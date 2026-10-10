"""Regression tests against the published results of Souza et al. (2014), grassroots."""

import pytest

from cwnet.reporting import tables

# Table XI (USD/y): total, operating, pump, pipe
TABLE_XI = {
    "Traditional": (42815, 23184, 3209, 16422),
    "Curve 1": (39811, 20183, 3045, 16583),
    "Curve 2": (41768, 24220, 3209, 14339),
    "Curve 3": (43939, 26911, 3312, 13716),
    "Curve 4": (46292, 29602, 3409, 13281),
}


def _costs(ev):
    c = ev.costs
    return c.total, c.operating, c.pump_capital_annualized, c.pipe_capital


def test_table_xi_costs(grassroots_study):
    tol = 6.0  # USD/y; the original code used a rounded ft->m conversion in the pipe cost
    assert _costs(grassroots_study.traditional["edgar_himmelblau"]) == pytest.approx(
        TABLE_XI["Traditional"], abs=tol
    )
    for ev in grassroots_study.lp:
        assert ev.feasible
        assert _costs(ev) == pytest.approx(TABLE_XI[ev.design.pump_curve], abs=tol)
    assert grassroots_study.best.design.pump_curve == "Curve 1"


def test_traditional_design_table_ix(grassroots_study):
    case = grassroots_study.case
    design = grassroots_study.traditional["edgar_himmelblau"].design
    expected = {
        1: "12",
        3: "12",
        4: "8",
        5: "5",
        6: "5",
        7: "8",
        8: "12",
        9: "4",
        10: "6",
        11: "8",
        12: "5",
        13: "2 1/2",
        14: "4",
        15: "6",
        16: "8",
        17: "5",
        18: "2 1/2",
    }
    for edge, label in expected.items():
        assert design.pipes[edge].describe(case)[0] == label
    assert design.pump_curve == "Curve 2"
    assert design.required_pump_head == pytest.approx(17.7, abs=0.3)


def test_optimal_design_is_hydraulically_balanced(grassroots_study):
    best = grassroots_study.best
    assert best.hydraulically_balanced
    se = best.scenarios[0]
    assert se.simulation.converged
    assert se.pump_flow == pytest.approx(94.8, abs=1e-3)
    assert all(v == pytest.approx(0.0, abs=1e-6) for v in best.design.valves["design"].values())


def test_optimal_design_subsections_table_ix(grassroots_study):
    """The LP optimum is degenerate: the published vertex and ours share the same cost and the
    same total length of each diameter on every path."""
    case = grassroots_study.case
    design = grassroots_study.best.design
    # pipes 5, 6, 12, 17 -> 6 in; pipe 7 -> 8/10 with 0.399/0.601 (Table IX)
    for edge in (5, 6, 12, 17, 10, 15):
        assert design.pipes[edge].describe(case)[0] == "6"
    assert design.pipes[7].describe(case) == ("8/10", "0.399/0.601")
    # total length of 10 in pipe on the main header (edges 1, 3, 8) = 172 m as in Table IX
    len10 = sum(
        case.pipe(e).length * f
        for e in (1, 3, 8)
        for n, f in design.pipes[e].subsections
        if case.pipe_catalog.sizes[n].nominal == 10
    )
    assert len10 == pytest.approx(172.0, abs=0.5)
    assert design.n_split_pipes <= 6


def test_traditional_simulation_table_x(grassroots_study):
    ev = grassroots_study.traditional["edgar_himmelblau"]
    se = ev.scenarios[0]
    assert se.simulation.converged
    flows = dict(zip(se.thermal.tags, se.exchanger_flows, strict=True))
    assert flows["E-101"] == pytest.approx(13.8, abs=0.1)
    assert flows["E-102"] == pytest.approx(32.2, abs=0.15)
    assert flows["E-103"] == pytest.approx(39.8, abs=0.1)
    assert flows["E-104"] == pytest.approx(12.7, abs=0.15)
    assert flows["E-105"] == pytest.approx(4.2, abs=0.15)
    assert se.exchanger_flows.sum() == pytest.approx(102.7, abs=0.2)
    df = tables.network_behaviour_table(ev)
    assert df.iloc[-1]["Simulated flow (kg/s)"] == pytest.approx(102.7, abs=0.2)


def test_towler_traditional_matches_original_report(grassroots_study):
    ev = grassroots_study.traditional["towler"]
    assert ev.design.pump_curve == "Curve 1"
    assert ev.costs.total == pytest.approx(42918, abs=8)


def test_tables_build(grassroots_study):
    study = grassroots_study
    assert len(tables.mass_flow_table(study)) == 8  # Table VIII has 8 groups
    assert len(tables.pipe_lengths_table(study.case)) == 5  # Table I has 5 groups
    assert len(tables.pipe_catalog_table(study.case)) == 20
    assert len(tables.pump_catalog_table(study.case)) == 4
    assert len(tables.design_comparison_table(study)) == 17
    assert len(tables.cost_comparison_table(study)) == 6
    assert len(tables.thermal_tasks_table(study.case)) == 5
