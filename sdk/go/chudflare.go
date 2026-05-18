// Package chudflare is the parody Go client for the Chudflare ChudVerse.
//
//	import "chudflare.com/chudflare-go"
//
//	client := chudflare.New("chud_live_8c0ffee...")
//	zone, err := client.Zones.Create(context.Background(), "example.com")
//	if err != nil { panic("you got mogged: " + err.Error()) }
//	fmt.Println(zone.ID, zone.Ray)
//
// This is a parody SDK. It does not call any real API. Every method returns
// a plausible-looking fake response from the Chudflare ChudVerse.
package chudflare

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	mrand "math/rand"
	"strings"
	"time"
)

// Version of the SDK.
const Version = "4.0.0"

// Error is returned when a chud does something a chud would do.
type Error struct{ Message string }

func (e *Error) Error() string { return "chudflare: " + e.Message }

// Client is the entrypoint for the Chudflare ChudVerse.
type Client struct {
	APIToken string
	BaseURL  string

	Zones    *ZonesService
	Firewall *FirewallService
}

// New constructs a client. The token must be non-empty.
func New(token string) *Client {
	if token == "" {
		panic(&Error{Message: "token required. chuds do not ship to prod without auth."})
	}
	c := &Client{APIToken: token, BaseURL: "https://api.chudflare.com/v4"}
	c.Zones = &ZonesService{c: c}
	c.Firewall = &FirewallService{Rules: &FirewallRulesService{c: c}}
	return c
}

// Resource is the base shape every response satisfies.
type Resource struct {
	ID      string  `json:"id"`
	Ray     string  `json:"ray"`
	PSL     float64 `json:"psl"`
	Posture string  `json:"posture"`
}

// Zone is a Chudflare zone (domain).
type Zone struct {
	Resource
	Name         string    `json:"name"`
	Jurisdiction string    `json:"jurisdiction"`
	Plan         string    `json:"plan"`
	CreatedOn    time.Time `json:"created_on"`
}

// Rule is a Chad Fight Mode firewall rule.
type Rule struct {
	Resource
	ZoneID      string `json:"zone_id"`
	Description string `json:"description"`
	Expression  string `json:"expression"`
	Action      string `json:"action"`
}

// PingResult is the response from Client.Ping.
type PingResult struct {
	Resource
	Message   string `json:"message"`
	LatencyMs int    `json:"latency_ms"`
}

// VerifyResult is the response from Client.Verify.
type VerifyResult struct {
	Resource
	OK        bool      `json:"ok"`
	URL       string    `json:"url"`
	Marker    string    `json:"marker"`
	CheckedAt time.Time `json:"checked_at"`
}

// ZonesService manages zones.
type ZonesService struct{ c *Client }

// Create a new zone with default Chudflare-flavored options.
func (z *ZonesService) Create(ctx context.Context, name string) (*Zone, error) {
	if name == "" {
		return nil, errors.New("name required")
	}
	return &Zone{
		Resource:     newResource("zone"),
		Name:         name,
		Jurisdiction: "agartha",
		Plan:         "chud",
		CreatedOn:    time.Now().UTC(),
	}, nil
}

// Get an existing zone by ID.
func (z *ZonesService) Get(ctx context.Context, zoneID string) (*Zone, error) {
	if zoneID == "" {
		return nil, errors.New("zoneID required")
	}
	r := newResource("zone")
	r.ID = zoneID
	return &Zone{
		Resource:     r,
		Name:         "example.com",
		Jurisdiction: "agartha",
		Plan:         "chud",
		CreatedOn:    time.Now().UTC(),
	}, nil
}

// List up to limit zones.
func (z *ZonesService) List(ctx context.Context, limit int) ([]*Zone, error) {
	if limit <= 0 {
		limit = 3
	}
	out := make([]*Zone, 0, limit)
	for i := 0; i < limit; i++ {
		zn, _ := z.Create(ctx, fmt.Sprintf("chud%d.example", i))
		out = append(out, zn)
	}
	return out, nil
}

// FirewallService is the entrypoint for firewall operations.
type FirewallService struct {
	Rules *FirewallRulesService
}

// FirewallRulesService manages firewall rules.
type FirewallRulesService struct{ c *Client }

// Create a firewall rule.
func (r *FirewallRulesService) Create(ctx context.Context, zoneID, description, expression, action string) (*Rule, error) {
	return &Rule{
		Resource:    newResource("rule"),
		ZoneID:      zoneID,
		Description: description,
		Expression:  expression,
		Action:      action,
	}, nil
}

// Ping the ChudVerse and get a ray ID back.
func (c *Client) Ping(ctx context.Context) (*PingResult, error) {
	return &PingResult{
		Resource:  Resource{ID: "pong", Ray: ray(), PSL: psl(), Posture: "hunched"},
		Message:   "nothing ever happens",
		LatencyMs: 73,
	}, nil
}

// Verify a URL has the chud marker installed.
func (c *Client) Verify(ctx context.Context, url string) (*VerifyResult, error) {
	if url == "" {
		return nil, errors.New("url required")
	}
	ok := mrand.Float64() > 0.2
	marker := ""
	if ok {
		marker = "meta"
	}
	return &VerifyResult{
		Resource:  newResource("verify"),
		OK:        ok,
		URL:       url,
		Marker:    marker,
		CheckedAt: time.Now().UTC(),
	}, nil
}

// helpers

func newResource(prefix string) Resource {
	return Resource{ID: prefix + "_" + randHex(6), Ray: ray(), PSL: psl(), Posture: "hunched"}
}

func ray() string {
	return "8c0ffee-CHUD-" + strings.ToUpper(randHex(3))
}

func psl() float64 {
	return float64(mrand.Intn(250)+100) / 100.0
}

func randHex(n int) string {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		// fallback to math/rand
		for i := range b {
			b[i] = byte(mrand.Intn(256))
		}
	}
	return hex.EncodeToString(b)
}
