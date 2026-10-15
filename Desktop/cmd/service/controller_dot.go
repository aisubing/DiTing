package main

import (
	"log"

	ditingdns "github.com/haoze-evolluling/diting/desktop/internal/dns"
)

// dotALPN 为 DoT 的 ALPN 标识（RFC 7858 §3.1）。
//
// 不宣告它客户端一样能连——DoT 客户端普遍不校验 ALPN——但宣告之后，误把
// DoH/DoQ 指向这个端口的客户端会握不上手，比连上来再收到解析失败更容易定位。
var dotALPN = []string{"dot"}

// buildEncryptedServerConfig 按当前配置装配加密监听参数。
//
// 调用方需持有 p.mu。返回 nil 表示本次不开放任何加密入口——此时连证书都
// 不去取，免得在用户没开这个功能时因为证书缺失而刷出无意义的错误日志。
func (p *program) buildEncryptedServerConfig() *ditingdns.EncryptedServerConfig {
	enc := p.cfg.Encrypted
	if !enc.Enabled || !enc.DoTEnabled {
		return nil
	}
	if p.certManager == nil {
		log.Println("[加密DNS] 证书管理器未就绪，本次不开放 DoT 监听")
		return nil
	}

	tlsCfg, err := p.certManager.TLSConfig(dotALPN...)
	if err != nil {
		// 证书不可用时宁可不监听：没有证书的 DoT 端口只会让客户端
		// 卡在握手阶段，比明确拒服务更难排查
		log.Printf("[加密DNS] 服务端证书不可用，本次不开放 DoT 监听: %v\n", err)
		return nil
	}

	return &ditingdns.EncryptedServerConfig{
		DoTEnabled:    true,
		ListenAddress: enc.ListenAddress,
		DoTPort:       enc.DoTPort,
		ServerName:    enc.ServerName,
		TLSConfig:     tlsCfg,
		ReadTimeout:   ditingdns.DefaultDoTReadTimeout,
		IdleTimeout:   ditingdns.DefaultDoTIdleTimeout,
	}
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
