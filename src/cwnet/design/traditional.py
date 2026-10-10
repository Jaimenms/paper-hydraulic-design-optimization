"""Traditional design based on economic velocities (Section "Traditional Design")."""

from __future__ import annotations

import warnings

import numpy as np

from cwnet.design.results import NetworkDesign
from cwnet.hydraulics.headloss import HydraulicTables
from cwnet.model import DesignCase, PipeStatus
from cwnet.topology.incidence import NetworkTopology
from cwnet.topology.massbalance import MassBalance


def towler_diameter(mass_flow, density: float):  # type: ignore[no-untyped-def]
    """Rule of thumb of Towler & Sinnott (2008), Eq. (37): ``D = (k / rho)^0.5`` in m."""
    return np.sqrt(np.asarray(mass_flow, dtype=float) / density)


def edgar_himmelblau_diameter(  # type: ignore[no-untyped-def]
    mass_flow, energy_price: float, coefficient: float = 1.269, reference_price: float = 0.10
):
    """Economic diameter of Edgar & Himmelblau (1989), Eq. (38), in m.

    ``D[in] = c (pc / pc_ref)^0.164 k^0.459`` where ``c`` was pre-evaluated for the fluid
    properties and pipe cost parameters of the paper (c = 1.269 for pc_ref = 0.10 USD/kWh).
    """
    k = np.asarray(mass_flow, dtype=float)
    return coefficient * (energy_price / reference_price) ** 0.164 * k**0.459 * 0.0254


def economic_diameters(
    case: DesignCase, balances: list[MassBalance], method: str | None = None
) -> np.ndarray:
    """Economic diameter (m) of every pipe: the largest value over the scenarios."""
    method = method or case.options.traditional_method
    d0 = np.zeros(len(case.pipes))
    for mb in balances:
        k = np.abs(mb.pipe_flows)
        if method == "towler":
            d = towler_diameter(k, case.fluid.density)
        elif method == "edgar_himmelblau":
            d = edgar_himmelblau_diameter(
                k,
                case.economics.energy_price,
                case.options.edgar_himmelblau_coefficient,
                case.options.edgar_himmelblau_reference_price,
            )
        else:
            raise ValueError(f"unknown traditional method {method!r}")
        d0 = np.maximum(d0, d)
    return d0


def velocity_limited_diameters(case: DesignCase, balances: list[MassBalance]) -> np.ndarray:
    """Smallest diameter (m) that respects the maximum velocity in all scenarios."""
    d = np.zeros(len(case.pipes))
    for mb in balances:
        k = np.abs(mb.pipe_flows)
        d = np.maximum(
            d, np.sqrt(4.0 * k / (np.pi * case.options.max_velocity * case.fluid.density))
        )
    return d


def traditional_design(
    case: DesignCase,
    topology: NetworkTopology,
    hydraulics: HydraulicTables,
    balances: list[MassBalance],
    method: str | None = None,
) -> NetworkDesign:
    """Size every pipe individually, round up to a commercial diameter and pick the pump.

    The pump is the alternative with the smallest head (at the limiting scenario flow)
    that still exceeds the largest circuit head requirement.
    """
    method = method or case.options.traditional_method
    catalog = case.pipe_catalog
    d0 = economic_diameters(case, balances, method)
    d_v = velocity_limited_diameters(case, balances)
    chosen = np.zeros(len(case.pipes), dtype=int)
    for i, pipe in enumerate(case.pipes):
        target = max(d0[i], d_v[i])
        if pipe.status == PipeStatus.FIXED:
            chosen[i] = catalog.index_of(pipe.diameter)
            continue
        if pipe.status == PipeStatus.EXISTING and case.options.keep_larger_existing_in_traditional:
            installed = catalog.inner_diameter_of(pipe.diameter)
            if installed > target:
                target = installed
        idx = catalog.smallest_index_at_least(target)
        if idx is None:
            warnings.warn(
                f"pipe {pipe.tag}: no catalogue diameter satisfies {target * 1000:.1f} mm; "
                "using the largest one",
                stacklevel=2,
            )
            idx = len(catalog) - 1
        chosen[i] = idx

    x = np.zeros((len(case.pipes), len(catalog)))
    x[np.arange(len(case.pipes)), chosen] = 1.0

    # Head required in every circuit and scenario: sum of losses + exchanger - elevation term
    lam_pi = topology.circuits_pipes
    lam_he = topology.circuits_exchangers
    n_sc = hydraulics.n_scenarios
    required = np.zeros((n_sc, topology.n_circuits))
    for m in range(n_sc):
        pipe_losses = hydraulics.pipe_loss[m][np.arange(len(case.pipes)), chosen]
        required[m] = (
            lam_pi @ (pipe_losses + hydraulics.pipe_fixed_loss)
            + lam_he @ hydraulics.exchanger_loss[m]
            - hydraulics.elevation_term
        )
    m_lim, l_lim = np.unravel_index(int(np.argmax(required)), required.shape)
    head_min = float(required[m_lim, l_lim])

    heads = hydraulics.pump_head[m_lim]
    candidates = [s for s in range(len(case.pump_catalog)) if heads[s] >= head_min]
    feasible = bool(candidates)
    if candidates:
        s_best = min(candidates, key=lambda s: heads[s])
        message = ""
    else:
        s_best = int(np.argmax(heads))
        message = (
            f"no pump alternative provides the required head of {head_min:.2f} m; "
            f"the largest pump ({case.pump_catalog[s_best].tag}) was selected"
        )
        warnings.warn(message, stacklevel=2)
    design = NetworkDesign.from_fraction_matrix(
        case,
        x,
        method=f"traditional:{method}",
        pump_curve=case.pump_catalog[s_best].tag,
        feasible=feasible,
        message=message,
        required_pump_head=head_min,
    )
    design.extra.update(
        {
            "economic_diameters": d0,
            "velocity_diameters": d_v,
            "limiting_scenario": case.scenarios[m_lim].name,
            "limiting_circuit": int(l_lim),
            "required_head_by_circuit": required,
        }
    )
    return design
