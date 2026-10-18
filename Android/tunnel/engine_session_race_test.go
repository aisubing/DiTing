// engine_session_race_test.go pins the O-104 start/stop interleaving contract.
//
// StartFull publishes its TUN stack only after releasing e.mu for the expensive
// setup (fd dup, gVisor stack allocation, buffered-TUN writer). A Stop() landing
// inside that window sees nil slots, so the publish must be able to tell "I am
// still the session" from "I was superseded". That decision is carried by
// Engine.sessionGen rather than by e.running alone, because a Stop() followed by
// a fresh StartFull leaves running=true while the older call is still in flight.

package tunnel

import (
	"testing"
)

// A Stop() during startup must invalidate the in-flight StartFull, even if a new
// session starts immediately afterwards and sets running back to true.
func TestSessionGenInvalidatesInFlightStart(t *testing.T) {
	e := NewEngine()

	// Stand in for StartFull's capture-under-lock step.
	e.mu.Lock()
	gen := e.sessionGen
	e.mu.Unlock()

	// Stop() then a brand-new session: running ends up true again, which is
	// exactly what an e.running-only check would mistake for "still mine".
	e.Stop()
	e.mu.Lock()
	e.sessionGen++
	e.running = true
	stillCurrent := e.running && e.sessionGen == gen
	e.mu.Unlock()

	if stillCurrent {
		t.Fatal("stale StartFull was considered current after Stop + restart")
	}
}

// The common case must keep working: nothing intervenes, so the captured
// generation still identifies the live session when the publish happens.
func TestSessionGenAcceptsUninterruptedStart(t *testing.T) {
	e := NewEngine()

	e.mu.Lock()
	gen := e.sessionGen
	e.running = true
	e.mu.Unlock()

	e.mu.Lock()
	stillCurrent := e.running && e.sessionGen == gen
	e.mu.Unlock()

	if !stillCurrent {
		t.Fatal("uninterrupted StartFull was rejected as stale")
	}
}

// Stop() must bump the generation even when no tunnel was running, otherwise a
// StartFull that captured the generation and then lost the race to a Stop would
// still see a matching value and publish into a stopped engine.
func TestStopBumpsSessionGenWithoutRunningTunnel(t *testing.T) {
	e := NewEngine()
	before := e.sessionGen
	e.Stop()
	if e.sessionGen == before {
		t.Fatal("Stop did not advance sessionGen while idle")
	}
	// And it must still have released the cache (A-017 stays fixed).
	if !e.dnsCache.closed.Load() {
		t.Fatal("idle Stop no longer closes the DNS cache")
	}
}
