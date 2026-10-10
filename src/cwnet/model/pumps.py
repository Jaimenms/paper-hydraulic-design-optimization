"""Pump alternatives (characteristic curves) and the pump edge of the network."""

from __future__ import annotations

import numpy as np
from pydantic import BaseModel, Field, field_validator


class PumpCurve(BaseModel):
    """A commercial pump alternative described by its characteristic curve.

    The head (m) is a polynomial of the volumetric flow rate ``q`` (m3/s):
    ``H(q) = a0 + a1 q + a2 q^2 + ...`` with ``coefficients = [a0, a1, a2, ...]``.
    """

    tag: str
    coefficients: list[float] = Field(..., min_length=1, description="[a0, a1, a2, ...]")
    efficiency: float = Field(0.6, gt=0, le=1, description="Overall pump+motor efficiency")
    rated_flow: float | None = Field(
        None,
        gt=0,
        description="Rated volumetric flow, m3/s, used for the capital cost estimate "
        "(defaults to the total design flow of the network)",
    )

    @field_validator("coefficients")
    @classmethod
    def _strip_trailing_zeros(cls, coefs: list[float]) -> list[float]:
        coefs = [float(c) for c in coefs]
        while len(coefs) > 1 and coefs[-1] == 0.0:
            coefs.pop()
        return coefs

    def head(self, q):  # type: ignore[no-untyped-def]
        """Pump head (m) at volumetric flow ``q`` (m3/s)."""
        q = np.asarray(q, dtype=float)
        return np.polynomial.polynomial.polyval(np.abs(q), self.coefficients)

    def head_from_mass_flow(self, k, density: float):  # type: ignore[no-untyped-def]
        return self.head(np.asarray(k, dtype=float) / density)


class PumpUnit(BaseModel):
    """The pump edge of the digraph."""

    edge: int = Field(..., description="Edge id of the pump")
    tag: str = "P-101"
    existing: bool = Field(False, description="True if a pump is already installed (revamp)")
    curve: str | None = Field(
        None, description="Tag of the installed curve (required when existing=True)"
    )

    @field_validator("curve")
    @classmethod
    def _strip(cls, v: str | None) -> str | None:
        return v.strip() if isinstance(v, str) else v
