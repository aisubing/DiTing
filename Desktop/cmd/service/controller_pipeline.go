package main

import (
	ditingdns "github.com/haoze-evolluling/diting/desktop/internal/dns"
)

// buildPipeline 装配 DNS 请求处理流水线。
//
// 中间件的注册顺序即语义的一部分，调用方不得随意调整：
//
//	metrics → EDE → ECH → client → access → ratelimit → SUDN → hosts → rewrite
//	→ safesearch → IPv6 → privatePTR → unqualified → filter → rebind
//	→ filterResponse → DNS64 → ECS → cache → forward
//
// 其中响应侧复检（filterResponse）位于 rebind 之后、DNS64 之前：
// 既包裹缓存（缓存命中也复检），又在 DNS64 合成之后获得最终应答，
// 且被 rebind 的已阻断判定短路。
//
// 调用方需持有 p.mu（内部对 p.cfg 的读取依赖该保护）。
func (p *program) buildPipeline() *ditingdns.Pipeline {
	metricsMw := p.newMetricsMiddleware()

	rebindMgr := p.rebindMgr
	if rebindMgr == nil {
		rebindMgr = ditingdns.NewRebindProtectionManager(p.cfg.Rebind)
	}
	clientMw := ditingdns.NewClientMiddleware(p.clientResolver)
	accessMw := ditingdns.NewAccessMiddleware(p.accessControl)
	rateLimitMw := ditingdns.NewRateLimitMiddleware(p.rateLimiter)
	edeMw := ditingdns.NewEDEMiddleware(func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.DNS.EnableEDE
	})
	echMw := ditingdns.NewECHMiddleware(func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.DNS.BlockECH
	})
	sudnMw := ditingdns.NewSUDNMiddleware()
	ipv6Mw := ditingdns.NewIPv6Middleware(func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.DNS.BlockIPv6
	})
	hostsMw := ditingdns.NewHostsMiddleware(p.hostsResolver)
	rewriteMw := ditingdns.NewRewriteMiddleware(p.rewriteEngine)
	safeSearchMw := ditingdns.NewSafeSearchMiddleware(p.safeSearchEng)
	privatePTRMw := ditingdns.NewPrivatePTRMiddleware(func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.DNS.BlockPrivatePTR
	}, p.clientResolver)
	unqualifiedMw := ditingdns.NewDynamicUnqualifiedMiddleware(func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.DNS.BlockUnqualified
	})
	filterMw := ditingdns.NewFilterMiddlewareWithGroups(p.filterEngine, p.groupResolver)
	rebindMw := ditingdns.NewRebindMiddleware(rebindMgr, p.cache)
	filterResponseMw := ditingdns.NewFilterResponseMiddleware(p.filterEngine, p.groupResolver, func() bool {
		p.mu.Lock()
		defer p.mu.Unlock()
		return p.cfg.Filter.FilterResponse
	}, p.cache)
	dns64Mw := ditingdns.NewDNS64Middleware(p.dns64Synth, p.resolver)
	ecsMw := ditingdns.NewECSMiddleware(p.ecsMgr)
	cacheMw := ditingdns.NewCacheMiddleware(p.cache, p.resolver)
	forwardMw := ditingdns.NewForwardMiddleware(p.resolver)

	return ditingdns.NewPipeline(
		metricsMw, edeMw, echMw, clientMw, accessMw, rateLimitMw, sudnMw,
		hostsMw, rewriteMw, safeSearchMw, ipv6Mw, privatePTRMw, unqualifiedMw,
		filterMw, rebindMw, filterResponseMw, dns64Mw, ecsMw, cacheMw, forwardMw,
	)
}
