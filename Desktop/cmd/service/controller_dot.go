package main

import (
	"log"

	"github.com/haoze-evolluling/diting/desktop/internal/core"
	ditingdns "github.com/haoze-evolluling/diting/desktop/internal/dns"
)

// dotALPN 为 DoT 的 ALPN 标识（RFC 7858 §3.1）。
//
// 不宣告它客户端一样能连——DoT 客户端普遍不校验 ALPN——但宣告之后，误把
// DoH/DoQ 指向这个端口的客户端会握不上手，比连上来再收到解析失败更容易定位。
//
// DoH 的 ALPN（h2）由服务器自己覆写：一张证书要同时服务两种协议时，
// 靠这里传入的 NextProtos 是分不开的。
var dotALPN = []string{"dot"}

// buildEncryptedServerConfig 按当前配置装配加密监听参数。
//
// 调用方需持有 p.mu。返回 nil 表示本次不开放任何加密入口——此时连证书都
// 不去取，免得在用户没开这个功能时因为证书缺失而刷出无意义的错误日志。
func (p *program) buildEncryptedServerConfig() *ditingdns.EncryptedServerConfig {
	enc := p.cfg.Encrypted
	if !enc.Enabled || (!enc.DoTEnabled && !enc.DoHEnabled && !enc.DoQEnabled) {
		return nil
	}
	if p.certManager == nil {
		log.Println("[加密DNS] 证书管理器未就绪，本次不开放加密监听")
		return nil
	}

	tlsCfg, err := p.certManager.TLSConfig(dotALPN...)
	if err != nil {
		// 证书不可用时宁可不监听：没有证书的加密端口只会让客户端
		// 卡在握手阶段，比明确拒服务更难排查
		log.Printf("[加密DNS] 服务端证书不可用，本次不开放加密监听: %v\n", err)
		return nil
	}

	cfg := &ditingdns.EncryptedServerConfig{
		DoTEnabled:    enc.DoTEnabled,
		DoHEnabled:    enc.DoHEnabled,
		DoQEnabled:    enc.DoQEnabled,
		ListenAddress: enc.ListenAddress,
		DoTPort:       enc.DoTPort,
		DoHPort:       enc.DoHPort,
		DoQPort:       enc.DoQPort,
		DoHPath:       enc.DoHPath,
		ServerName:    enc.ServerName,
		TLSConfig:     tlsCfg,
		ReadTimeout:   ditingdns.DefaultDoTReadTimeout,
		IdleTimeout:   ditingdns.DefaultDoTIdleTimeout,
	}

	// 可信代理解析失败时退回「不信任任何转发头」而不是拒绝监听：
	// 两种做法都杜绝了来源伪造，但后者会连带把整个加密入口拖下水。
	// 列表在保存时已校验过，走到这里通常意味着配置文件被手工改坏了，
	// 故用 Warn 级别的日志明确点出真实后果。
	if enc.ReverseProxy.Enabled {
		tp, err := ditingdns.NewTrustedProxy(true, enc.ReverseProxy.TrustedSources,
			enc.ReverseProxy.ClientIPHeader)
		if err != nil {
			log.Printf("[加密DNS] 反向代理可信来源无效，本次将忽略全部转发头，"+
				"代理后的真实客户端 IP 无法还原: %v\n", err)
		} else {
			cfg.TrustedProxy = tp
		}
	}
	// 只开一项时其余项的端口可能还是零值（旧配置文件缺字段），补齐默认值：
	// 运行期配置的校验只看已启用那几项，但日志与界面都会读这些值
	if !isValidEncPort(cfg.DoTPort) {
		cfg.DoTPort = core.DefaultDoTPort
	}
	if !isValidEncPort(cfg.DoHPort) {
		cfg.DoHPort = core.DefaultDoHPort
	}
	if !isValidEncPort(cfg.DoQPort) {
		cfg.DoQPort = core.DefaultDoQPort
	}
	return cfg
}

// isValidEncPort 判断监听端口是否可用；0 视为非法（见 core.isValidPort 的取舍）
func isValidEncPort(port int) bool {
	return port > 0 && port <= 65535
}

// reloadDNSWithCurrentConfig 在持有 p.mu 的前提下重建流水线与监听器。
//
// 加密监听的配置（端口、证书、服务器名）只在启动时读取一次，改完必须重建
// 才生效。这一点与明文监听一致：流水线本身也是每次启动重新装配的，因此
// 顺带把两边都刷到最新，而不是只换加密那部分、留下一半旧一半新。
func (p *program) reloadDNSWithCurrentConfig() {
	if !p.dnsRunning || p.server == nil {
		return
	}

	pipeline := p.buildPipeline()
	udpAddrs, tcpAddrs := p.cfg.DNS.EffectiveListenAddresses()
	serverCfg := ditingdns.ServerConfig{
		UDPAddresses: udpAddrs,
		TCPAddresses: tcpAddrs,
		ReadTimeout:  p.cfg.DNS.ReadTimeout,
		WriteTimeout: p.cfg.DNS.WriteTimeout,
	}

	encCfg := p.buildEncryptedServerConfig()

	old := p.server
	newSrv := ditingdns.NewServer(serverCfg, pipeline)
	newSrv.SetEncryptedConfig(encCfg)
	if err := newSrv.Start(); err != nil {
		// 新监听器起不来时保留旧的：让用户正在使用的解析中断，
		// 比让某个配置项晚一步生效严重得多
		log.Printf("[加密DNS] 重建监听器失败，继续沿用原有监听器: %v\n", err)
		return
	}

	p.server = newSrv
	if err := old.Shutdown(); err != nil {
		log.Printf("[加密DNS] 关闭旧监听器时出错: %v\n", err)
	}
}
