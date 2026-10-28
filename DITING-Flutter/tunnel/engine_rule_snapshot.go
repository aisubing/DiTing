// engine_rule_snapshot.go publishes the native rule set (mmap tries, Bloom pre-filters, $important
// tries) as one immutable snapshot behind an atomic pointer.
//
// Every DNS query used to take e.mu just to copy six slice headers, so all DNS goroutines serialized
// on the engine mutex that the UI setters, Start/Stop and the TUN writer also contend for. Writers
// still hold e.mu while they rebuild the slices; readers now take one atomic load.
//
// Lifetime: SetTries/SetImportantTries/Stop close the old mmaps under e.mu, exactly as before. A
// query racing a reload could already observe closed tries with the old copy-under-lock scheme, and
// MmapTrie/BloomFilter treat a nil buffer as "no data", so this keeps the same guarantees.

package tunnel

type nativeRuleSnapshot struct {
	adTries        []*MmapTrie
	adTrieIDs      []string
	secTries       []*MmapTrie
	secTrieIDs     []string
	adBlooms       []*BloomFilter
	secBlooms      []*BloomFilter
	importantTries []*MmapTrie
}

var emptyNativeRules = &nativeRuleSnapshot{}

// publishNativeRulesLocked must be called with e.mu held after any change to
// the rule slices. It copies the slice headers into a fresh snapshot.
func (e *Engine) publishNativeRulesLocked() {
	e.nativeRules.Store(&nativeRuleSnapshot{
		adTries:        e.adTries,
		adTrieIDs:      e.adTrieIDs,
		secTries:       e.secTries,
		secTrieIDs:     e.secTrieIDs,
		adBlooms:       e.adBlooms,
		secBlooms:      e.secBlooms,
		importantTries: e.importantTries,
	})
}

func (e *Engine) loadNativeRules() *nativeRuleSnapshot {
	if s := e.nativeRules.Load(); s != nil {
		return s
	}
	return emptyNativeRules
}

// matchNativeRules returns the IDs of every security and ad list containing
// domain (or a parent), security lists first, mirroring the original order.
func (s *nativeRuleSnapshot) matchNativeRules(domain string, firstOnly bool) []string {
	var matched []string
	match := func(tries []*MmapTrie, blooms []*BloomFilter, ids []string, fallback string) bool {
		for i, trie := range tries {
			if trie == nil {
				continue
			}
			var bloom *BloomFilter
			if i < len(blooms) {
				bloom = blooms[i]
			}
			if bloom != nil && !bloom.MightContainDomainOrParent(domain) {
				continue
			}
			if !trie.ContainsOrParent(domain) {
				continue
			}
			id := fallback
			if i < len(ids) {
				id = ids[i]
			}
			matched = append(matched, id)
			if firstOnly {
				return true
			}
		}
		return false
	}
	if match(s.secTries, s.secBlooms, s.secTrieIDs, "security") {
		return matched
	}
	match(s.adTries, s.adBlooms, s.adTrieIDs, "filter_list")
	return matched
}

// setResolverLocked must be called with e.mu held; it keeps the lock-free
// resolver view in sync with e.resolver.
func (e *Engine) setResolverLocked(r *Resolver) {
	e.resolver = r
	e.resolverView.Store(r)
}

// currentResolver is the hot-path read of e.resolver. The atomic view is the
// fast path; the locked read covers code (tests) that assigns e.resolver
// directly without going through setResolverLocked.
func (e *Engine) currentResolver() *Resolver {
	if r := e.resolverView.Load(); r != nil {
		return r
	}
	e.mu.Lock()
	r := e.resolver
	e.mu.Unlock()
	return r
}
