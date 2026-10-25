// resolver_smart.go implements the smart_prediction scheduling strategy.
//
// Algorithm (staggered hedging):
//   - Rank providers by expected cost (SRTT + failure cost + decayed penalty).
//   - Query the best candidate first. If it has not answered within its own
//     adaptive hedge delay (≈ SRTT + 2·RTTVAR), launch the next candidate, and so
//     on one at a time, instead of fanning out to every backup at once.
//   - A failed attempt immediately launches the next candidate (fast failover).
//   - The first valid answer wins; the losers are cancelled and recorded as
//     censored samples rather than failures.

package tunnel

import (
	"context"
	"fmt"
	"sort"
	"time"
)

type predResult struct {
	provider *configuredProvider
	response []byte
	elapsed  time.Duration
	err      error
	isBackup bool
}

// rankProviders orders providers by ascending score. Scores are computed once
// per query so the comparator does not take locks or read the clock.
func rankProviders(providers []*configuredProvider, now time.Time) []*configuredProvider {
	type ranked struct {
		p     *configuredProvider
		score time.Duration
	}
	items := make([]ranked, len(providers))
	for i, p := range providers {
		items[i] = ranked{p: p, score: defaultEWMA}
		if p.stats != nil {
			items[i].score = p.stats.scoreAt(now)
		}
	}
	sort.SliceStable(items, func(i, j int) bool { return items[i].score < items[j].score })
	out := make([]*configuredProvider, len(items))
	for i := range items {
		out[i] = items[i].p
	}
	return out
}

func providerHedgeDelay(p *configuredProvider) time.Duration {
	if p == nil || p.stats == nil {
		return hedgeDelayCold
	}
	return p.stats.HedgeDelay()
}

func (r *Resolver) resolveSmartPrediction(rawQuery []byte, queryName string, queryType uint16, startTime time.Time, snapshot *resolverSnapshot) ([]byte, error) {
	providers := snapshot.providers
	n := len(providers)
	if n == 0 {
		return nil, fmt.Errorf("no providers available")
	}
	if n == 1 {
		return r.resolveSingle(rawQuery, queryName, queryType, startTime, providers)
	}

	candidates := rankProviders(providers, startTime)
	primary := candidates[0]

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeoutPlain)
	defer cancel()

	resultCh := make(chan predResult, n)
	next := 0
	inflight := 0
	var lastLaunched *configuredProvider

	// launch starts the next acquirable candidate; false when none remain.
	launch := func() bool {
		for next < n {
			prov := candidates[next]
			isBackup := next > 0
			next++
			if !snapshot.acquire() {
				continue
			}
			inflight++
			lastLaunched = prov
			go func() {
				defer snapshot.release()
				resp, elapsed, err := r.queryConfiguredProvider(ctx, prov, rawQuery)
				resultCh <- predResult{provider: prov, response: resp, elapsed: elapsed, err: err, isBackup: isBackup}
			}()
			return true
		}
		return false
	}

	var timer *time.Timer
	var timerC <-chan time.Time
	// arm schedules the next hedge based on the latest launched candidate.
	arm := func() {
		if timer != nil {
			timer.Stop()
		}
		timer, timerC = nil, nil
		if next < n && lastLaunched != nil {
			timer = time.NewTimer(providerHedgeDelay(lastLaunched))
			timerC = timer.C
		}
	}
	defer func() {
		if timer != nil {
			timer.Stop()
		}
	}()

	if !launch() {
		return nil, fmt.Errorf("snapshot retired: primary provider could not be acquired")
	}
	arm()

	var winner *predResult
	var lastErr error
	for winner == nil && inflight > 0 {
		select {
		case <-timerC:
			launch()
			arm()
		case res := <-resultCh:
			inflight--
			if res.err == nil && res.response != nil {
				resCopy := res
				winner = &resCopy
				cancel()
				break
			}
			lastErr = res.err
			if launch() {
				arm()
			}
		}
	}

	fallbackTriggered := next > 1
	totalElapsed := time.Since(startTime).Milliseconds()
	if winner != nil {
		var selectedElapsed int64
		if !winner.isBackup {
			selectedElapsed = winner.elapsed.Milliseconds()
		}
		r.notifyRaceLog(queryName, queryType, "smart_prediction", n, true, totalElapsed,
			primary.id, selectedElapsed, winner.provider.id, winner.elapsed.Milliseconds(),
			fallbackTriggered, winner.isBackup, "")
		return winner.response, nil
	}

	var errMsg string
	if lastErr != nil {
		errMsg = lastErr.Error()
	}
	r.notifyRaceLog(queryName, queryType, "smart_prediction", n, false, totalElapsed,
		primary.id, 0, "", 0, fallbackTriggered, false, errMsg)
	return nil, lastErr
}
