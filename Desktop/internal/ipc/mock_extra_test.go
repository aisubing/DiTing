package ipc

import (
	"context"
	"fmt"

	"github.com/haoze-evolluling/diting/desktop/internal/core"
)

// mockExtra 汇总后续 Step 新增的 ServiceController 方法桩。
//
// mockController 通过匿名嵌入本类型获得这些方法，
// 从而让 mock_test.go 不随功能增长触碰 600 行上限。
// 每个新增方法请在此文件内按 Step 分组实现。
type mockExtra struct {
	// A6 缓存落盘：由各测试按需注入
	cachePersist    *CachePersistResponse
	cachePersistErr bool
	cacheDumped     bool
	cacheLoaded     bool

	// B3 内置阻断服务：由各测试按需注入
	blockedServices        *BlockedServicesResponse
	blockedServicesErr     bool
	blockedServicesUpdated bool
	lastServicesReq        ConfigureBlockedServicesRequest
}

// CachePersistStatus 实现 ServiceController 接口（A6）
func (m *mockExtra) CachePersistStatus(ctx context.Context) (*CachePersistResponse, error) {
	if m.cachePersistErr {
		return nil, errCachePersistUnavailable
	}
	if m.cachePersist != nil {
		return m.cachePersist, nil
	}
	return &CachePersistResponse{Path: "/tmp/cache.json", EntryCount: 0}, nil
}

// DumpCache 实现 ServiceController 接口（A6）
func (m *mockExtra) DumpCache(ctx context.Context) (*CachePersistResponse, error) {
	m.cacheDumped = true
	return &CachePersistResponse{Path: "/tmp/cache.json", EntryCount: 7}, nil
}

// LoadCache 实现 ServiceController 接口（A6）
func (m *mockExtra) LoadCache(ctx context.Context) (*CachePersistResponse, error) {
	m.cacheLoaded = true
	return &CachePersistResponse{Path: "/tmp/cache.json", Restored: 7, EntryCount: 7}, nil
}

// errCachePersistUnavailable 供需要错误路径的用例注入
var errCachePersistUnavailable = fmt.Errorf("cache persist unavailable")

// GetBlockedServices 实现 ServiceController 接口（B3）
func (m *mockExtra) GetBlockedServices(ctx context.Context) (*BlockedServicesResponse, error) {
	if m.blockedServicesErr {
		return nil, errBlockedServicesUnavailable
	}
	if m.blockedServices != nil {
		return m.blockedServices, nil
	}
	return &BlockedServicesResponse{
		Services: []core.BlockedService{
			{ID: "bilibili", Name: "Bilibili", Group: "streaming", RuleN: 2,
				Source: "service:bilibili"},
		},
		Groups:         []core.BlockedServiceGroup{{ID: "streaming", Name: "流媒体", Count: 1}},
		BlockedIDs:     []string{},
		Schedules:      map[string][]core.BlockingSchedule{},
		ScheduleStates: []core.ServiceScheduleState{},
	}, nil
}

// ConfigureBlockedServices 实现 ServiceController 接口（B3）
func (m *mockExtra) ConfigureBlockedServices(ctx context.Context, req ConfigureBlockedServicesRequest) error {
	if m.blockedServicesErr {
		return errBlockedServicesUnavailable
	}
	m.blockedServicesUpdated = true
	m.lastServicesReq = req
	return nil
}

// errBlockedServicesUnavailable 供需要错误路径的用例注入
var errBlockedServicesUnavailable = fmt.Errorf("blocked services unavailable")
