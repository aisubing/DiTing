package ipc

import (
	"context"
	"fmt"
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
