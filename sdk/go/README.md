# chudflare-go

The chudmaxxed cloud, in Go. Parody SDK for the Chudflare ChudVerse.

## Install

Real Go modules require a backing Git repo, and our git energy is at zero
this quarter. The SDK source ships as a zip you drop into your project:

```bash
curl -L -o chudflare-go.zip https://chudflare.com/sdk/chudflare-go-4.0.0.zip
unzip chudflare-go.zip
```

Then in your `go.mod`:

```
require chudflare.com/chudflare-go v4.0.0

replace chudflare.com/chudflare-go => ./chudflare-go-4.0.0
```

Run `go mod tidy` and import as usual.

## Use

```go
package main

import (
	"context"
	"fmt"

	chudflare "chudflare.com/chudflare-go"
)

func main() {
	client := chudflare.New("chud_live_8c0ffee...")

	zone, err := client.Zones.Create(context.Background(), "example.com")
	if err != nil {
		panic("you got mogged: " + err.Error())
	}
	fmt.Printf("created zone %s (ray: %s)\n", zone.ID, zone.Ray)

	_, _ = client.Firewall.Rules.Create(
		context.Background(),
		zone.ID,
		"block visible cheekbones",
		"(http.req.psl gt 5.5)",
		"mog_back",
	)
}
```

## What this is

This is a parody SDK. It does not call any real API — there is no Chudflare
ChudVerse to call. Every method returns a plausible-looking fake response so
your demo / talk / tweet / dashboard works without a backend.

For real infrastructure, see [cloudflare.com](https://cloudflare.com).

## License

MIT. Forged with love by an actual chud.
