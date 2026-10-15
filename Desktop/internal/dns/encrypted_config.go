package dns

import (
	"crypto/tls"
	"fmt"
	"net"
	"strconv"
	"strings"
	"time"

	"github.com/haoze-evolluling/diting/desktop/internal/core"
)

// DoT 的默认参数。读超时沿用明文 TCP 的量级，空闲超时放宽到 30 秒：
// 加密客户端普遍维持长连接，用明文那样的短空闲窗口会让它们反复重握手。
const (
	DefaultDoTReadTimeout = 5 * time.Second
	DefaultDoTIdleTimeout = 30 * time.Second
)

// EncryptedServerConfig 加密 DNS 监听配置。
//
// 与 core.EncryptedDNSConfig 分开：那是「用户配置了什么」的持久化形态，
// 这里是「本次要监听什么」的运行形态。证书已经由 CertManager 载入成
// *tls.Config，配置里不再出现任何文件路径。
type EncryptedServerConfig struct {
	DoTEnabled bool
	// ListenAddress 为空表示所有网卡；端口取自 core.EncryptedDNSConfig
	ListenAddress string
	DoTPort       int
	// ServerName 用于从 SNI 中剥离 ClientID
	ServerName string
	// TLSConfig 已载入服务端证书；为 nil 时不监听任何加密端口
	TLSConfig *tls.Config
	// ReadTimeout / IdleTimeout 见上方默认值
	ReadTimeout time.Duration
	IdleTimeout time.Duration
}

// DoTListenAddress 返回 DoT 的监听地址，形如 0.0.0.0:853。
//
// 空监听地址必须展开成 0.0.0.0 而不是交给 net.Listen 当 "": 后者在部分
// 平台上会同时抢 v4/v6 通配地址，与明文 DNS 已有的 [::] 监听撞车。
func (c EncryptedServerConfig) DoTListenAddress() string {
	host := strings.TrimSpace(c.ListenAddress)
	if host == "" {
		host = "0.0.0.0"
	}
	port := c.DoTPort
	if port <= 0 || port > 65535 {
		port = core.DefaultDoTPort
	}
	return net.JoinHostPort(host, strconv.Itoa(port))
}

// Validate 校验监听配置是否足以开工。
func (c EncryptedServerConfig) Validate() error {
	if c.DoTPort <= 0 || c.DoTPort > 65535 {
		return fmt.Errorf("DoT 端口 %d 非法", c.DoTPort)
	}
	if c.ListenAddress != "" {
		if ip := net.ParseIP(strings.TrimSpace(c.ListenAddress)); ip == nil {
			return fmt.Errorf("监听地址 %q 不是合法 IP", c.ListenAddress)
		}
	}
	return nil
}
