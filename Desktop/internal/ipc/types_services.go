package ipc

import "github.com/haoze-evolluling/diting/desktop/internal/core"

// BlockedServicesResponse 内置阻断服务目录与当前选择状态
type BlockedServicesResponse struct {
	// Services 目录中的全部服务（含规则明细，供界面展开查看）
	Services []core.BlockedService `json:"services"`
	// Groups 服务分组及其服务数量
	Groups []core.BlockedServiceGroup `json:"groups"`
	// BlockedIDs 当前被勾选拦截的服务 ID
	BlockedIDs []string `json:"blockedIds"`
	// BlockedGroups 当前被整组拦截的分组 ID
	BlockedGroups []string `json:"blockedGroups"`
	// ActiveRules 当前选择展开后实际生效的规则条数
	ActiveRules int `json:"activeRules"`
}

// ConfigureBlockedServicesRequest 更新内置服务拦截选择。
//
// 两个字段均为可选：省略表示沿用当前值，传空数组表示清空该维度。
// 用指针而非切片本身来区分这两种意图。
type ConfigureBlockedServicesRequest struct {
	IDs    *[]string `json:"ids,omitempty"`
	Groups *[]string `json:"groups,omitempty"`
}
