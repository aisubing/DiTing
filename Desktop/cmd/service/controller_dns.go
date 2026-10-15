package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/haoze-evolluling/diting/desktop/internal/core"
	ditingdns "github.com/haoze-evolluling/diting/desktop/internal/dns"
	"github.com/haoze-evolluling/diting/desktop/internal/ipc"
	"github.com/haoze-evolluling/diting/desktop/internal/platform"
)

// StartDNS 实现 ServiceController 接口
func (p *program) StartDNS(ctx context.Context) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.dnsRunning {
		return nil
	}

	// 流水线装配（含指标采集中间件）已拆分至 controller_pipeline.go / controller_metrics.go
	pipeline := p.buildPipeline()
	udpAddrs, tcpAddrs := p.cfg.DNS.EffectiveListenAddresses()
	serverCfg := ditingdns.ServerConfig{
		UDPAddresses: udpAddrs,
		TCPAddresses: tcpAddrs,
		ReadTimeout:  p.cfg.DNS.ReadTimeout,
		WriteTimeout: p.cfg.DNS.WriteTimeout,
	}

	// 53 端口占用前置检测：若本地监听包含 53 且不可用，立即执行深度冲突诊断
	needs53 := false
	for _, a := range append(serverCfg.UDPAddresses, serverCfg.TCPAddresses...) {
		if strings.HasSuffix(a, ":53") {
			needs53 = true
			break
		}
	}
	if needs53 && p.portChecker != nil && !platform.AreAddressesAvailable(serverCfg.UDPAddresses, serverCfg.TCPAddresses) {
		res, checkErr := p.portChecker.CheckPort53ForAddresses(ctx, serverCfg.UDPAddresses, serverCfg.TCPAddresses)
		if checkErr == nil && res != nil && !res.Available {
			return &platform.PortConflictError{Result: res}
		}
		if checkErr != nil {
			return fallbackPortConflict(nil)
		}
	}

	srv := ditingdns.NewServer(serverCfg, pipeline)
	if err := srv.Start(); err != nil {
		if platform.IsPortBindConflict(err) {
			if p.portChecker != nil {
				if res, checkErr := p.portChecker.CheckPort53ForAddresses(ctx, serverCfg.UDPAddresses, serverCfg.TCPAddresses); checkErr == nil && res != nil {
					return &platform.PortConflictError{Result: res, Err: err}
				}
			}
			return fallbackPortConflict(err)
		}
		return fmt.Errorf("启动 DNS 监听器失败: %w", err)
	}

	p.server = srv
	p.dnsRunning = true
	log.Printf("[DNS] 谛听 DNS 监听器已就绪: %v\n", serverCfg.UDPAddresses)
	return nil
}

// StopDNS 实现 ServiceController 接口
func (p *program) StopDNS(ctx context.Context) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if !p.dnsRunning {
		return nil
	}

	// 关键保护：若当前处于系统 DNS 接管状态，必须先安全还原网卡，防止系统网络彻底断连
	if p.takeoverMgr != nil && p.takeoverMgr.IsTakeoverActive() {
		log.Println("[DNS] 停止 DNS 监听前检测到接管生效中，自动先还原系统 DNS 接管...")
		if err := p.takeoverMgr.Restore(ctx); err != nil {
			log.Printf("[DNS警告] 自动还原系统 DNS 接管失败: %v\n", err)
		} else if p.ipcServer != nil {
			p.ipcServer.Broadcast(ipc.Event{Type: "takeover", Timestamp: time.Now().UnixMilli(), Data: "disabled"})
		}
	}

	if p.server != nil {
		_ = p.server.Shutdown()
		p.server = nil
	}
	p.dnsRunning = false
	log.Println("[DNS] 谛听 DNS 监听器已停止")
	return nil
}

// EnableTakeover 实现 ServiceController 接口
func (p *program) EnableTakeover(ctx context.Context) error {
	p.mu.Lock()
	dnsRun := p.dnsRunning
	p.mu.Unlock()

	if !dnsRun {
		log.Println("[接管] DNS 服务未处于运行状态，自动先启动本地 DNS 监听器...")
		if err := p.StartDNS(ctx); err != nil {
			var pErr *platform.PortConflictError
			if errors.As(err, &pErr) {
				return pErr
			}
			return fmt.Errorf("接管前启动 DNS 监听器失败: %w", err)
		}
	}

	adapters, err := p.adapterScan.GetActivePhysicalAdapters(ctx)
	if err != nil {
		return fmt.Errorf("枚举活动物理网卡失败: %w", err)
	}
	if len(adapters) == 0 {
		return fmt.Errorf("未检测到有效活动的物理网卡（以太网或 Wi-Fi）")
	}

	if err := p.takeoverMgr.Takeover(ctx, adapters); err != nil {
		return err
	}
	log.Printf("[接管] 已成功接管 %d 个活动物理网卡\n", len(adapters))
	return nil
}

// DisableTakeover 实现 ServiceController 接口
func (p *program) DisableTakeover(ctx context.Context) error {
	if err := p.takeoverMgr.Restore(ctx); err != nil {
		return err
	}
	log.Println("[接管] 已成功还原物理网卡 DNS 设置")
	return nil
}

// GetAdapters 实现 ServiceController 接口
func (p *program) GetAdapters(ctx context.Context) ([]platform.AdapterInfo, error) {
	if p.adapterScan == nil {
		p.adapterScan = newAdapterScanner(platform.NewDefaultExecutor())
	}
	return p.adapterScan.ScanAll(ctx)
}

// GetStatus 实现 ServiceController 接口
func (p *program) GetStatus(ctx context.Context) (*ipc.StatusResponse, error) {
	p.mu.Lock()
	dnsRun := p.dnsRunning
	p.mu.Unlock()

	upstreams := make([]ipc.UpstreamInfo, 0)
	if p.resolver != nil {
		stats := p.resolver.GetProviderStats()
		for _, stat := range stats {
			upstreams = append(upstreams, ipc.UpstreamInfo{
				ID:           stat.ID,
				Protocol:     string(stat.Protocol),
				Server:       stat.Server,
				URL:          stat.URL,
				Weight:       stat.Weight,
				Active:       stat.IsHealthy,
				SuccessCount: stat.SuccessCount,
				FailureCount: stat.FailureCount,
				AvgLatencyMs: stat.AvgLatencyMs,
			})
		}
	} else if p.cfg != nil {
		for _, prov := range p.cfg.Upstream.Providers {
			w := prov.Weight
			if w <= 0 {
				w = 1
			}
			upstreams = append(upstreams, ipc.UpstreamInfo{
				ID:       prov.ID,
				Protocol: string(prov.Protocol),
				Server:   prov.Server,
				URL:      prov.URL,
				Weight:   w,
				Active:   true,
			})
		}
	}

	var takenAdapters []platform.AdapterState
	takeoverActive := false
	if p.takeoverMgr != nil {
		takenAdapters = p.takeoverMgr.GetTakenOverAdapters()
		takeoverActive = p.takeoverMgr.IsTakeoverActive()
	}
	lanAddrs, _ := platform.GetLANAddresses()
	effUDP, _ := p.cfg.DNS.EffectiveListenAddresses()

	var metricsSnap ipc.MetricsStatus
	if p.metrics != nil {
		metricsSnap = p.metrics.Snapshot()
	}

	return &ipc.StatusResponse{
		Version:       Version,
		PID:           os.Getpid(),
		UptimeSeconds: int64(time.Since(p.startTime).Seconds()),
		DNS: ipc.DNSStatus{
			Running:           dnsRun,
			ListenAddresses:   effUDP,
			AllowLAN:          p.cfg.DNS.AllowLAN,
			LANAddresses:      lanAddrs,
			Mode:              p.cfg.Upstream.Mode,
			Upstreams:         upstreams,
			Bootstrap:         p.cfg.Upstream.Bootstrap,
			ConditionalRoutes: p.cfg.Upstream.ConditionalRoutes,
			EnableEDE:         p.cfg.DNS.EnableEDE,
			BlockUnqualified:  p.cfg.DNS.BlockUnqualified,
			BlockPrivatePTR:   p.cfg.DNS.BlockPrivatePTR,
			BlockIPv6:         p.cfg.DNS.BlockIPv6,
			BlockECH:          p.cfg.DNS.BlockECH,
			EDNSPadding:       p.cfg.DNS.EDNSPadding,
		},
		Takeover: ipc.TakeoverStatus{
			Active:   takeoverActive,
			Adapters: takenAdapters,
		},
		Metrics:    metricsSnap,
		Cache:      p.getCacheStatsSnapshot(),
		Filter:     p.getFilterStatsSnapshot(),
		Hosts:      p.cfg.Hosts,
		Rebind:     p.cfg.Rebind,
		Access:     p.cfg.Access,
		RateLimit:  p.cfg.RateLimit,
		DNS64:      p.cfg.DNS64,
		Rewrite:    p.cfg.Rewrite,
		SafeSearch: p.cfg.SafeSearch,
		ECS:        p.cfg.ECS,
		Clients:    p.getClientsSnapshot(),
	}, nil
}

func (p *program) getCacheStatsSnapshot() core.CacheStats {
	if p.cache != nil {
		return p.cache.Stats()
	}
	return core.CacheStats{Enabled: false}
}

func (p *program) getFilterStatsSnapshot() core.FilterStats {
	if p.filterEngine != nil {
		return p.filterEngine.GetStats()
	}
	return core.FilterStats{Enabled: false}
}

func (p *program) getClientsSnapshot() []core.ClientInfo {
	if p.clientResolver != nil {
		return p.clientResolver.GetClients()
	}
	return []core.ClientInfo{}
}
