// engine_lifecycle_test.go pins the Engine teardown contract (A-017).
//
// NewEngine eagerly allocates a DNS cache whose cleaner goroutine ticks every
// 30 seconds, so an Engine that is dropped without Stop() leaks that goroutine
// for the rest of the process lifetime. The Android CA helper mints a throwaway
// Engine per certificate call, which turned the leak into an unbounded one.
//
// The assertions here are deliberately observable from outside the cache: after
// Stop(), the cache reports itself closed and a second Stop() is a no-op.

package tunnel

import (
	"testing"
)

func TestEngineStopClosesDNSCache(t *testing.T) {
	e := NewEngine()
	cache := e.dnsCache
	if cache == nil {
		t.Fatal("NewEngine did not allocate a DNS cache")
	}
	if cache.closed.Load() {
		t.Fatal("fresh cache reports itself closed before Stop")
	}

	e.Stop()

	if !cache.closed.Load() {
		t.Fatal("Engine.Stop did not close the DNS cache cleaner (goroutine leak)")
	}
}

// Stop() runs on every service teardown path and is routinely called twice
// (service onDestroy plus the tunnel manager). A double close would panic on the
// closed stopCleaner channel, so the second call must be inert.
func TestEngineStopIsIdempotent(t *testing.T) {
	e := NewEngine()
	e.Stop()
	e.Stop()
	e.Stop()

	if !e.dnsCache.closed.Load() {
		t.Fatal("cache should still report closed after repeated Stop calls")
	}
}

// The MITM certificate cache is likewise released on Stop so a restarted Engine
// does not keep certificates for hosts the user has since removed.
func TestEngineStopReleasesCertCache(t *testing.T) {
	e := NewEngine()
	e.Stop()

	if e.stackCertMgr != nil {
		t.Fatal("Engine.Stop left the MITM certificate manager attached")
	}
}
