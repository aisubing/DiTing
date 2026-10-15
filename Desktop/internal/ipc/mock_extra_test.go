package ipc

// mockExtra 汇总后续 Step 新增的 ServiceController 方法桩。
//
// mockController 通过匿名嵌入本类型获得这些方法，
// 从而让 mock_test.go 不随功能增长触碰 600 行上限。
// 每个新增方法请在此文件内按 Step 分组实现。
type mockExtra struct{}
