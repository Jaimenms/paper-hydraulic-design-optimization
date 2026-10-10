"""Economic parameters and cost correlations."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class PipeCostModel(BaseModel):
    """Installed pipe cost per unit length (Narang et al., 2009).

    ``c = C1 / 0.3048 * (D_nom[in] / 12) ** m`` in USD/m.
    """

    c1: float = Field(7.0386, gt=0)
    m: float = Field(1.4393, gt=0)


class PumpCostModel(BaseModel):
    """Installed centrifugal pump cost (Couper et al., 2005), Eqs. (19)-(21) of the paper.

    ``Z = q[gpm] * sqrt(H[ft])``;
    ``C_base = 1.39 exp(8.833 - 0.6019 ln Z + 0.0519 (ln Z)^2)``;
    ``F_T = exp(b1 + b2 ln Z + b3 (ln Z)^2)``;
    ``C = F_I * F_MS * F_M * F_T * C_base``.
    """

    fi: float = Field(2.8, gt=0, description="Installation factor")
    fms: float = Field(1.3, gt=0, description="Marshall & Swift index correction")
    fm: float = Field(1.35, gt=0, description="Material factor (1.35 = cast steel)")
    b: tuple[float, float, float] = Field(
        (5.1029, -1.2217, 0.0771), description="Pump type factor coefficients"
    )


class Economics(BaseModel):
    """Economic data of the design problem."""

    energy_price: float = Field(0.10, ge=0, description="USD/kWh")
    interest_rate: float = Field(0.12, ge=0, description="Interest rate i")
    project_years: int = Field(20, gt=0, description="Project horizon n_y, years")
    operating_hours: float = Field(8760.0, gt=0, description="Operating hours per year")
    pipe_cost: PipeCostModel = Field(default_factory=PipeCostModel)
    pump_cost: PumpCostModel = Field(default_factory=PumpCostModel)
    objective_basis: Literal["published", "annualized"] = Field(
        "published",
        description=(
            "How capital costs enter the total annual cost used to rank the pump "
            "alternatives. 'published' reproduces the original Scilab code and the "
            "published tables: total = operating + r * pump capital + pipe capital. "
            "'annualized' applies the annualizing factor r to both capital terms, as in "
            "Eqs. (15)-(18) of the paper."
        ),
    )

    @property
    def annualizing_factor(self) -> float:
        """``r = i (1+i)^n / ((1+i)^n - 1)`` (Couper, 2003)."""
        i, n = self.interest_rate, self.project_years
        if i == 0:
            return 1.0 / n
        f = (1.0 + i) ** n
        return i * f / (f - 1.0)
