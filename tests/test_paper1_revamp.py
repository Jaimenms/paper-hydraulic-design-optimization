"""Regression tests against the revamp results of Souza et al. (2014)."""

import pytest

from cwnet.design.evaluate import evaluate_design
from cwnet.design.traditional import traditional_design
from cwnet.hydraulics.headloss import build_hydraulic_tables
from cwnet.topology.massbalance import solve_all_scenarios

# Table XVI (USD/y): total, operating, pump, pipe
TABLE_XVI = {
    "Curve 1": (43746, 18265, 0, 25481),
    "Curve 2": (34622, 21918, 3209, 9495),
    "Curve 3": (32857, 24353, 3312, 5192),
    "Curve 4": (33142, 26789, 3409, 2944),
}


def test_table_xvi_lp_costs(revamp_study):
    for ev in revamp_study.lp:
        c = ev.costs
        assert (c.total, c.operating, c.pump_capital_annualized, c.pipe_capital) == pytest.approx(
            TABLE_XVI[ev.design.pump_curve], abs=6
        )
    assert revamp_study.best.design.pump_curve == "Curve 3"


def _length_of(case, design, edges, nominal):
    return sum(
        case.pipe(e).length * f
        for e in edges
        for n, f in design.pipes[e].subsections
        if case.pipe_catalog.sizes[n].nominal == nominal
    )


def test_table_xiv_optimal_diameters_and_valve(revamp_study):
    """The LP optimum is degenerate: pipes in series carrying the same flow can exchange their
    subsections at equal cost. The published vertex (Table XIV) and the one found here agree on
    the non-degenerate pipes and on the total length of each diameter along the series groups."""
    case = revamp_study.case
    d = revamp_study.best.design
    expected = {
        1: "10",
        3: "12",
        4: "10",
        8: "10",
        9: "3 1/2",
        11: "8",
        12: "6",
        14: "3 1/2",
        16: "6",
        17: "6",
        26: "12",
        27: "4",
        28: "8",
    }
    for edge, label in expected.items():
        assert d.pipes[edge].describe(case)[0] == label, edge
    # pipes 5 and 6 (37.4 kg/s): 8 in on 100 + 0.959*100 m (Table XIV: 5 -> 8, 6 -> 6/8 0.041/0.959)
    assert _length_of(case, d, (5, 6), 8.0) == pytest.approx(195.9, abs=0.2)
    # pipes 7 and 25 (73 kg/s): 10 in on 0.355*39.9 + 60.1 m
    assert _length_of(case, d, (7, 25), 10.0) == pytest.approx(74.26, abs=0.2)
    # pipes 10 and 15 (28.7 kg/s): 8 in on 0.728*25 m
    assert _length_of(case, d, (10, 15), 8.0) == pytest.approx(18.2, abs=0.2)
    # pipes 13, 18 and 24 (6.2 kg/s): 3 in on 5.625 + 25 + 0.388*19.375 m
    assert _length_of(case, d, (13, 18, 24), 3.0) == pytest.approx(38.14, abs=0.2)
    # new pipes 29 and 30 (15.6 kg/s): 5 in on 25 + 0.063*25 m
    assert _length_of(case, d, (29, 30), 5.0) == pytest.approx(26.58, abs=0.2)
    valves = d.valves["revamp"]
    assert valves["E-101"] == pytest.approx(3.763, abs=0.002)
    assert all(valves[t] == pytest.approx(0.0, abs=1e-6) for t in valves if t != "E-101")
    assert revamp_study.best.hydraulically_balanced


def test_traditional_revamp_consistent_with_new_flows(revamp_study):
    """With E-101 at its new flow (7.5 kg/s) the required head is 14.36 m (14.4 m in the paper)
    and the smallest sufficient pump is Curve 3, not Curve 4."""
    ev = revamp_study.traditional["edgar_himmelblau"]
    assert ev.design.required_pump_head == pytest.approx(14.36, abs=0.05)
    assert ev.design.pump_curve == "Curve 3"


def test_traditional_revamp_as_published(revamp_case, revamp_study):
    """Tables XIV-XVI (traditional column) are reproduced when E-101 is sized with its former
    flow of 11.8 kg/s, which is what the stale result file of the original code contained."""
    alt = revamp_case.model_copy(deep=True)
    alt.scenarios[0].flows["E-101"] = 11.8
    topo = revamp_study.topology
    bal = solve_all_scenarios(alt, topo)
    hyd = build_hydraulic_tables(alt, bal)
    design = traditional_design(alt, topo, hyd, bal, "edgar_himmelblau")
    assert design.pump_curve == "Curve 4"
    assert design.pipes[9].describe(revamp_case)[0] == "4"
    ev = evaluate_design(revamp_case, topo, revamp_study.balances, design, revamp_study.cost_matrix)
    c = ev.costs
    assert (c.total, c.operating, c.pump_capital_annualized, c.pipe_capital) == pytest.approx(
        (37378, 24193, 3409, 9776), abs=6
    )
    flows = dict(zip(ev.scenarios[0].thermal.tags, ev.scenarios[0].exchanger_flows, strict=True))
    assert flows["E-101"] == pytest.approx(12.0, abs=0.1)
    assert flows["E-105A/B"] == pytest.approx(8.3, abs=0.1)
    assert flows["E-106"] == pytest.approx(16.8, abs=0.1)
