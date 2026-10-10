"""Fluid properties."""

from __future__ import annotations

from pydantic import BaseModel, Field


class Fluid(BaseModel):
    """Thermophysical properties of the circulating fluid (cooling water)."""

    name: str = "Cooling water"
    density: float = Field(995.0, gt=0, description="Specific mass, kg/m3")
    viscosity: float = Field(0.72e-3, gt=0, description="Dynamic viscosity, Pa.s")
    heat_capacity: float = Field(4187.0, gt=0, description="Heat capacity, J/(kg K)")
    inlet_temperature: float = Field(
        32.0, description="Cooling water supply temperature, degC (thermal check only)"
    )
