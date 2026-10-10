"""Operating scenarios: sets of cooling water flow rate specifications."""

from __future__ import annotations

from pydantic import BaseModel, Field


class Scenario(BaseModel):
    """One operating scenario: the mass flow rate demanded by each heat exchanger."""

    name: str = "base"
    time_fraction: float = Field(1.0, ge=0, le=1, description="Fraction of the operating time")
    flows: dict[str, float] = Field(
        ..., description="Mass flow (kg/s) per heat exchanger tag (or edge id as string)"
    )
