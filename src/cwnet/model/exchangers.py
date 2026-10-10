"""Heat exchanger edges (cooling water consumers)."""

from __future__ import annotations

from enum import IntEnum

import numpy as np
from pydantic import BaseModel, Field, model_validator


class FlowArrangement(IntEnum):
    """Flow arrangement used by the effectiveness-NTU thermal check."""

    PARALLEL = 1
    COUNTERFLOW = 2
    SHELL_AND_TUBE_1N = 3


class ThermalDesign(BaseModel):
    """Thermal design data of a shell-and-tube cooler (only needed for the thermal check).

    The cold stream is the cooling water of the network; the hot stream is the process fluid.
    """

    area: float = Field(..., gt=0, description="Heat transfer area, m2")
    h_tube: float = Field(..., gt=0, description="Design film coefficient, tube side, W/(m2 K)")
    h_shell: float = Field(..., gt=0, description="Design film coefficient, shell side, W/(m2 K)")
    fouling_tube: float = Field(0.0, ge=0, description="Fouling resistance, tube side, m2 K/W")
    fouling_shell: float = Field(0.0, ge=0, description="Fouling resistance, shell side, m2 K/W")
    tube_conductivity: float = Field(20.0, gt=0, description="Tube wall conductivity, W/(m K)")
    tube_inner_diameter: float = Field(0.01575, gt=0, description="m")
    tube_outer_diameter: float = Field(0.01905, gt=0, description="m")
    arrangement: FlowArrangement = FlowArrangement.SHELL_AND_TUBE_1N
    cold_in_tubes: bool = Field(True, description="True if cooling water flows inside the tubes")
    hot_flow: float = Field(..., gt=0, description="Hot stream mass flow rate, kg/s")
    hot_heat_capacity: float = Field(..., gt=0, description="Hot stream heat capacity, J/(kg K)")
    hot_inlet_temperature: float = Field(..., description="degC")
    hot_outlet_temperature: float = Field(..., description="Design (target) value, degC")
    cold_outlet_temperature: float = Field(..., description="Design (target) value, degC")


class HeatExchanger(BaseModel):
    """A heat exchanger edge fed with cooling water."""

    edge: int = Field(..., description="Edge id of the heat exchanger")
    tag: str
    design_flow: float = Field(..., gt=0, description="Cooling water design mass flow, kg/s")
    design_head_loss: float = Field(..., ge=0, description="Head loss at design flow, m")
    head_loss_exponent: float = Field(
        1.8, gt=0, description="Exponent alpha of F = F_design (k/k_design)^alpha"
    )
    thermal: ThermalDesign | None = None

    @model_validator(mode="after")
    def _tag(self) -> HeatExchanger:
        self.tag = self.tag.strip()
        return self

    def head_loss(self, k):  # type: ignore[no-untyped-def]
        """Head loss (m) at mass flow ``k`` (kg/s), sign-aware (Mukherjee, 1998)."""
        k = np.asarray(k, dtype=float)
        ratio = np.abs(k) / self.design_flow
        return np.sign(k) * self.design_head_loss * ratio**self.head_loss_exponent
