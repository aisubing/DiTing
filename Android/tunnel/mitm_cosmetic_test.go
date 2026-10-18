// mitm_cosmetic_test.go verifies the domain-scoped cosmetic stylesheet: a rule
// scoped to one domain must not leak to other sites, #@# exceptions must un-hide
// the selector, and the injected <link> must carry the page hostname.

package tunnel

import (
	"io"
	"net/http"
	"strings"
	"testing"
)

const cosmeticFixture = `{
  "globalHide": [".generic-ad"],
  "globalException": [],
  "domains": {
    "example.com": {"hide": [".banner-ad", ".generic-ad"], "exception": [".site-banner"]},
    "other.com": {"hide": [".banner-ad"], "exception": []},
    "site-banner": {"hide": [".site-banner"], "exception": []}
  }
}`

func TestCosmeticCssScopesRulesByHost(t *testing.T) {
	example := buildCosmeticCss(cosmeticFixture, "www.example.com")
	if !strings.Contains(example, ".banner-ad { display: none !important; }") {
		t.Fatalf("scoped rule missing for subdomain: %q", example)
	}
	if !strings.Contains(example, ".generic-ad { display: none !important; }") {
		t.Fatalf("global rule missing: %q", example)
	}

	unrelated := buildCosmeticCss(cosmeticFixture, "unrelated.org")
	if strings.Contains(unrelated, ".banner-ad") {
		t.Fatalf("example.com rule leaked to unrelated.org: %q", unrelated)
	}
	if !strings.Contains(unrelated, ".generic-ad") {
		t.Fatalf("global rule must still apply: %q", unrelated)
	}
}

func TestCosmeticCssAppliesExceptionInsteadOfHide(t *testing.T) {
	css := buildCosmeticCss(cosmeticFixture, "example.com")
	if strings.Contains(css, ".site-banner { display: none") {
		t.Fatalf("exception compiled as hide: %q", css)
	}
	if !strings.Contains(css, ".site-banner { display: revert !important; }") {
		t.Fatalf("exception override missing: %q", css)
	}
}

// A `#@#` rule with no domain scope reaches the engine as globalException.
// It used to be counted (map sized) but never copied in, so a global hide could
// never be un-hidden on any site.
const cosmeticGlobalExceptionFixture = `{
  "globalHide": [".generic-ad", ".promo"],
  "globalException": [".generic-ad"],
  "domains": {
    "example.com": {"hide": [".banner-ad"], "exception": []}
  }
}`

func TestCosmeticCssAppliesGlobalException(t *testing.T) {
	css := buildCosmeticCss(cosmeticGlobalExceptionFixture, "unrelated.org")
	if strings.Contains(css, ".generic-ad { display: none") {
		t.Fatalf("globally excepted selector still hidden: %q", css)
	}
	if !strings.Contains(css, ".generic-ad { display: revert !important; }") {
		t.Fatalf("global exception override missing: %q", css)
	}
	if !strings.Contains(css, ".promo { display: none !important; }") {
		t.Fatalf("unrelated global hide must survive: %q", css)
	}

	// A host-scoped hide of the same selector must also lose to the global
	// exception, because the exception is applied after the host walk.
	scoped := buildCosmeticCss(cosmeticGlobalExceptionFixture, "example.com")
	if strings.Contains(scoped, ".generic-ad { display: none") {
		t.Fatalf("global exception did not override host hide: %q", scoped)
	}
}

func TestCosmeticCssEmptyPayload(t *testing.T) {
	if got := buildCosmeticCss("", "example.com"); !strings.Contains(got, "no cosmetic rules") {
		t.Fatalf("unexpected stylesheet for empty payload: %q", got)
	}
}

func TestCosmeticLinkTagCarriesHost(t *testing.T) {
	tag := cosmeticLinkTag("Ads.Example.com:443")
	want := `href="https://local.pwhs.app/cosmetic.css?h=ads.example.com"`
	if !strings.Contains(tag, want) {
		t.Fatalf("link tag %q does not contain %q", tag, want)
	}
	if strings.Contains(tag, "?h=") && strings.Contains(cosmeticLinkTag(""), "?h=") {
		t.Fatalf("host-less tag must not carry a query")
	}
}

func TestServeCssUsesRequestHost(t *testing.T) {
	SetCosmeticRules(cosmeticFixture)
	defer SetCosmeticRules("")

	req, err := http.NewRequest("GET", "https://local.pwhs.app/cosmetic.css?h=example.com", nil)
	if err != nil {
		t.Fatal(err)
	}
	body, err := io.ReadAll(ServeLocalAsset(req).Body)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(body), ".banner-ad { display: none !important; }") {
		t.Fatalf("served css missing host-scoped rule: %q", string(body))
	}

	otherReq, _ := http.NewRequest("GET", "https://local.pwhs.app/cosmetic.css?h=other.org", nil)
	otherBody, err := io.ReadAll(ServeLocalAsset(otherReq).Body)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(otherBody), ".banner-ad") {
		t.Fatalf("served css leaked a scoped rule: %q", string(otherBody))
	}
}
