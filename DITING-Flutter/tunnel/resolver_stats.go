// resolver_stats.go tracks performance metrics and health statistics for configured upstream DNS providers,
// recording latency measurements, error rates, and query success counters.
//
// The model follows TCP's RTO estimator: a smoothed RTT (SRTT) plus a smoothed
// mean deviation (RTTVAR). Together with an EWMA failure ratio and a time-decayed
// consecutive-failure penalty they drive the smart_prediction ranking and the
// adaptive hedge delay.

package tunnel

import (
	"math"
	"sync"
	"time"
)

type providerStats struct {
	mu           sync.RWMutex
	ewmaRTT      time.Duration // smoothed RTT (SRTT)
	rttVar       time.Duration // smoothed mean deviation of RTT (RTTVAR)
	failRate     float64       // EWMA of the failure ratio in [0, 1]
	failureCount int           // consecutive failures since the last success
	lastFailure  time.Time
	lastSuccess  time.Time
	sampleCount  int64
}

const (
	defaultEWMA   = 50 * time.Millisecond
	ewmaAlpha     = 0.3
	rttVarBeta    = 0.25
	failRateAlpha = 0.2

	// failRateCost is the expected latency cost of a failed attempt; a provider
	// failing 10% of the time is ranked as if it were 100ms slower.
	failRateCost           = time.Second
	failurePenaltyStep     = 100 * time.Millisecond
	failurePenaltyMax      = 5 * time.Second
	failurePenaltyHalfLife = 30 * time.Second

	// Hedge delay bounds for smart_prediction. Cold providers (no samples yet)
	// hedge quickly so the backups get measured early.
	hedgeDelayCold = 50 * time.Millisecond
	hedgeDelayMin  = 20 * time.Millisecond
	hedgeDelayMax  = 800 * time.Millisecond
	hedgeVarFactor = 2
)

func newProviderStats() *providerStats {
	return &providerStats{
		ewmaRTT: defaultEWMA,
	}
}

// observeRTTLocked folds one RTT sample into SRTT/RTTVAR. Caller holds s.mu.
func (s *providerStats) observeRTTLocked(rtt time.Duration) {
	if s.sampleCount == 0 {
		s.ewmaRTT = rtt
		s.rttVar = rtt / 2
	} else {
		dev := rtt - s.ewmaRTT
		if dev < 0 {
			dev = -dev
		}
		s.rttVar = time.Duration((1.0-rttVarBeta)*float64(s.rttVar) + rttVarBeta*float64(dev))
		s.ewmaRTT = time.Duration((1.0-ewmaAlpha)*float64(s.ewmaRTT) + ewmaAlpha*float64(rtt))
	}
	s.sampleCount++
}

func (s *providerStats) RecordSuccess(rtt time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastSuccess = time.Now()
	s.failureCount = 0
	s.failRate *= 1.0 - failRateAlpha
	s.observeRTTLocked(rtt)
}

func (s *providerStats) RecordFailure() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.lastFailure = time.Now()
	s.failureCount++
	s.failRate = (1.0-failRateAlpha)*s.failRate + failRateAlpha
}

// RecordCensored records a query that was cancelled because another provider
// answered first. It is not a failure, but the provider was at least `elapsed`
// slow, so it is used as a lower-bound RTT sample when it exceeds SRTT. This lets
// a provider that keeps losing races drift down the ranking instead of being
// either punished as broken or never re-evaluated.
func (s *providerStats) RecordCensored(elapsed time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.sampleCount > 0 && elapsed <= s.ewmaRTT {
		return
	}
	if s.sampleCount == 0 && elapsed <= defaultEWMA {
		return
	}
	s.observeRTTLocked(elapsed)
}

func (s *providerStats) Score() time.Duration {
	return s.scoreAt(time.Now())
}

// scoreAt returns the expected cost of using this provider: SRTT plus a failure
// ratio cost plus a consecutive-failure penalty that halves every
// failurePenaltyHalfLife, so a recovered provider regains its rank smoothly.
func (s *providerStats) scoreAt(now time.Time) time.Duration {
	s.mu.RLock()
	defer s.mu.RUnlock()
	score := s.ewmaRTT + time.Duration(s.failRate*float64(failRateCost))
	if s.failureCount > 0 {
		penalty := time.Duration(s.failureCount) * failurePenaltyStep
		if penalty > failurePenaltyMax {
			penalty = failurePenaltyMax
		}
		if !s.lastFailure.IsZero() {
			if since := now.Sub(s.lastFailure); since > 0 {
				decay := math.Exp2(-float64(since) / float64(failurePenaltyHalfLife))
				penalty = time.Duration(float64(penalty) * decay)
			}
		}
		score += penalty
	}
	return score
}

// HedgeDelay returns how long smart_prediction waits on this provider before
// launching the next candidate: roughly its tail latency (SRTT + k*RTTVAR).
func (s *providerStats) HedgeDelay() time.Duration {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if s.sampleCount == 0 {
		return hedgeDelayCold
	}
	d := s.ewmaRTT + hedgeVarFactor*s.rttVar
	if d < hedgeDelayMin {
		d = hedgeDelayMin
	}
	if d > hedgeDelayMax {
		d = hedgeDelayMax
	}
	return d
}
