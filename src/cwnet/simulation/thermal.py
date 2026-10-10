"""Effectiveness-NTU evaluation of the coolers for the simulated cooling water flows.

Port of the ``heatcheck`` routine used in Tavares et al. (2010): film coefficients are
corrected from the design values with the flow ratios (``^0.8`` tube side, ``^0.6`` shell
side), the overall coefficient is recomputed and the outlet temperatures follow from the
effectiveness of the arrangement.
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from cwnet.model import DesignCase
from cwnet.model.exchangers import FlowArrangement


@dataclass
class ThermalResult:
    tags: list[str]
    cold_flow: np.ndarray
    cold_flow_design: np.ndarray
    cold_outlet: np.ndarray
    cold_outlet_design: np.ndarray
    hot_outlet: np.ndarray
    hot_outlet_design: np.ndarray
    duty: np.ndarray
    overall_coefficient: np.ndarray
    effectiveness: np.ndarray

    @property
    def hot_outlet_deviation(self) -> np.ndarray:
        return self.hot_outlet - self.hot_outlet_design

    @property
    def cold_flow_ratio(self) -> np.ndarray:
        return self.cold_flow / self.cold_flow_design


def _effectiveness(ntu: float, cr: float, arrangement: FlowArrangement) -> float:
    if arrangement == FlowArrangement.PARALLEL:
        return (1.0 - np.exp(-ntu * (1.0 + cr))) / (1.0 + cr)
    if arrangement == FlowArrangement.COUNTERFLOW:
        if abs(1.0 - cr) < 1e-12:
            return ntu / (1.0 + ntu)
        e = np.exp(-ntu * (1.0 - cr))
        return (1.0 - e) / (1.0 - cr * e)
    s = np.sqrt(1.0 + cr**2)
    e = np.exp(-ntu * s)
    return 2.0 / (1.0 + cr + s * (1.0 + e) / (1.0 - e))


def thermal_check(case: DesignCase, cold_flows) -> ThermalResult:  # type: ignore[no-untyped-def]
    """Outlet temperatures of the coolers for the given cooling water flows (kg/s)."""
    cold_flows = np.asarray(cold_flows, dtype=float)
    fluid = case.fluid
    n = len(case.exchangers)
    tags, mc_sp, tco, tco_sp, tho, tho_sp, duty, u_all, eff_all = [], [], [], [], [], [], [], [], []
    for h, he in enumerate(case.exchangers):
        td = he.thermal
        tags.append(he.tag)
        mc = max(float(cold_flows[h]), 1e-12)
        if td is None:
            mc_sp.append(he.design_flow)
            for lst in (tco, tco_sp, tho, tho_sp, duty, u_all, eff_all):
                lst.append(np.nan)
            continue
        mc_design = he.design_flow
        mh = td.hot_flow
        c_h, c_c = mh * td.hot_heat_capacity, mc * fluid.heat_capacity
        c_min, c_max = min(c_c, c_h), max(c_c, c_h)
        cr = c_min / c_max
        ratio_c, ratio_h = mc / mc_design, 1.0
        if td.cold_in_tubes:
            hi = td.h_tube * ratio_c**0.8
            he_ = td.h_shell * ratio_h**0.6
        else:
            hi = td.h_tube * ratio_h**0.8
            he_ = td.h_shell * ratio_c**0.6
        dr = td.tube_outer_diameter / td.tube_inner_diameter
        u = 1.0 / (
            dr / hi
            + td.fouling_tube * dr
            + td.tube_outer_diameter * np.log(dr) / (2.0 * td.tube_conductivity)
            + td.fouling_shell
            + 1.0 / he_
        )
        ntu = u * td.area / c_min
        eff = _effectiveness(ntu, cr, td.arrangement)
        q = eff * c_min * (td.hot_inlet_temperature - fluid.inlet_temperature)
        mc_sp.append(mc_design)
        tco.append(fluid.inlet_temperature + q / c_c)
        tco_sp.append(td.cold_outlet_temperature)
        tho.append(td.hot_inlet_temperature - q / c_h)
        tho_sp.append(td.hot_outlet_temperature)
        duty.append(q)
        u_all.append(u)
        eff_all.append(eff)
    assert len(tags) == n
    return ThermalResult(
        tags=tags,
        cold_flow=cold_flows,
        cold_flow_design=np.array(mc_sp),
        cold_outlet=np.array(tco),
        cold_outlet_design=np.array(tco_sp),
        hot_outlet=np.array(tho),
        hot_outlet_design=np.array(tho_sp),
        duty=np.array(duty),
        overall_coefficient=np.array(u_all),
        effectiveness=np.array(eff_all),
    )
