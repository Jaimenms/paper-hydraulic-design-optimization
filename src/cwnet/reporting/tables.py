"""pandas tables reproducing the structure of the tables of the papers.

Every function returns a :class:`pandas.DataFrame` ready to be displayed in a notebook
or exported to CSV/LaTeX. Table numbers refer to Souza et al. (2014) unless stated.
"""

from __future__ import annotations

from collections.abc import Iterable

import numpy as np
import pandas as pd

from cwnet.design.results import DesignEvaluation, DesignStudy, NetworkDesign
from cwnet.model import DesignCase, PipeStatus
from cwnet.model.pipes import nominal_label


def _group_equal(values: dict[int, float], fmt: str = "{:g}") -> pd.DataFrame:
    groups: dict[str, list[int]] = {}
    for key, value in values.items():
        groups.setdefault(fmt.format(value), []).append(key)
    rows = [(", ".join(str(k) for k in keys), value) for value, keys in groups.items()]
    return pd.DataFrame(rows)


# ----------------------------------------------------------------------------- inputs
def pipe_lengths_table(case: DesignCase) -> pd.DataFrame:
    """Table I / Table XII: lengths of the pipe sections, grouped by equal length."""
    df = _group_equal({p.edge: p.length for p in case.pipes}, "{:.2f}")
    df.columns = ["Pipe section", "Length (m)"]
    df["Length (m)"] = df["Length (m)"].astype(float)
    return df.sort_values("Length (m)").reset_index(drop=True)


def pipe_catalog_table(case: DesignCase) -> pd.DataFrame:
    """Table II: commercial diameters."""
    return pd.DataFrame(
        {
            "Nominal diameter (in)": [s.label for s in case.pipe_catalog.sizes],
            "Inner diameter (mm)": [
                round(s.inner_diameter * 1000, 1) for s in case.pipe_catalog.sizes
            ],
            "Outer diameter (mm)": [
                round(s.outer_diameter * 1000, 1) if s.outer_diameter else np.nan
                for s in case.pipe_catalog.sizes
            ],
        }
    )


def pump_catalog_table(case: DesignCase) -> pd.DataFrame:
    """Table III: available pumps (curve coefficients)."""
    n = max(len(c.coefficients) for c in case.pump_catalog)
    rows = []
    for c in case.pump_catalog:
        coefs = list(c.coefficients) + [0.0] * (n - len(c.coefficients))
        row = {"Alternative": c.tag}
        for i in reversed(range(n)):
            unit = {0: "m", 1: "s/m2", 2: "s2/m5", 3: "s3/m8"}.get(i, f"s^{i}/m^{3 * i - 1}")
            row[f"a{i} ({unit})"] = coefs[i]
        row["Efficiency"] = c.efficiency
        row["Rated flow (m3/s)"] = c.rated_flow if c.rated_flow is not None else np.nan
        rows.append(row)
    return pd.DataFrame(rows)


def pump_cost_factors_table(case: DesignCase) -> pd.DataFrame:
    """Table IV: pump capital cost factors."""
    pc = case.economics.pump_cost
    return pd.DataFrame(
        {"Factor": ["FI", "FMS", "FM", "b1", "b2", "b3"], "Value": [pc.fi, pc.fms, pc.fm, *pc.b]}
    )


def problem_parameters_table(case: DesignCase) -> pd.DataFrame:
    """Table V: problem parameters."""
    f, e, o = case.fluid, case.economics, case.options
    eff = case.pump_catalog[0].efficiency
    rows = [
        ("Cooling water density", f.density, "kg/m3"),
        ("Cooling water viscosity", f.viscosity, "Pa.s"),
        ("Cooling water heat capacity", f.heat_capacity, "J/(kg K)"),
        ("Cooling water inlet temperature", f.inlet_temperature, "degC"),
        ("Maximum flow velocity", o.max_velocity, "m/s"),
        ("Pump efficiency (eta)", eff, "-"),
        ("Number of operating hours (Nop)", e.operating_hours, "hours/year"),
        ("Energy cost (pc)", e.energy_price, "USD/kWh"),
        ("Interest rate (i)", e.interest_rate, "-"),
        ("Project horizon (ny)", e.project_years, "years"),
        ("Annualizing factor (r)", round(e.annualizing_factor, 4), "1/year"),
        ("Pipe cost coefficient C1", e.pipe_cost.c1, "-"),
        ("Pipe cost exponent m", e.pipe_cost.m, "-"),
    ]
    return pd.DataFrame(rows, columns=["Parameter", "Value", "Unit"])


def thermal_tasks_table(case: DesignCase) -> pd.DataFrame:
    """Table VI: thermal tasks (hot / cold streams)."""
    rows = []
    for h in case.exchangers:
        t = h.thermal
        if t is None:
            continue
        rows.append(
            {
                "Heat exchanger": h.tag,
                "Flow rate (kg/s) hot / cold": f"{t.hot_flow:g} / {h.design_flow:g}",
                "Inlet temperature (degC) hot / cold": (
                    f"{t.hot_inlet_temperature:g} / {case.fluid.inlet_temperature:g}"
                ),
                "Outlet temperature (degC) hot / cold": (
                    f"{t.hot_outlet_temperature:g} / {t.cold_outlet_temperature:g}"
                ),
                "Heat capacity (J/kg K) hot / cold": (
                    f"{t.hot_heat_capacity:g} / {case.fluid.heat_capacity:g}"
                ),
            }
        )
    return pd.DataFrame(rows)


def exchanger_design_table(case: DesignCase) -> pd.DataFrame:
    """Table VII: heat exchanger design data."""
    rows = []
    for h in case.exchangers:
        t = h.thermal
        rows.append(
            {
                "Heat exchanger": h.tag,
                "Area (m2)": t.area if t else np.nan,
                "Film coefficient (W/m2 K) tube / shell": f"{t.h_tube:g} / {t.h_shell:g}"
                if t
                else "",
                "Total fouling factor (m2 K/W)": (t.fouling_tube + t.fouling_shell)
                if t
                else np.nan,
                "Design cooling water flow (kg/s)": h.design_flow,
                "Design cooling water head loss (m)": h.design_head_loss,
            }
        )
    return pd.DataFrame(rows)


def scenario_table(case: DesignCase) -> pd.DataFrame:
    """Table 3 (2016): heat exchanger flows in each scenario, with design values."""
    data = {"Heat exchanger": [h.tag for h in case.exchangers]}
    for sc in case.scenarios:
        data[f"{sc.name} (kg/s)"] = case.scenario_flows(sc)
    data["Design (kg/s)"] = [h.design_flow for h in case.exchangers]
    data["Design head loss (m)"] = [h.design_head_loss for h in case.exchangers]
    return pd.DataFrame(data)


# ------------------------------------------------------------------------- mass balance
def mass_flow_table(study: DesignStudy, scenario: int = 0, grouped: bool = True) -> pd.DataFrame:
    """Table VIII / XIII: mass flow rate of every edge (grouped by equal values)."""
    mb = study.balances[scenario]
    flows = {e: float(k) for e, k in zip(study.topology.edge_ids, mb.edge_flows, strict=True)}
    if not grouped:
        return pd.DataFrame({"Edge": list(flows), "Mass flow rate (kg/s)": list(flows.values())})
    df = _group_equal(flows, "{:.4f}")
    df.columns = ["Edge", "Mass flow rate (kg/s)"]
    df["Mass flow rate (kg/s)"] = df["Mass flow rate (kg/s)"].astype(float)
    return df.sort_values("Mass flow rate (kg/s)", ascending=False).reset_index(drop=True)


def circuit_table(study: DesignStudy) -> pd.DataFrame:
    """The hydraulic circuit matrix Lambda as a table (circuits x edges)."""
    topo = study.topology
    df = pd.DataFrame(topo.circuits.astype(int), columns=[str(e) for e in topo.edge_ids])
    df.index = [f"Circuit {i + 1} ({study.case.exchangers[i].tag})" for i in range(topo.n_circuits)]
    return df


# -------------------------------------------------------------------------- designs
def _design_columns(case: DesignCase, design: NetworkDesign, prefix: str) -> dict[str, list[str]]:
    diam, frac = [], []
    for p in case.pipes:
        d, f = design.pipes[p.edge].describe(case)
        diam.append(d)
        frac.append(f)
    return {f"{prefix} diameter (in)": diam, f"{prefix} length fraction": frac}


def design_comparison_table(
    study: DesignStudy,
    traditional: str | None = None,
    lp: DesignEvaluation | None = None,
    show_fractions_for_traditional: bool = False,
) -> pd.DataFrame:
    """Table IX / XIV / Table 5 (2016): diameters of the traditional and optimized designs."""
    case = study.case
    data: dict[str, list] = {"Edge": [p.edge for p in case.pipes]}
    if case.is_revamp:
        data["Diameter before revamp (in)"] = [
            nominal_label(p.nominal_diameter) if p.status != PipeStatus.NEW else "-"
            for p in case.pipes
        ]
    if study.traditional:
        key = traditional or next(iter(study.traditional))
        cols = _design_columns(case, study.traditional[key].design, "Traditional")
        data.update(
            cols
            if show_fractions_for_traditional
            else {k: v for k, v in cols.items() if "diameter" in k}
        )
    ev = lp or study.best
    if ev is not None:
        data.update(_design_columns(case, ev.design, "Optimization"))
    return pd.DataFrame(data)


def cost_comparison_table(study: DesignStudy, basis: str | None = None) -> pd.DataFrame:
    """Table XI / XVI: total, operating, pump and pipe costs of every design."""
    rows = []
    for key, ev in study.traditional.items():
        rows.append(_cost_row(f"Traditional ({key})", ev, basis))
    for ev in study.lp:
        rows.append(_cost_row(f"Proposed / {ev.design.pump_curve}", ev, basis))
    return pd.DataFrame(rows)


def _cost_row(label: str, ev: DesignEvaluation, basis: str | None) -> dict[str, object]:
    c = ev.costs
    if not ev.feasible:
        return {
            "Methodology / case": label,
            "Pump": ev.design.pump_curve,
            "Total cost (USD/y)": np.nan,
            "Operational cost (USD/y)": np.nan,
            "Pump cost (USD/y)": np.nan,
            "Pipe cost (USD)": np.nan,
            "Feasible": False,
        }
    total = (
        c.total
        if basis is None
        else (c.total_annualized if basis == "annualized" else c.total_published)
    )
    return {
        "Methodology / case": label,
        "Pump": ev.design.pump_curve,
        "Total cost (USD/y)": round(total),
        "Operational cost (USD/y)": round(c.operating),
        "Pump cost (USD/y)": round(c.pump_capital_annualized),
        "Pipe cost (USD)": round(c.pipe_capital),
        "Feasible": True,
    }


def cost_breakdown_table(evaluations: Iterable[tuple[str, DesignEvaluation]]) -> pd.DataFrame:
    """Detailed cost breakdown with both total conventions."""
    rows = []
    for label, ev in evaluations:
        c = ev.costs
        rows.append(
            {
                "Design": label,
                "Pump": ev.design.pump_curve,
                **{k: round(v, 1) for k, v in c.as_dict().items()},
            }
        )
    return pd.DataFrame(rows)


def network_behaviour_table(ev: DesignEvaluation, scenario: int = 0) -> pd.DataFrame:
    """Table X / XV: specified vs simulated flows and hot-stream outlet temperatures."""
    se = ev.scenarios[scenario]
    th = se.thermal
    rows = []
    for h, tag in enumerate(
        th.tags if th else [str(i) for i in range(len(se.specified_exchanger_flows))]
    ):
        row = {
            "Heat exchanger": tag,
            "Design flow (kg/s)": round(float(se.specified_exchanger_flows[h]), 2),
            "Simulated flow (kg/s)": round(float(se.exchanger_flows[h]), 2),
        }
        if th is not None and not np.isnan(th.hot_outlet[h]):
            row["Design hot outlet (degC)"] = round(float(th.hot_outlet_design[h]), 1)
            row["Simulated hot outlet (degC)"] = round(float(th.hot_outlet[h]), 1)
            row["Simulated cold outlet (degC)"] = round(float(th.cold_outlet[h]), 1)
        rows.append(row)
    df = pd.DataFrame(rows)
    total = {
        "Heat exchanger": "Total",
        "Design flow (kg/s)": round(float(se.specified_exchanger_flows.sum()), 2),
        "Simulated flow (kg/s)": round(float(se.exchanger_flows.sum()), 2),
    }
    return pd.concat([df, pd.DataFrame([total])], ignore_index=True)


def exchanger_flows_by_scenario_table(ev: DesignEvaluation) -> pd.DataFrame:
    """Simulated heat exchanger flows in every scenario (Table 8 of the 2016 paper)."""
    data = {"Heat exchanger": list(ev.scenarios[0].thermal.tags) if ev.scenarios[0].thermal else []}
    if not data["Heat exchanger"]:
        data["Heat exchanger"] = [str(i + 1) for i in range(len(ev.scenarios[0].exchanger_flows))]
    for se in ev.scenarios:
        data[f"{se.scenario} specified (kg/s)"] = np.round(se.specified_exchanger_flows, 2)
        data[f"{se.scenario} simulated (kg/s)"] = np.round(se.exchanger_flows, 2)
    return pd.DataFrame(data)


def valve_table(ev: DesignEvaluation, case: DesignCase) -> pd.DataFrame:
    """Table 6 (2016): valve head losses per heat exchanger and scenario."""
    data = {"Heat exchanger": [h.tag for h in case.exchangers]}
    for sc in case.scenarios:
        data[f"{sc.name} (m)"] = [
            round(ev.design.valve_head(sc.name, h.tag), 3) for h in case.exchangers
        ]
    return pd.DataFrame(data)


def pipe_results_table(ev: DesignEvaluation, case: DesignCase, scenario: int = 0) -> pd.DataFrame:
    """Detailed hydraulic results of every pipe section for one scenario."""
    se = ev.scenarios[scenario]
    sim = se.simulation
    rows = []
    for i, p in enumerate(case.pipes):
        d, f = ev.design.pipes[p.edge].describe(case)
        tail = case.network.edge(p.edge).tail
        head = case.network.edge(p.edge).head
        rows.append(
            {
                "Edge": p.edge,
                "Length (m)": p.length,
                "Diameter (in)": d,
                "Length fraction": f,
                "Mass flow (kg/s)": round(float(sim.pipe_flows[i]), 3),
                "Velocity (m/s)": " / ".join(f"{v:.2f}" for v in sim.pipe_velocities[i]),
                "Head loss (m)": round(float(sim.pipe_head_losses[i]), 3),
                "Upstream pressure (bar g)": round(sim.pressure_at(tail), 3),
                "Downstream pressure (bar g)": round(sim.pressure_at(head), 3),
            }
        )
    return pd.DataFrame(rows)


def pump_operating_table(study: DesignStudy) -> pd.DataFrame:
    """Operating point of the pump (flow, head, power) for every design and scenario."""
    from cwnet.costs.pumps import pump_power

    rows = []
    evs = [(f"Traditional ({k})", e) for k, e in study.traditional.items()] + [
        (f"Proposed / {e.design.pump_curve}", e) for e in study.lp if e.feasible
    ]
    for label, ev in evs:
        eff = study.case.pump_curve(ev.design.pump_curve).efficiency
        for se in ev.scenarios:
            rows.append(
                {
                    "Design": label,
                    "Scenario": se.scenario,
                    "Pump": ev.design.pump_curve,
                    "Flow (kg/s)": round(se.pump_flow, 2),
                    "Head (m)": round(se.pump_head, 3),
                    "Power (kW)": round(pump_power(se.pump_flow, se.pump_head, eff), 2),
                    "Operating cost (USD/y)": round(se.operating_cost),
                    "Converged": se.simulation.converged,
                }
            )
    return pd.DataFrame(rows)
