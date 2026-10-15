package core

import (
	"bytes"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"
)

// RuleEngine 谛听 Windows 规则过滤与拦截引擎核心
type RuleEngine struct {
	mu             sync.RWMutex
	cfg            FilterConfig
	matcher        *RuleMatcher
	totalQueries   atomic.Uint64
	blockedQueries atomic.Uint64
	allowedQueries atomic.Uint64

	// 客户端分组：组 ID → 专属匹配器 / 拦截方式覆盖
	groupCfg        ClientGroupConfig
	groupMatchers   map[string]*RuleMatcher
	groupBlockModes map[string]string

	// bogusMatcher 伪应答地址匹配器；未启用伪应答纠正时为 nil
	bogusMatcher *BogusNXDomainMatcher

	httpClient *http.Client
	stopCh     chan struct{}

	// now 时钟注入点，默认 time.Now；测试可借此固定"当前时刻"
	now func() time.Time

	// pausedUntil 定时暂停拦截的截止时刻（零值表示未暂停），纯运行时状态不持久化
	pausedUntil time.Time
}

// NewRuleEngine 初始化规则引擎并自动加载构建规则索引
func NewRuleEngine(cfg FilterConfig) *RuleEngine {
	NormalizeFilterConfig(&cfg)

	engine := &RuleEngine{
		cfg:     cfg,
		matcher: NewRuleMatcher(),
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
		stopCh:          make(chan struct{}),
		now:             time.Now,
		groupCfg:        ClientGroupConfig{},
		groupMatchers:   make(map[string]*RuleMatcher),
		groupBlockModes: make(map[string]string),
	}

	// 确保规则缓存目录存在
	if err := os.MkdirAll(cfg.DataDir, 0755); err != nil {
		log.Printf("[RuleEngine] 创建缓存目录失败 (%s): %v", cfg.DataDir, err)
	}

	// 首次全量加载规则
	if err := engine.rebuildUnlocked(); err != nil {
		log.Printf("[RuleEngine] 初始加载规则出现警告: %v", err)
	}
	engine.mu.Lock()
	engine.syncBogusMatcherUnlocked()
	engine.mu.Unlock()

	// 启动定期更新定时器
	go engine.runUpdateTicker()

	return engine
}

// IsEnabled 查询规则过滤总开关。
//
// 定时暂停期内同样返回 false，从而经 filter_middleware 的既有早退路径整体放行，无需改动中间件。
func (e *RuleEngine) IsEnabled() bool {
	e.mu.RLock()
	defer e.mu.RUnlock()
	if !e.cfg.Enabled {
		return false
	}
	paused, _ := e.pauseStateUnlocked()
	return !paused
}

// SetEnabled 设置规则过滤总开关
func (e *RuleEngine) SetEnabled(enabled bool) {
	e.mu.Lock()
	e.cfg.Enabled = enabled
	// 总开关同时决定伪应答纠正是否生效
	e.syncBogusMatcherUnlocked()
	e.mu.Unlock()
}

// GetConfig 获取当前过滤配置副本
func (e *RuleEngine) GetConfig() FilterConfig {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.cfg
}

// UpdateConfig 更新过滤配置并热重载
func (e *RuleEngine) UpdateConfig(cfg FilterConfig) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	old := e.cfg

	// 保持未显式更新字段
	if cfg.CustomRules == nil {
		cfg.CustomRules = old.CustomRules
	}
	if cfg.Lists == nil {
		cfg.Lists = old.Lists
	}
	if cfg.DataDir == "" {
		cfg.DataDir = old.DataDir
	}
	// 深拷贝时间计划，避免编译产物写回引擎在用切片的后备数组
	if cfg.Schedules == nil {
		cfg.Schedules = append([]BlockingSchedule(nil), old.Schedules...)
	} else {
		cfg.Schedules = append([]BlockingSchedule(nil), cfg.Schedules...)
	}
	NormalizeFilterConfig(&cfg)

	e.cfg = cfg
	// 伪应答清单与总开关都可能在本轮变更，必须先同步再决定是否重建规则索引
	e.syncBogusMatcherUnlocked()

	// 规则索引仅由自定义规则与订阅列表决定；其余字段（开关、时间计划等）热更新即可
	matcherInputsUnchanged := e.matcher != nil && e.matcher.TotalRules() > 0 &&
		len(old.CustomRules) == len(cfg.CustomRules) &&
		len(old.Lists) == len(cfg.Lists)
	if matcherInputsUnchanged {
		return nil
	}

	return e.rebuildUnlocked()
}

func (e *RuleEngine) getMatcher() *RuleMatcher {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.matcher
}

// GetStats 获取当前运行时拦截与规则统计指标
func (e *RuleEngine) GetStats() FilterStats {
	e.mu.RLock()
	defer e.mu.RUnlock()

	total := e.totalQueries.Load()
	blocked := e.blockedQueries.Load()
	allowed := e.allowedQueries.Load()
	var rate float64
	if total > 0 {
		rate = float64(blocked) / float64(total) * 100
	}

	activeLists := 0
	for _, l := range e.cfg.Lists {
		if l.Enabled {
			activeLists++
		}
	}

	totalRules := 0
	if e.matcher != nil {
		totalRules = e.matcher.TotalRules()
	}

	// 计划关闭或未配置启用计划时恒为生效（避免重入加锁，直接内联判定）
	scheduleActive := true
	if e.cfg.ScheduleEnabled && HasEnabledSchedule(e.cfg.Schedules) {
		scheduleActive = ActiveSchedule(e.cfg.Schedules, e.currentTime())
	}

	// 定时暂停为运行时状态，同样内联判定以免重入加锁
	paused, pausedUntil := e.pauseStateUnlocked()
	var pausedRemaining int64
	if paused {
		pausedRemaining = int64(pausedUntil.Sub(e.currentTime()).Seconds())
		if pausedRemaining < 0 {
			pausedRemaining = 0
		}
	}

	return FilterStats{
		Enabled:            e.cfg.Enabled,
		TotalRules:         totalRules,
		ActiveLists:        activeLists,
		TotalQueries:       total,
		BlockedQueries:     blocked,
		AllowedQueries:     allowed,
		BlockRate:          rate,
		ScheduleActive:     scheduleActive,
		Paused:             paused,
		PausedRemainingSec: pausedRemaining,
		PausedUntilMs:      pausedUntilMs(paused, pausedUntil),
	}
}

// pausedUntilMs 将暂停截止时刻转为 Unix 毫秒（未暂停返回 0）。
func pausedUntilMs(paused bool, until time.Time) int64 {
	if !paused || until.IsZero() {
		return 0
	}
	return until.UnixMilli()
}

// Match 对域名进行过滤评估并记录遥测统计
func (e *RuleEngine) Match(domain string, qtype uint16) CheckHostResult {
	return e.MatchForGroup(domain, qtype, DefaultClientGroupID)
}

// IsBlockingActive 判断当前时刻拦截功能是否处于生效状态。
//
// 语义：时间计划开关关闭，或未配置任何启用计划时，拦截恒为常开（等价历史行为）；
// 开关开启且存在启用计划时，仅命中窗口才拦截。
func (e *RuleEngine) IsBlockingActive() bool {
	return e.IsBlockingActiveAt(e.currentTime())
}

// IsBlockingActiveAt 判断给定时刻拦截功能是否处于生效状态（便于测试注入时钟）。
func (e *RuleEngine) IsBlockingActiveAt(now time.Time) bool {
	e.mu.RLock()
	defer e.mu.RUnlock()

	if !e.cfg.ScheduleEnabled || !HasEnabledSchedule(e.cfg.Schedules) {
		return true
	}
	return ActiveSchedule(e.cfg.Schedules, now)
}

// CurrentSchedule 返回当前生效的时间计划（无则 nil）。
func (e *RuleEngine) CurrentSchedule() *BlockingSchedule {
	return e.CurrentScheduleAt(e.currentTime())
}

// CurrentScheduleAt 返回给定时刻生效的时间计划（无则 nil）。
func (e *RuleEngine) CurrentScheduleAt(now time.Time) *BlockingSchedule {
	e.mu.RLock()
	defer e.mu.RUnlock()

	if !e.cfg.ScheduleEnabled {
		return nil
	}
	return FirstActiveSchedule(e.cfg.Schedules, now)
}

// SetClock 注入自定义时钟（测试专用），传 nil 恢复 time.Now。
func (e *RuleEngine) SetClock(now func() time.Time) {
	e.mu.Lock()
	defer e.mu.Unlock()
	if now == nil {
		e.now = time.Now
		return
	}
	e.now = now
}

// currentTime 读取注入时钟的当前时刻（锁外调用，仅读函数指针）。
func (e *RuleEngine) currentTime() time.Time {
	e.mu.RLock()
	now := e.now
	e.mu.RUnlock()
	if now == nil {
		now = time.Now
	}
	return now()
}

// CheckHost 提供外部纯只读检测（不增加正式查询指标计数）
func (e *RuleEngine) CheckHost(domain string, qtype uint16) CheckHostResult {
	matcher := e.getMatcher()
	if matcher == nil {
		return CheckHostResult{Action: "pass"}
	}
	return matcher.Match(domain, qtype)
}

// compileGroupMatchersUnlocked 为每个启用分组构建专属规则匹配器。
//
// 调用方须已持有 e.mu 写锁。组级规则集按 RuleListIDs 过滤：
// 空列表表示继承全部；否则只包含指定的订阅列表（自定义规则始终包含）。
func (e *RuleEngine) compileGroupMatchersUnlocked(customRules, listRules []*ParsedRule) {
	e.groupMatchers = make(map[string]*RuleMatcher)
	e.groupBlockModes = make(map[string]string)

	if !e.groupCfg.Enabled {
		return
	}

	for i := range e.groupCfg.Groups {
		g := &e.groupCfg.Groups[i]
		if !g.Enabled {
			continue
		}

		selected := make([]*ParsedRule, 0, len(customRules)+len(listRules))
		selected = append(selected, customRules...)

		if len(g.RuleListIDs) == 0 {
			selected = append(selected, listRules...)
		} else {
			allow := make(map[string]bool, len(g.RuleListIDs))
			for _, id := range g.RuleListIDs {
				allow[id] = true
			}
			for _, r := range listRules {
				if allow[r.Source] {
					selected = append(selected, r)
				}
			}
		}

		m := NewRuleMatcher()
		m.BuildFromRules(selected)
		e.groupMatchers[g.ID] = m
		if g.BlockMode != "" {
			e.groupBlockModes[g.ID] = g.BlockMode
		}
	}
}

// getGroupMatcher 读取指定分组的匹配器（不存在或未分组时回落默认匹配器）。
func (e *RuleEngine) getGroupMatcher(groupID string) *RuleMatcher {
	e.mu.RLock()
	defer e.mu.RUnlock()
	if groupID != "" && groupID != DefaultClientGroupID {
		if m, ok := e.groupMatchers[groupID]; ok {
			return m
		}
	}
	return e.matcher
}

// MatchForGroup 按客户端分组评估域名，并记录遥测统计。
//
// 未命中分组或分组未启用时等价于 Match（默认组语义不变）。
func (e *RuleEngine) MatchForGroup(domain string, qtype uint16, groupID string) CheckHostResult {
	if !e.IsEnabled() {
		return CheckHostResult{Action: "pass"}
	}
	// 分时拦截：优先按分组计划判定，未配置组级计划时回落全局语义
	if !e.IsBlockingActiveForGroup(groupID) {
		return CheckHostResult{Action: "pass", Reason: ReasonScheduleInactive}
	}

	matcher := e.getGroupMatcher(groupID)
	if matcher == nil {
		return CheckHostResult{Action: "pass"}
	}

	e.totalQueries.Add(1)
	res := matcher.Match(domain, qtype)

	// 仅白名单模式：未命中放行规则时一律阻断（计划窗口外已在上面提前放行）
	if e.IsAllowlistOnlyForGroup(groupID) {
		res = applyAllowlistOnly(res)
	}

	if res.Blocked {
		e.blockedQueries.Add(1)
	} else if res.Action == "allow" {
		e.allowedQueries.Add(1)
	}
	return res
}

// GroupBlockMode 返回分组的拦截方式覆盖（无覆盖时返回空串）。
func (e *RuleEngine) GroupBlockMode(groupID string) string {
	if e == nil || groupID == "" || groupID == DefaultClientGroupID {
		return ""
	}
	e.mu.RLock()
	defer e.mu.RUnlock()
	return e.groupBlockModes[groupID]
}

// SetClientGroups 注入客户端分组配置并重建分组匹配器。
//
// 分组配置独立于 FilterConfig，因此不触发全局规则索引重建之外的副作用。
func (e *RuleEngine) SetClientGroups(cfg ClientGroupConfig) error {
	if err := NormalizeClientGroupConfig(&cfg); err != nil {
		// 归一化错误不阻断生效，记录后继续（非法成员已被剔除）
		log.Printf("[RuleEngine] 客户端分组配置存在问题: %v", err)
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if cfg.Groups == nil {
		cfg.Groups = []ClientGroup{}
	}
	e.groupCfg = cfg

	customRules, listRules := e.loadAllRulesUnlocked()
	e.compileGroupMatchersUnlocked(customRules, listRules)
	return nil
}

// GetClientGroups 返回当前客户端分组配置副本。
func (e *RuleEngine) GetClientGroups() ClientGroupConfig {
	e.mu.RLock()
	defer e.mu.RUnlock()
	out := ClientGroupConfig{Enabled: e.groupCfg.Enabled, Groups: make([]ClientGroup, len(e.groupCfg.Groups))}
	copy(out.Groups, e.groupCfg.Groups)
	return out
}

// rebuildUnlocked 从自定义规则与订阅缓存重建匹配器并原子切换
func (e *RuleEngine) rebuildUnlocked() error {
	customRules, listRules := e.loadAllRulesUnlocked()

	allRules := make([]*ParsedRule, 0, len(customRules)+len(listRules))
	allRules = append(allRules, customRules...)
	allRules = append(allRules, listRules...)

	// 构建新的匹配器实例并全量原子切换
	newMatcher := NewRuleMatcher()
	newMatcher.BuildFromRules(allRules)
	e.matcher = newMatcher

	// 按客户端分组构建专属匹配器（组数有限，内存可控）
	e.compileGroupMatchersUnlocked(customRules, listRules)

	log.Printf("[RuleEngine] 规则索引构建完毕，共激活 %d 条规则", len(allRules))
	return nil
}

// loadAllRulesUnlocked 解析自定义规则与各启用订阅列表的缓存并返回。
//
// 返回顺序固定为自定义规则在前（最高优先级），随后按列表声明顺序。
func (e *RuleEngine) loadAllRulesUnlocked() (customRules []*ParsedRule, listRules []*ParsedRule) {
	for _, line := range e.cfg.CustomRules {
		if r, ok := ParseRuleLine(line, "custom"); ok && r != nil {
			customRules = append(customRules, r)
		}
	}

	for i := range e.cfg.Lists {
		list := &e.cfg.Lists[i]
		if !list.Enabled {
			continue
		}
		cacheFile := filepath.Join(e.cfg.DataDir, list.ID+".txt")
		data, err := os.ReadFile(cacheFile)
		if err != nil {
			continue
		}
		parsed, err := ParseRules(bytes.NewReader(data), list.ID)
		if err != nil {
			continue
		}
		list.RulesCount = len(parsed)
		listRules = append(listRules, parsed...)
	}
	return customRules, listRules
}

func (e *RuleEngine) runUpdateTicker() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-e.stopCh:
			return
		case <-ticker.C:
			e.mu.Lock()
			interval := time.Duration(e.cfg.UpdateIntervalHours) * time.Hour
			needUpdate := false
			for _, l := range e.cfg.Lists {
				if l.Enabled && time.Since(time.UnixMilli(l.LastUpdated)) > interval {
					needUpdate = true
					break
				}
			}
			if needUpdate {
				changed := false
				for _, l := range e.cfg.Lists {
					if l.Enabled && time.Since(time.UnixMilli(l.LastUpdated)) > interval {
						if updated, err := e.refreshListUnlocked(l.ID); err == nil && updated {
							changed = true
						}
					}
				}
				if changed {
					_ = e.rebuildUnlocked()
				}
			}
			e.mu.Unlock()
		}
	}
}

// Close 关闭规则引擎后台协程
func (e *RuleEngine) Close() {
	close(e.stopCh)
}
