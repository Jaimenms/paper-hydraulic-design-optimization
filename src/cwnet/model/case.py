"""The complete definition of a design case."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator

from cwnet.model.economics import Economics
from cwnet.model.exchangers import HeatExchanger
from cwnet.model.fluid import Fluid
from cwnet.model.network import Network
from cwnet.model.pipes import PipeCatalog, PipeSection, PipeStatus
from cwnet.model.pumps import PumpCurve, PumpUnit
from cwnet.model.scenario import Scenario


class DesignOptions(BaseModel):
    """Options controlling the design algorithms."""

    max_velocity: float = Field(3.7, gt=0, description="Maximum flow velocity, m/s")
    allow_valves: bool = Field(
        True,
        description=(
            "Include the valve head losses y_h (one per heat exchanger and scenario) as "
            "non-negative decision variables of the LP. Required for revamp and "
            "multi-scenario problems; for grassroots problems the optimum is the same "
            "unless the velocity limit is active."
        ),
    )
    valve_max_head: float | None = Field(
        None, gt=0, description="Optional upper bound of the valve head losses, m"
    )
    allow_downsizing_existing: bool = Field(
        True, description="Allow existing pipes to be replaced by smaller diameters"
    )
    traditional_method: Literal["edgar_himmelblau", "towler"] = Field(
        "edgar_himmelblau", description="Economic-velocity rule of the traditional design"
    )
    edgar_himmelblau_coefficient: float = Field(
        1.269,
        gt=0,
        description=(
            "Coefficient c such that D[in] = c (pc/pc_ref)^0.164 k^0.459 (k in kg/s), "
            "pre-evaluated for the fluid and cost parameters of the paper"
        ),
    )
    edgar_himmelblau_reference_price: float = Field(0.10, gt=0, description="USD/kWh")
    keep_larger_existing_in_traditional: bool = Field(
        True,
        description="Traditional design keeps an existing pipe when it is larger than "
        "the economic diameter",
    )
    lp_solver: Literal["highs-ds", "highs-ipm", "highs"] = "highs-ds"
    qp_postprocess: bool = Field(
        False,
        description="Apply the quadratic-programming post-processing that reduces the "
        "number of split pipes without increasing the cost (draft of the paper, Sec. 5.1)",
    )
    simulation_tolerance: float = Field(1e-9, gt=0)
    simulation_max_iterations: int = Field(50, gt=0)


class DesignCase(BaseModel):
    """All the data needed to design, optimize and simulate a cooling water network."""

    name: str = "Cooling water network"
    description: str = ""
    author: str = ""
    date: str = ""
    fluid: Fluid = Field(default_factory=Fluid)
    network: Network
    pipes: list[PipeSection]
    pump: PumpUnit
    pump_catalog: list[PumpCurve] = Field(..., min_length=1)
    exchangers: list[HeatExchanger] = Field(..., min_length=1)
    pipe_catalog: PipeCatalog = Field(default_factory=PipeCatalog.ansi_b36_10_std)
    economics: Economics = Field(default_factory=Economics)
    scenarios: list[Scenario] = Field(default_factory=list)
    options: DesignOptions = Field(default_factory=DesignOptions)

    # ------------------------------------------------------------------ validation
    @model_validator(mode="after")
    def _validate(self) -> DesignCase:
        edge_ids = set(self.network.edge_ids)
        pipe_edges = [p.edge for p in self.pipes]
        he_edges = [h.edge for h in self.exchangers]
        all_assigned = pipe_edges + he_edges + [self.pump.edge]
        if len(set(all_assigned)) != len(all_assigned):
            raise ValueError("an edge is assigned to more than one element")
        missing = edge_ids - set(all_assigned)
        if missing:
            raise ValueError(f"edges without element definition: {sorted(missing)}")
        unknown = set(all_assigned) - edge_ids
        if unknown:
            raise ValueError(f"elements refer to undefined edges: {sorted(unknown)}")
        tags = [h.tag for h in self.exchangers]
        if len(set(tags)) != len(tags):
            raise ValueError("duplicated heat exchanger tags")
        curve_tags = [c.tag for c in self.pump_catalog]
        if len(set(curve_tags)) != len(curve_tags):
            raise ValueError("duplicated pump curve tags")
        if self.pump.existing:
            if self.pump.curve is None:
                raise ValueError("an existing pump must name its installed curve")
            if self.pump.curve not in curve_tags:
                raise ValueError(
                    f"installed pump curve {self.pump.curve!r} must be in the pump catalogue"
                )
        for p in self.pipes:
            if p.status != PipeStatus.NEW:
                self.pipe_catalog.index_of(p.diameter)  # raises if unknown
        if not self.scenarios:
            self.scenarios = [
                Scenario(
                    name="design",
                    time_fraction=1.0,
                    flows={h.tag: h.design_flow for h in self.exchangers},
                )
            ]
        total = sum(s.time_fraction for s in self.scenarios)
        if abs(total - 1.0) > 1e-6:
            raise ValueError(f"scenario time fractions must sum to 1 (got {total:g})")
        for s in self.scenarios:
            for key in s.flows:
                self.exchanger(key)  # raises if unknown
        self.pipes.sort(key=lambda p: p.edge)
        self.exchangers.sort(key=lambda h: h.edge)
        return self

    # ------------------------------------------------------------------ helpers
    def exchanger(self, key: str | int) -> HeatExchanger:
        """Find a heat exchanger by tag or by edge id."""
        text = str(key).strip()
        for h in self.exchangers:
            if h.tag == text or str(h.edge) == text:
                return h
        raise KeyError(f"unknown heat exchanger {key!r}")

    def pipe(self, edge: int) -> PipeSection:
        for p in self.pipes:
            if p.edge == edge:
                return p
        raise KeyError(edge)

    def pump_curve(self, tag: str) -> PumpCurve:
        for c in self.pump_catalog:
            if c.tag == tag:
                return c
        raise KeyError(tag)

    def scenario_flows(self, scenario: Scenario) -> list[float]:
        """Flow specification vector ordered as ``self.exchangers``."""
        flows: list[float] = []
        for h in self.exchangers:
            value = None
            for key, v in scenario.flows.items():
                if self.exchanger(key) is h:
                    value = v
            if value is None:
                raise ValueError(f"scenario {scenario.name!r} has no flow for {h.tag}")
            flows.append(float(value))
        return flows

    @property
    def is_revamp(self) -> bool:
        return self.pump.existing or any(p.status != PipeStatus.NEW for p in self.pipes)
