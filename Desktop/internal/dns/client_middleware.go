package dns

import (
	"github.com/haoze-evolluling/diting/desktop/internal/core"
)

// NewClientMiddleware 创建客户端主机名识别与活动记录中间件
// 深度借鉴自 Blocky (client_names_resolver.go) 与 AdGuard Home (internal/rdns)
func NewClientMiddleware(resolver *core.ClientResolver) Middleware {
	return NewClientMiddlewareWithGroups(resolver, nil)
}

// NewClientMiddlewareWithGroups 创建带客户端分组标记的中间件。
//
// 分组标记必须在流水线早期写入：缓存中间件依赖它做按组隔离的键，
// 若注册位置晚于缓存，缓存键会退化为默认组，分组隔离随之失效。
func NewClientMiddlewareWithGroups(resolver *core.ClientResolver, groups *core.GroupResolver) Middleware {
	return func(ctx *DNSContext, next func() error) error {
		if resolver != nil && ctx.ClientIP != nil {
			name := resolver.IdentifyClient(ctx.ClientIP)
			ctx.ClientName = name
			if name != "" {
				ctx.Set("client_name", name)
			}
		}

		if groups != nil && ctx.ClientIP != nil {
			ctx.Set(attrClientGroup, groups.Resolve(ctx.ClientIP))
		}

		return next()
	}
}
