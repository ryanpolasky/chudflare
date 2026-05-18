package chudflare

import (
	"context"
	"strings"
	"testing"
)

func TestZoneCreate(t *testing.T) {
	c := New("chud_live_test")
	z, err := c.Zones.Create(context.Background(), "example.com")
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if z.Name != "example.com" {
		t.Errorf("name = %q, want example.com", z.Name)
	}
	if !strings.HasPrefix(z.ID, "zone_") {
		t.Errorf("id = %q, want zone_ prefix", z.ID)
	}
	if !strings.HasPrefix(z.Ray, "8c0ffee-CHUD-") {
		t.Errorf("ray = %q, want 8c0ffee-CHUD- prefix", z.Ray)
	}
	if z.Posture != "hunched" {
		t.Errorf("posture = %q, want hunched", z.Posture)
	}
}

func TestPing(t *testing.T) {
	c := New("chud_live_test")
	p, err := c.Ping(context.Background())
	if err != nil {
		t.Fatalf("ping: %v", err)
	}
	if p.Message != "nothing ever happens" {
		t.Errorf("message = %q", p.Message)
	}
	if p.LatencyMs != 73 {
		t.Errorf("latency_ms = %d, want 73", p.LatencyMs)
	}
}

func TestFirewallRuleCreate(t *testing.T) {
	c := New("chud_live_test")
	r, err := c.Firewall.Rules.Create(context.Background(),
		"zone_abc", "block visible cheekbones",
		"(http.req.psl gt 5.5)", "mog_back")
	if err != nil {
		t.Fatalf("rule: %v", err)
	}
	if r.Action != "mog_back" {
		t.Errorf("action = %q", r.Action)
	}
}

func TestEmptyTokenPanics(t *testing.T) {
	defer func() {
		if recover() == nil {
			t.Fatal("expected panic on empty token")
		}
	}()
	New("")
}
