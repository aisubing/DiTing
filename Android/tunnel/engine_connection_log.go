// engine_connection_log.go provides full-tunnel per-app traffic attribution and connection logging.
//
// Key Mechanisms:
// - Flow Attribution: In full-tunnel mode, the stack extracts the 5-tuple and queries the UID resolver
//   to identify the owning Android package, capturing apps connecting directly to hard-coded IPs (e.g. WhatsApp, Telegram).
// - JNI Memory Safety: UID-to-package resolution uses AppUidResolver (taking int arguments only) rather than
//   AppResolver to prevent Go runtime cgocheck panics under concurrent hot-path execution.
// - Deduplication & UI Pipeline: connLogSeen (sync.Map) deduplicates entries by app+dest tuple to avoid log flooding,
//   and events are dispatched through notifyLog tagged as "connection" or "firewall:<reason>".

package tunnel

import (
	"fmt"
	"sync"
	"sync/atomic"
)

// connLogSeenMaxEntries bounds the per-session connection-log deduplication set.
// The set was only ever cleared wholesale by StartFull, so a long-running VPN
// session that talked to many destinations grew it monotonically.
const connLogSeenMaxEntries = 8192

// connLogSeenDedup holds the dedupe keys for the current session together with
// the bound above. Entries are dropped on an overflow reset rather than evicted
// individually: the keys are cheap to rebuild and a stale key only costs one
// duplicate log line.
type connLogSeenDedup struct {
	mu      sync.Mutex
	seen    map[string]struct{}
	cleared atomic.Int64
}

var connLogSeen connLogSeenDedup

// markSeen stores key and reports whether it was already present. When the set
// reaches [connLogSeenMaxEntries] it is emptied first, which trades exactness for
// a bounded footprint.
func (d *connLogSeenDedup) markSeen(key string) (dup bool) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.seen == nil {
		d.seen = make(map[string]struct{}, connLogSeenMaxEntries)
	}
	if _, ok := d.seen[key]; ok {
		return true
	}
	if len(d.seen) >= connLogSeenMaxEntries {
		d.seen = make(map[string]struct{}, connLogSeenMaxEntries)
		d.cleared.Add(1)
	}
	d.seen[key] = struct{}{}
	return false
}

// reset empties the set; called when a full-tunnel session starts.
func (d *connLogSeenDedup) reset() {
	d.mu.Lock()
	d.seen = make(map[string]struct{}, connLogSeenMaxEntries)
	d.mu.Unlock()
}

// size reports the current entry count (test/telemetry helper).
func (d *connLogSeenDedup) size() int {
	d.mu.Lock()
	defer d.mu.Unlock()
	return len(d.seen)
}

func (e *Engine) appNameForFlow(flow flowID, protocol int) string {
	uidr := e.uidResolver
	r := e.appUidResolver
	if uidr == nil || r == nil {
		return ""
	}
	uid := resolveFlowUID(uidr, protocol, flow)
	if uid == UIDUnknown {
		return ""
	}
	return r.PackageForUid(uid)
}

func (e *Engine) logConnection(flow flowID, protocol int) {
	hasBatch := e.logAggregator != nil && e.logAggregator.hasCallback()
	if !hasBatch && e.logCallback == nil {
		return
	}

	uid := UIDUnknown
	if e.uidResolver != nil {
		uid = resolveFlowUID(e.uidResolver, protocol, flow)
	}
	app := ""
	if uid != UIDUnknown && e.appUidResolver != nil {
		app = e.appUidResolver.PackageForUid(uid)
	}
	if app == "" {
		if uid != UIDUnknown {
			app = fmt.Sprintf("uid:%d", uid)
		} else {
			app = "unknown"
		}
	}
	dest := flow.serverIP.String()
	key := fmt.Sprintf("%s|%s|%d|%d", app, dest, flow.serverPort, protocol)
	if connLogSeen.markSeen(key) {
		return
	}
	proto := "TCP"
	if protocol == ProtocolUDP {
		proto = "UDP"
	}

	e.notifyLog(
		fmt.Sprintf("%s %s:%d", proto, dest, flow.serverPort),
		false, 0, 0, app, dest, "connection", "", false,
	)
}

func (e *Engine) logBlockedConnection(flow flowID, protocol int, reason string) {
	if e == nil {
		return
	}
	hasBatch := e.logAggregator != nil && e.logAggregator.hasCallback()
	if !hasBatch && e.logCallback == nil {
		return
	}
	uid := UIDUnknown
	if e.uidResolver != nil {
		uid = resolveFlowUID(e.uidResolver, protocol, flow)
	}
	app := ""
	if uid != UIDUnknown && e.appUidResolver != nil {
		app = e.appUidResolver.PackageForUid(uid)
	}
	if app == "" {
		if uid != UIDUnknown {
			app = fmt.Sprintf("uid:%d", uid)
		} else {
			app = "unknown"
		}
	}
	dest := flow.serverIP.String()
	proto := "TCP"
	if protocol == ProtocolUDP {
		proto = "UDP"
	}
	key := fmt.Sprintf("blk|%s|%s|%d|%d|%s", app, dest, flow.serverPort, protocol, reason)
	if connLogSeen.markSeen(key) {
		return
	}
	e.notifyLog(
		fmt.Sprintf("%s %s:%d", proto, dest, flow.serverPort),
		true, 0, 0, app, dest, "firewall:"+reason, "", false,
	)
}
