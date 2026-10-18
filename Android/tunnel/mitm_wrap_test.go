// mitm_wrap_test.go pins the framing of responses that went through cosmetic
// injection: the body length is unknown, so the response must still tell the
// client where the body ends (Connection: close, chunked or Content-Length).
// Without that an HTTP/1.1 keep-alive client waits for a boundary that never
// arrives and the page never finishes loading.

package tunnel

import (
	"bufio"
	"bytes"
	"io"
	"net/http"
	"strings"
	"testing"
)

// readUpstreamResponse parses a raw HTTP/1.1 response the same way the relay
// does, so the test exercises the real *http.Response the injection rewrites.
func readUpstreamResponse(t *testing.T, raw string, method string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(method, "http://example.com/page", nil)
	if err != nil {
		t.Fatalf("build request: %v", err)
	}
	resp, err := http.ReadResponse(bufio.NewReader(strings.NewReader(raw)), req)
	if err != nil {
		t.Fatalf("read response: %v", err)
	}
	return resp
}

// serializeResponse writes resp to a buffer and returns the raw bytes, which is
// exactly what relayHTTPFlow hands to the client connection.
func serializeResponse(t *testing.T, resp *http.Response) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := resp.Write(&buf); err != nil {
		t.Fatalf("write response: %v", err)
	}
	return buf.Bytes()
}

func TestInjectedResponseIsSelfDelimiting(t *testing.T) {
	SetCosmeticRules(cosmeticFixture)
	defer SetCosmeticRules("")

	const raw = "HTTP/1.1 200 OK\r\n" +
		"Content-Type: text/html; charset=utf-8\r\n" +
		"Content-Length: 46\r\n" +
		"\r\n" +
		"<html><head><title>t</title></head><body>x</body></html>"

	resp := readUpstreamResponse(t, raw, "GET")
	if !ShouldInjectHTML(resp.Header.Get("Content-Type")) {
		t.Fatal("fixture must be treated as injectable HTML")
	}
	wrapResponseForInjection(resp, "example.com")

	wire := serializeResponse(t, resp)

	head, body, found := strings.Cut(string(wire), "\r\n\r\n")
	if !found {
		t.Fatalf("no header/body separator in %q", wire)
	}
	lowerHead := strings.ToLower(head)
	closeDelimited := strings.Contains(lowerHead, "connection: close")
	chunked := strings.Contains(lowerHead, "transfer-encoding: chunked")
	hasContentLength := strings.Contains(lowerHead, "content-length:")
	if !closeDelimited && !chunked && !hasContentLength {
		t.Fatalf("injected response has no body boundary (keep-alive client would hang); headers: %q", head)
	}
	if !strings.Contains(body, "cosmetic.css") {
		t.Fatalf("injection missing from body: %q", body)
	}
	if resp.Close != true {
		t.Fatal("relay only closes the connection on resp.Close, so it must be set")
	}
}

// A HEAD response has no body at all, but the injected variant used to lose its
// Content-Length as well, leaving the client with nothing to size the response by.
func TestInjectedHeadResponseKeepsFraming(t *testing.T) {
	SetCosmeticRules(cosmeticFixture)
	defer SetCosmeticRules("")

	const raw = "HTTP/1.1 200 OK\r\n" +
		"Content-Type: text/html; charset=utf-8\r\n" +
		"Content-Length: 46\r\n" +
		"\r\n"

	resp := readUpstreamResponse(t, raw, "HEAD")
	wrapResponseForInjection(resp, "example.com")
	wire := serializeResponse(t, resp)

	head := string(wire)
	if !strings.Contains(strings.ToLower(head), "connection: close") &&
		!strings.Contains(strings.ToLower(head), "content-length:") {
		t.Fatalf("HEAD response lost its framing: %q", head)
	}
}

// Injection must stay streaming: a large body may not be buffered just to compute
// a Content-Length, so the reader has to yield the injected tag while the upstream
// body is still being produced.
func TestInjectionStreamsWithoutBufferingWholeBody(t *testing.T) {
	SetCosmeticRules(cosmeticFixture)
	defer SetCosmeticRules("")

	upstream := io.MultiReader(
		strings.NewReader("<html><head>"),
		&countingReader{remaining: 4 << 20},
	)
	reader := NewInjectingReader(upstream, "example.com")
	out, err := io.ReadAll(io.LimitReader(reader, 4096))
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if !strings.Contains(string(out), "cosmetic.css") {
		t.Fatalf("injection did not stream: %q", string(out[:min(len(out), 200)]))
	}
}

type countingReader struct{ remaining int }

func (c *countingReader) Read(p []byte) (int, error) {
	if c.remaining <= 0 {
		return 0, io.EOF
	}
	n := len(p)
	if n > c.remaining {
		n = c.remaining
	}
	for i := 0; i < n; i++ {
		p[i] = 'x'
	}
	c.remaining -= n
	return n, nil
}
