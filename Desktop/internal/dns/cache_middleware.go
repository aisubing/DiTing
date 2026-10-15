package dns

import (
	"context"

	"github.com/haoze-evolluling/diting/desktop/internal/core"
	"github.com/miekg/dns"
)

// NewCacheMiddleware 创建智能缓存流水线中间件（不区分客户端分组）
func NewCacheMiddleware(cache *core.DNSCache, resolver core.Resolver) Middleware {
	return NewCacheMiddlewareWithGroups(cache, resolver, nil)
}

// NewCacheMiddlewareWithGroups 创建带客户端分组隔离的缓存中间件。
//
// groups 为 nil 时键退回默认组，行为与既有版本逐字一致。
// 非 nil 时按分组隔离：不同分组可能被路由到不同上游、得到不同应答，
// 共用缓存会让 A 组的结果被 B 组命中，分组的策略隔离随之失效。
func NewCacheMiddlewareWithGroups(cache *core.DNSCache, resolver core.Resolver, groups *core.GroupResolver) Middleware {
	return func(ctx *DNSContext, next func() error) error {
		if cache == nil || !cache.IsEnabled() || ctx.Req == nil || len(ctx.Req.Question) == 0 {
			return next()
		}

		req := ctx.Req
		q := req.Question[0]
		group := cachedGroup(ctx, groups)
		cachedResp, hit, isStale, staleCandidate := cache.GetForGroup(req, group)

		// 1. 有效期内新鲜命中 (Fresh Hit)
		if hit && cachedResp != nil {
			ctx.Resp = cachedResp
			ctx.Set("cache_hit", "fresh")
			return nil
		}

		// 2. 过期宽限期内的陈旧条目 (Optimistic Stale-While-Revalidate 容灾)
		if isStale && staleCandidate != nil && cache.IsStaleFallbackEnabled() {
			if cache.IsOptimistic() {
				staleResp := cache.BuildStaleResponse(req, staleCandidate)
				if staleResp != nil {
					ctx.Resp = staleResp
					ctx.Set("cache_hit", "stale")

					// 后台异步回源刷新 (并发单飞防惊群)
					if resolver != nil {
						reqCopy := req.Copy()
						go func() {
							flightKey := core.CacheKeyForGroup(q.Name, q.Qtype, q.Qclass, group)
							_, _, _ = cache.SingleFlight(flightKey, func() (*dns.Msg, error) {
								freshResp, err := resolver.Exchange(context.Background(), reqCopy)
								if err == nil && freshResp != nil {
									cache.PutForGroup(reqCopy, freshResp, group)
								}
								return freshResp, err
							})
						}()
					}
					return nil
				}
			}
		}

		// 3. 缓存未命中 (Cache Miss)，调用下层中间件 (ForwardMiddleware)
		// 结合 singleflight 防并发回源击穿
		flightKey := core.CacheKeyForGroup(q.Name, q.Qtype, q.Qclass, group)
		var innerErr error

		val, shared, flightErr := cache.SingleFlight(flightKey, func() (*dns.Msg, error) {
			innerErr = next()
			if innerErr == nil && ctx.Resp != nil {
				cache.PutForGroup(req, ctx.Resp, group)
				return ctx.Resp, nil
			}
			return ctx.Resp, innerErr
		})

		// 若为并发共享等待者，优先使用最新写入的缓存以具备动态 TTL 重写；
		// 若条目未入缓存（如 TTL=0 或未开启负缓存），则回退使用 SingleFlight 交付的响应副本
		if shared {
			if freshResp, hit, _, _ := cache.GetForGroup(req, group); hit && freshResp != nil {
				ctx.Resp = freshResp
				ctx.Set("cache_hit", "fresh")
				ctx.Err = nil
				return nil
			}
			if val != nil {
				ctx.Resp = val.Copy()
				ctx.Resp.Id = req.Id
			}
			if flightErr != nil || ctx.Resp == nil || ctx.Resp.Rcode == dns.RcodeServerFailure {
				if isStale && staleCandidate != nil && cache.IsStaleFallbackEnabled() {
					staleResp := cache.BuildStaleResponse(req, staleCandidate)
					if staleResp != nil {
						ctx.Resp = staleResp
						ctx.Set("cache_hit", "stale_fallback")
						ctx.Err = nil
						return nil
					}
				}
				ctx.Err = flightErr
				return flightErr
			}
			ctx.Err = nil
			return nil
		}

		// 4. 回源发生错误或 SERVFAIL，检查是否存在可用 Stale 候选进行降级容灾
		if innerErr != nil || flightErr != nil || ctx.Resp == nil || ctx.Resp.Rcode == dns.RcodeServerFailure {
			if isStale && staleCandidate != nil && cache.IsStaleFallbackEnabled() {
				staleResp := cache.BuildStaleResponse(req, staleCandidate)
				if staleResp != nil {
					ctx.Resp = staleResp
					ctx.Set("cache_hit", "stale_fallback")
					ctx.Err = nil
					return nil
				}
			}
			if innerErr != nil {
				return innerErr
			}
			return flightErr
		}

		return nil
	}
}

// cachedGroup 取出该查询的客户端分组；未启用分组时返回默认组。
//
// 分组由 client 中间件在流水线早期写入；此处读不到时回落默认组，
// 与「未启用分组」保持同一语义。
func cachedGroup(ctx *DNSContext, groups *core.GroupResolver) string {
	if groups == nil {
		return core.DefaultClientGroupID
	}
	if v, ok := ctx.Get(attrClientGroup); ok {
		if s, ok := v.(string); ok && s != "" {
			return s
		}
	}
	return core.DefaultClientGroupID
}
