"""Pump capital (Couper et al., 2005) and operating costs, Eqs. (19)-(22)."""

from __future__ import annotations

import numpy as np

from cwnet.constants import FOOT, GRAVITY, M3S_TO_GPM
from cwnet.model.economics import Economics, PumpCostModel


def pump_capital_cost(mass_flow: float, head: float, density: float, model: PumpCostModel) -> float:
    """Installed cost (USD) of a centrifugal pump at the rated point (mass flow kg/s, head m)."""
    q_gpm = mass_flow / density * M3S_TO_GPM
    h_ft = head / FOOT
    if q_gpm <= 0 or h_ft <= 0:
        return 0.0
    ln_z = np.log(q_gpm * np.sqrt(h_ft))
    base = 1.39 * np.exp(8.833 - 0.6019 * ln_z + 0.0519 * ln_z**2)
    b1, b2, b3 = model.b
    f_t = np.exp(b1 + b2 * ln_z + b3 * ln_z**2)
    return float(model.fi * model.fms * model.fm * f_t * base)


def pump_power(mass_flow: float, head: float, efficiency: float) -> float:
    """Shaft (electrical) power in kW: ``k g H / eta``."""
    return mass_flow * GRAVITY * head / (efficiency * 1e3)


def pump_operating_cost(
    mass_flow: float, head: float, efficiency: float, economics: Economics
) -> float:
    """Annual energy cost (USD/year) at an operating point."""
    return (
        pump_power(mass_flow, head, efficiency) * economics.operating_hours * economics.energy_price
    )
