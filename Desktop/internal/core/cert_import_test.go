package core

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCert_ImportPEM(t *testing.T) {
	m, _ := newTestCertManager(t)
	gen, err := GenerateSelfSignedCert(selfSignedCfg())
	if err != nil {
		t.Fatal(err)
	}

	if err := m.ImportPEM(gen.CertPEM, gen.KeyPEM); err != nil {
		t.Fatalf("导入 PEM 失败: %v", err)
	}
	info := m.Info()
	if !info.Loaded {
		t.Fatalf("导入后应载入成功: %+v", info)
	}
	if m.GetConfig().Source != CertSourceFile {
		t.Fatalf("导入后来源应切为文件，实得 %q", m.GetConfig().Source)
	}
}

// 不匹配的一对必须在导入时就拒绝，而不是留到下次启动时以握手失败呈现
func TestCert_ImportPEMMismatchedRejected(t *testing.T) {
	m, _ := newTestCertManager(t)
	a, _ := GenerateSelfSignedCert(selfSignedCfg())
	bCfg := selfSignedCfg()
	bCfg.CommonName = "other.lan"
	bCfg.DNSNames = []string{"other.lan"}
	b, _ := GenerateSelfSignedCert(bCfg)

	if err := m.ImportPEM(a.CertPEM, b.KeyPEM); err == nil {
		t.Fatal("证书与私钥不匹配时应拒绝导入")
	}
	if m.Info().Loaded {
		t.Fatal("拒绝后不应载入任何证书")
	}
}

func TestCert_ImportPEMGarbageRejected(t *testing.T) {
	m, _ := newTestCertManager(t)
	if err := m.ImportPEM([]byte("not pem"), []byte("also not pem")); err == nil {
		t.Fatal("非 PEM 输入应被拒绝")
	}
}

func TestCert_LoadFromFiles(t *testing.T) {
	dir := t.TempDir()
	gen, err := GenerateSelfSignedCert(selfSignedCfg())
	if err != nil {
		t.Fatal(err)
	}
	certPath := filepath.Join(dir, "c.pem")
	keyPath := filepath.Join(dir, "k.pem")
	if err := os.WriteFile(certPath, gen.CertPEM, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(keyPath, gen.KeyPEM, 0o600); err != nil {
		t.Fatal(err)
	}

	m := NewCertManager(dir, CertConfig{
		Source:   CertSourceFile,
		CertFile: certPath,
		KeyFile:  keyPath,
	})
	info := m.Info()
	if !info.Loaded {
		t.Fatalf("应从 PEM 文件载入: %+v", info)
	}
	if info.ChainLength != 1 {
		t.Fatalf("链长应为 1，实得 %d", info.ChainLength)
	}
}

func TestCert_ResolvePathsRejectsIncompleteConfig(t *testing.T) {
	dir := t.TempDir()

	if _, _, _, err := resolveCertPaths(dir, CertConfig{Source: CertSourceFile}); err == nil {
		t.Fatal("缺少证书路径应报错")
	}
	if _, _, _, err := resolveCertPaths(dir, CertConfig{
		Source: CertSourceFile, CertFile: "c.pem",
	}); err == nil {
		t.Fatal("缺少私钥路径应报错")
	}
	if _, _, _, err := resolveCertPaths("", CertConfig{Source: CertSourceSelfSigned}); err == nil {
		t.Fatal("缺少证书目录应报错")
	}

	// PKCS#12 的证书与私钥同在一个文件
	c, k, pw, err := resolveCertPaths(dir, CertConfig{
		Source: CertSourcePKCS12, CertFile: "bundle.p12", PKCS12Password: "s3cret",
	})
	if err != nil {
		t.Fatalf("PKCS#12 路径解析失败: %v", err)
	}
	if c != k || pw != "s3cret" {
		t.Fatalf("PKCS#12 路径解析不符: %q %q %q", c, k, pw)
	}
}

func TestCert_InfoFingerprintFormat(t *testing.T) {
	m, _ := newTestCertManager(t)
	if _, err := m.EnsureSelfSigned(selfSignedCfg()); err != nil {
		t.Fatal(err)
	}
	info := m.Info()
	parts := strings.Split(info.Fingerprint, ":")
	if len(parts) != 32 {
		t.Fatalf("SHA-256 指纹应有 32 段，实得 %d", len(parts))
	}
	for _, p := range parts {
		if len(p) != 2 || strings.ToUpper(p) != p {
			t.Fatalf("指纹段应为两位大写十六进制，实得 %q", p)
		}
	}
	if info.DaysRemaining <= 0 {
		t.Fatalf("有效期剩余天数应为正，实得 %d", info.DaysRemaining)
	}
}

func TestCert_ReloadAfterFileChange(t *testing.T) {
	dir := t.TempDir()
	first := selfSignedCfg()
	first.DNSNames = []string{"first.lan"}
	first.CommonName = "first.lan"
	gen1, _ := GenerateSelfSignedCert(first)
	certPath := filepath.Join(dir, "c.pem")
	keyPath := filepath.Join(dir, "k.pem")
	os.WriteFile(certPath, gen1.CertPEM, 0o600)
	os.WriteFile(keyPath, gen1.KeyPEM, 0o600)

	m := NewCertManager(dir, CertConfig{Source: CertSourceFile, CertFile: certPath, KeyFile: keyPath})
	if got := m.Info().DNSNames; len(got) != 1 || got[0] != "first.lan" {
		t.Fatalf("初次载入不符: %v", got)
	}

	second := selfSignedCfg()
	second.DNSNames = []string{"second.lan"}
	second.CommonName = "second.lan"
	gen2, _ := GenerateSelfSignedCert(second)
	os.WriteFile(certPath, gen2.CertPEM, 0o600)
	os.WriteFile(keyPath, gen2.KeyPEM, 0o600)

	m.Reload()
	if got := m.Info().DNSNames; len(got) != 1 || got[0] != "second.lan" {
		t.Fatalf("重载后应换上新的 SAN，实得 %v", got)
	}
}

// 证书链必须按顺序解析，且跳过非证书块
func TestCert_ParseChainSkipsNonCertBlocks(t *testing.T) {
	gen, _ := GenerateSelfSignedCert(selfSignedCfg())
	mixed := append([]byte("-----BEGIN RSA PRIVATE KEY-----\nAAAA\n-----END RSA PRIVATE KEY-----\n"), gen.CertPEM...)

	chain, err := parseChain(mixed)
	if err != nil {
		t.Fatalf("解析失败: %v", err)
	}
	if len(chain) != 1 {
		t.Fatalf("应只解析出 1 张证书，实得 %d", len(chain))
	}
}

func TestCert_ParseChainEmpty(t *testing.T) {
	if _, err := parseChain([]byte("nothing here")); err == nil {
		t.Fatal("无证书块时应报错")
	}
}
