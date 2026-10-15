package dns

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/miekg/dns"
)

// ServerConfig 定义 DNS 本地服务监听配置
type ServerConfig struct {
	UDPAddresses []string      `json:"udpAddresses"`
	TCPAddresses []string      `json:"tcpAddresses"`
	ReadTimeout  time.Duration `json:"readTimeout"`
	WriteTimeout time.Duration `json:"writeTimeout"`
}

// DefaultServerConfig 返回标准默认双栈配置 (127.0.0.1:53 与 [::1]:53)
func DefaultServerConfig() ServerConfig {
	return ServerConfig{
		UDPAddresses: []string{"127.0.0.1:53", "[::1]:53"},
		TCPAddresses: []string{"127.0.0.1:53", "[::1]:53"},
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 5 * time.Second,
	}
}

// Server 基于 miekg/dns 的双栈 UDP/TCP DNS 监听服务
type Server struct {
	mu            sync.Mutex
	config        ServerConfig
	pipeline      *Pipeline
	servers       []*dns.Server
	activeQueries sync.WaitGroup
	started       atomic.Bool
	closed        atomic.Bool
	ctx           context.Context
	cancel        context.CancelFunc

	// encrypted 为加密监听配置；nil 表示本次不开放加密入口
	encrypted *EncryptedServerConfig
	// dot 为已激活的 DoT 监听器；未启用时为 nil
	dot *dotListener
}

// SetEncryptedConfig 设置加密 DNS 监听配置，须在 Start 之前调用。
//
// 单独一个方法而不是塞进 NewServer 的参数：加密入口是可选能力，
// 绝大多数调用方（含测试）只关心明文监听，不该被迫构造一份假证书。
func (s *Server) SetEncryptedConfig(cfg *EncryptedServerConfig) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.encrypted = cfg
}

// EncryptedEnabled 报告是否有任何加密监听器处于启用状态
func (s *Server) EncryptedEnabled() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.encrypted != nil && s.encrypted.DoTEnabled
}

// NewServer 创建 DNS 监听服务
func NewServer(config ServerConfig, pipeline *Pipeline) *Server {
	if len(config.UDPAddresses) == 0 && len(config.TCPAddresses) == 0 {
		config = DefaultServerConfig()
	}
	config.UDPAddresses = DeduplicateAddresses(config.UDPAddresses)
	config.TCPAddresses = DeduplicateAddresses(config.TCPAddresses)
	if config.ReadTimeout <= 0 {
		config.ReadTimeout = 5 * time.Second
	}
	if config.WriteTimeout <= 0 {
		config.WriteTimeout = 5 * time.Second
	}

	return &Server{
		config:   config,
		pipeline: pipeline,
	}
}

// Start 启动双栈 UDP/TCP 监听器
func (s *Server) Start() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.started.Load() {
		return fmt.Errorf("server already started")
	}

	servers := make([]*dns.Server, 0)
	boundCount := 0

	// 启动 UDP 监听器
	for _, addr := range s.config.UDPAddresses {
		network := "udp"
		if isIPv6(addr) {
			network = "udp6"
		} else {
			network = "udp4"
		}

		conn, err := net.ListenPacket(network, addr)
		if err != nil {
			// 若 IPv6 地址绑定失败（部分系统禁用 IPv6），容错降级
			if isIPv6(addr) {
				continue
			}
			s.cleanupServers(servers)
			return fmt.Errorf("bind udp %s failed: %w", addr, err)
		}

		udpServer := &dns.Server{
			PacketConn:   conn,
			Handler:      dns.HandlerFunc(s.ServeDNS),
			ReadTimeout:  s.config.ReadTimeout,
			WriteTimeout: s.config.WriteTimeout,
			UDPSize:      dns.MaxMsgSize,
		}
		servers = append(servers, udpServer)
		boundCount++
	}

	// 启动 TCP 监听器
	for _, addr := range s.config.TCPAddresses {
		network := "tcp"
		if isIPv6(addr) {
			network = "tcp6"
		} else {
			network = "tcp4"
		}

		listener, err := net.Listen(network, addr)
		if err != nil {
			if isIPv6(addr) {
				continue
			}
			s.cleanupServers(servers)
			return fmt.Errorf("bind tcp %s failed: %w", addr, err)
		}

		tcpServer := &dns.Server{
			Listener:     listener,
			Handler:      dns.HandlerFunc(s.ServeDNS),
			ReadTimeout:  s.config.ReadTimeout,
			WriteTimeout: s.config.WriteTimeout,
		}
		servers = append(servers, tcpServer)
		boundCount++
	}

	if boundCount == 0 {
		s.cleanupServers(servers)
		return fmt.Errorf("failed to bind any DNS listener (all UDP/TCP listeners failed)")
	}

	s.servers = servers
	s.started.Store(true)
	s.closed.Store(false)
	ctx, cancel := context.WithCancel(context.Background())
	s.ctx = ctx
	s.cancel = cancel

	// 异步激活每个 listener
	for _, srv := range servers {
		go func(server *dns.Server) {
			_ = server.ActivateAndServe()
		}(srv)
	}

	// 加密监听是附加能力：绑定失败只记日志，不能让明文解析跟着起不来
	if s.encrypted != nil && s.encrypted.DoTEnabled {
		if err := s.startDoT(); err != nil {
			log.Printf("[DNS] DoT 监听器启动失败，加密解析暂不可用: %v\n", err)
		} else {
			log.Printf("[DNS] DoT 监听器已就绪: %s\n", s.encrypted.DoTListenAddress())
		}
	}

	return nil
}

// ServeDNS 处理单次 DNS 协议请求
func (s *Server) ServeDNS(w dns.ResponseWriter, r *dns.Msg) {
	if r == nil {
		return
	}
	if s.closed.Load() {
		dns.HandleFailed(w, r)
		return
	}

	protocol := "udp"
	if _, ok := w.RemoteAddr().(*net.TCPAddr); ok {
		protocol = "tcp"
	}
	s.handleQuery(w, r, protocol, "")
}

// handleEncryptedQuery 处理来自加密监听器的查询。
//
// 与明文入口共用同一条流水线：加密只改变报文怎么来、应答怎么回去，
// 不该改变一次查询被怎样解析。serverName 用于识别 ClientID，明文入口传空串。
func (s *Server) handleEncryptedQuery(w dns.ResponseWriter, r *dns.Msg, protocol, serverName string) {
	if r == nil {
		return
	}
	if s.closed.Load() {
		dns.HandleFailed(w, r)
		return
	}
	s.handleQuery(w, r, protocol, serverName)
}

// handleQuery 执行一次查询：构造上下文、跑流水线、写回应答。
func (s *Server) handleQuery(w dns.ResponseWriter, r *dns.Msg, protocol, serverName string) {
	s.activeQueries.Add(1)
	defer s.activeQueries.Done()

	timeout := s.config.ReadTimeout + s.config.WriteTimeout
	if timeout <= 0 {
		timeout = 5 * time.Second
	}
	baseCtx := s.ctx
	if baseCtx == nil {
		baseCtx = context.Background()
	}
	queryCtx, queryCancel := context.WithTimeout(baseCtx, timeout)
	defer queryCancel()

	dnsCtx := NewDNSContext(queryCtx, r, w.RemoteAddr(), protocol)
	applyEncryptedClientID(dnsCtx, serverName, s.ServerName())

	if s.pipeline != nil {
		_ = s.pipeline.Execute(dnsCtx)
	}

	if dnsCtx.Resp != nil {
		dnsCtx.Resp.Id = r.Id
		if protocol == "udp" {
			maxSize := dns.MinMsgSize
			if opt := r.IsEdns0(); opt != nil {
				maxSize = int(opt.UDPSize())
			}
			if maxSize < dns.MinMsgSize {
				maxSize = dns.MinMsgSize
			}
			dnsCtx.Resp.Truncate(maxSize)
		}
		_ = w.WriteMsg(dnsCtx.Resp)
	} else {
		dns.HandleFailed(w, r)
	}
}

// serving 报告服务是否仍在接收查询。
func (s *Server) serving() bool {
	return s.started.Load() && !s.closed.Load()
}

// ServerName 返回用户在加密配置里填写的服务器名；未配置时为空串。
func (s *Server) ServerName() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.encrypted == nil {
		return ""
	}
	return s.encrypted.ServerName
}

// Shutdown 优雅关闭监听器并等待进行中请求结束
func (s *Server) Shutdown() error {
	s.mu.Lock()
	if !s.started.Load() || s.closed.Load() {
		s.mu.Unlock()
		return nil
	}
	s.closed.Store(true)
	s.started.Store(false)
	if s.cancel != nil {
		s.cancel()
		s.cancel = nil
	}
	servers := s.servers
	s.servers = nil
	dot := s.dot
	s.dot = nil
	s.mu.Unlock()

	// 先关闭所有网络监听，拒绝新连接
	s.cleanupServers(servers)
	if dot != nil {
		dot.close()
	}

	// 等待活跃请求在超时内完成
	waitCh := make(chan struct{})
	go func() {
		s.activeQueries.Wait()
		close(waitCh)
	}()

	select {
	case <-waitCh:
	case <-time.After(3 * time.Second):
		// 优雅超时强行退出
	}

	return nil
}

func (s *Server) cleanupServers(servers []*dns.Server) {
	for _, srv := range servers {
		if srv != nil {
			_ = srv.Shutdown()
			if srv.PacketConn != nil {
				_ = srv.PacketConn.Close()
			}
			if srv.Listener != nil {
				_ = srv.Listener.Close()
			}
		}
	}
}

func isIPv6(addr string) bool {
	host, _, err := net.SplitHostPort(addr)
	if err == nil {
		ip := net.ParseIP(host)
		return ip != nil && ip.To4() == nil
	}
	ip := net.ParseIP(strings.Trim(addr, "[]"))
	return ip != nil && ip.To4() == nil
}

// DeduplicateAddresses 去除重复及被全通配地址覆盖的地址
func DeduplicateAddresses(addrs []string) []string {
	if len(addrs) == 0 {
		return nil
	}
	seen := make(map[string]bool)
	wildcardPortsV4 := make(map[string]bool)
	wildcardPortsV6 := make(map[string]bool)

	// 第一轮：记录已有的 0.0.0.0 和 [::] 通配端口
	for _, a := range addrs {
		host, port, err := net.SplitHostPort(a)
		if err == nil {
			if host == "0.0.0.0" {
				wildcardPortsV4[port] = true
			} else if host == "::" {
				wildcardPortsV6[port] = true
			}
		}
	}

	result := make([]string, 0, len(addrs))
	for _, a := range addrs {
		if seen[a] {
			continue
		}
		host, port, err := net.SplitHostPort(a)
		if err == nil {
			// 若已有 0.0.0.0:port，则过滤同端口的其他所有 IPv4 地址，防止 Windows 套接字冲突
			if wildcardPortsV4[port] && host != "0.0.0.0" && !isIPv6(a) {
				continue
			}
			// 若已有 [::]:port，则过滤同端口的其他所有 IPv6 地址
			if wildcardPortsV6[port] && host != "::" && isIPv6(a) {
				continue
			}
		}
		seen[a] = true
		result = append(result, a)
	}
	return result
}
