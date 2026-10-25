// resolver_smart_test.go covers the smart_prediction scheduler: adaptive hedge
// delay, staggered hedging, fast failover and censored loser accounting.

package tunnel

import (
	"sync/atomic"
	"testing"
	"time"

	"github.com/miekg/dns"
)

func countingHandler(counter *atomic.Int32, inner dns.HandlerFunc) dns.HandlerFunc {
	return func(w dns.ResponseWriter, r *dns.Msg) {
		counter.Add(1)
		inner(w, r)
	}
}

func TestProviderStats_HedgeDelayAndCensored(t *testing.T) {
	s := newProviderStats()
	if d := s.HedgeDelay(); d != hedgeDelayCold {
		t.Fatalf("cold hedge delay = %v, want %v", d, hedgeDelayCold)
	}
	for i := 0; i < 20; i++ {
		s.RecordSuccess(200 * time.Millisecond)
	}
	if d := s.HedgeDelay(); d < 200*time.Millisecond || d > hedgeDelayMax {
		t.Fatalf("hedge delay for stable 200ms provider = %v", d)
	}
	for i := 0; i < 20; i++ {
		s.RecordSuccess(2 * time.Millisecond)
	}
	if d := s.HedgeDelay(); d != hedgeDelayMin {
		t.Fatalf("hedge delay should clamp to %v, got %v", hedgeDelayMin, d)
	}

	before := s.Score()
	s.RecordCensored(time.Millisecond) // faster than SRTT: no information
	if s.Score() != before {
		t.Fatalf("short censored sample must not change score")
	}
	s.RecordCensored(300 * time.Millisecond)
	if s.Score() <= before || s.failureCount != 0 {
		t.Fatalf("long censored sample should raise SRTT without failure, score=%v failures=%d", s.Score(), s.failureCount)
	}
}

func TestProviderStats_FailurePenaltyDecays(t *testing.T) {
	s := newProviderStats()
	s.RecordSuccess(20 * time.Millisecond)
	for i := 0; i < 10; i++ {
		s.RecordFailure()
	}
	now := time.Now()
	fresh := s.scoreAt(now)
	later := s.scoreAt(now.Add(5 * failurePenaltyHalfLife))
	if later >= fresh {
		t.Fatalf("penalty should decay over time: fresh=%v later=%v", fresh, later)
	}
}

func TestResolver_SmartPredictionStaggeredHedge(t *testing.T) {
	var hits1, hits2, hits3 atomic.Int32
	srv1, addr1 := startMockDNSServer(t, countingHandler(&hits1, makeAnswerHandler("10.0.0.1", 400*time.Millisecond)))
	defer srv1.Shutdown()
	srv2, addr2 := startMockDNSServer(t, countingHandler(&hits2, makeAnswerHandler("10.0.0.2", 5*time.Millisecond)))
	defer srv2.Shutdown()
	srv3, addr3 := startMockDNSServer(t, countingHandler(&hits3, makeAnswerHandler("10.0.0.3", 5*time.Millisecond)))
	defer srv3.Shutdown()

	logger := &mockRaceLogger{}
	resolver := NewResolver(nil)
	resolver.SetRaceLogCallback(logger)
	if err := resolver.ConfigureProviders("smart_prediction", []dnsProviderConfig{
		{ID: "p1", Protocol: "PLAIN", Server: addr1},
		{ID: "p2", Protocol: "PLAIN", Server: addr2},
		{ID: "p3", Protocol: "PLAIN", Server: addr3},
	}); err != nil {
		t.Fatalf("ConfigureProviders failed: %v", err)
	}

	if _, err := resolver.Resolve(makeQueryMsg("hedge.example.com")); err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}
	res := logger.lastResult()
	if res == nil || res.winnerProviderID != "p2" || !res.fallbackUsed || !res.fallbackSuccess {
		t.Fatalf("expected hedged p2 to win, got %+v", res)
	}
	if hits3.Load() != 0 {
		t.Fatalf("p3 must not be queried when the first hedge answers, hits=%d", hits3.Load())
	}

	p1 := resolver.providerStatsMap["p1"]
	// The cancelled loser reports asynchronously after Resolve returns.
	var p1Samples int64
	var p1Failures int
	for deadline := time.Now().Add(time.Second); time.Now().Before(deadline); time.Sleep(5 * time.Millisecond) {
		p1.mu.RLock()
		p1Samples, p1Failures = p1.sampleCount, p1.failureCount
		p1.mu.RUnlock()
		if p1Samples > 0 || p1Failures > 0 {
			break
		}
	}
	if p1Failures != 0 || p1Samples == 0 {
		t.Fatalf("cancelled loser must be a censored sample, samples=%d failures=%d", p1Samples, p1Failures)
	}
	if p1.Score() <= resolver.providerStatsMap["p2"].Score() {
		t.Fatalf("slow loser should rank below the winner after censoring")
	}

	// The next query should prefer p2 directly.
	if _, err := resolver.Resolve(makeQueryMsg("hedge2.example.com")); err != nil {
		t.Fatalf("second Resolve failed: %v", err)
	}
	if res := logger.lastResult(); res.selectedProviderID != "p2" || res.fallbackUsed {
		t.Fatalf("expected p2 as primary without fallback, got %+v", res)
	}
}

func TestResolver_SmartPredictionFastFailover(t *testing.T) {
	srv1, addr1 := startMockDNSServer(t, makeAnswerHandler("", 0)) // SERVFAIL
	defer srv1.Shutdown()
	srv2, addr2 := startMockDNSServer(t, makeAnswerHandler("10.0.0.2", 0))
	defer srv2.Shutdown()

	logger := &mockRaceLogger{}
	resolver := NewResolver(nil)
	resolver.SetRaceLogCallback(logger)
	if err := resolver.ConfigureProviders("smart_prediction", []dnsProviderConfig{
		{ID: "p1", Protocol: "PLAIN", Server: addr1},
		{ID: "p2", Protocol: "PLAIN", Server: addr2},
	}); err != nil {
		t.Fatalf("ConfigureProviders failed: %v", err)
	}

	start := time.Now()
	if _, err := resolver.Resolve(makeQueryMsg("failover.example.com")); err != nil {
		t.Fatalf("Resolve failed: %v", err)
	}
	if elapsed := time.Since(start); elapsed >= hedgeDelayCold {
		t.Fatalf("failover should not wait for the hedge timer, took %v", elapsed)
	}
	res := logger.lastResult()
	if res == nil || res.winnerProviderID != "p2" || !res.fallbackUsed || !res.fallbackSuccess {
		t.Fatalf("expected failover to p2, got %+v", res)
	}
}
