"""chudflare — The chudmaxxed cloud, in Python.

This is a parody SDK. It does not call any real API. Every method returns a
plausible-looking fake response from the Chudflare ChudVerse.

    from chudflare import Chudflare
    client = Chudflare(api_token="chud_live_8c0ffee...")
    zone = client.zones.create(name="example.com")
    print(zone.id, zone.ray)
"""

from __future__ import annotations

import random
import time
import uuid
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

__version__ = "4.0.0"
__all__ = ["Chudflare", "ChudflareError", "__version__"]


class ChudflareError(Exception):
    """Raised when a chud does something a chud would do."""


def _ray() -> str:
    return f"8c0ffee-CHUD-{uuid.uuid4().hex[:6].upper()}"


def _psl() -> float:
    return round(random.uniform(1.0, 3.5), 2)


def _id(prefix: str) -> str:
    return f"{prefix}_{uuid.uuid4().hex[:12]}"


def _now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


@dataclass
class Resource:
    """Base response object. Attribute access works like a dict."""

    id: str
    ray: str
    psl: float
    posture: str = "hunched"
    extra: Dict[str, Any] = field(default_factory=dict)

    def __getattr__(self, name: str) -> Any:
        extra = self.__dict__.get("extra", {})
        if name in extra:
            return extra[name]
        raise AttributeError(f"{type(self).__name__!r} has no attribute {name!r}")

    def __getitem__(self, key: str) -> Any:
        if key in self.__dict__:
            return self.__dict__[key]
        return self.extra[key]

    def to_dict(self) -> Dict[str, Any]:
        return {"id": self.id, "ray": self.ray, "psl": self.psl,
                "posture": self.posture, **self.extra}


class _ZonesService:
    def __init__(self, client: "Chudflare") -> None:
        self._c = client

    def create(self, *, name: str, jurisdiction: str = "agartha",
               posture: str = "hunched", plan: str = "chud") -> Resource:
        if not name:
            raise ChudflareError("name required. chuds need a domain to chud.")
        return Resource(
            id=_id("zone"), ray=_ray(), psl=_psl(), posture=posture,
            extra={"name": name, "jurisdiction": jurisdiction, "plan": plan,
                   "created_on": _now()},
        )

    def list(self, *, limit: int = 3) -> List[Resource]:
        return [self.create(name=f"chud{i}.example") for i in range(limit)]

    def get(self, zone_id: str) -> Resource:
        return Resource(id=zone_id, ray=_ray(), psl=_psl(),
                        extra={"name": "example.com", "plan": "chud",
                               "created_on": _now()})


class _FirewallRulesService:
    def __init__(self, client: "Chudflare") -> None:
        self._c = client

    def create(self, *, zone_id: str, description: str, expression: str,
               action: str) -> Resource:
        return Resource(
            id=_id("rule"), ray=_ray(), psl=_psl(),
            extra={"zone_id": zone_id, "description": description,
                   "expression": expression, "action": action},
        )


class _FirewallService:
    def __init__(self, client: "Chudflare") -> None:
        self.rules = _FirewallRulesService(client)


class Chudflare:
    """The Chudflare ChudVerse client.

    Pass an API token (any non-empty string works in this parody SDK):

        client = Chudflare(api_token="chud_live_8c0ffee...")
        zone = client.zones.create(name="example.com")
    """

    def __init__(self, api_token: Optional[str] = None,
                 base_url: str = "https://api.chudflare.com/v4") -> None:
        if not api_token:
            raise ChudflareError(
                "api_token required. chuds do not ship to prod without auth.")
        self.api_token = api_token
        self.base_url = base_url
        self.zones = _ZonesService(self)
        self.firewall = _FirewallService(self)

    def __repr__(self) -> str:
        return f"<Chudflare base_url={self.base_url!r} v{__version__}>"

    def ping(self) -> Resource:
        return Resource(id="pong", ray=_ray(), psl=_psl(),
                        extra={"message": "nothing ever happens",
                               "latency_ms": 73})

    def verify(self, *, url: str) -> Resource:
        if not url:
            raise ChudflareError("url required.")
        ok = random.random() > 0.2
        return Resource(
            id=_id("verify"), ray=_ray(), psl=_psl(),
            extra={"ok": ok, "url": url, "marker": "meta" if ok else None,
                   "checked_at": _now()},
        )
