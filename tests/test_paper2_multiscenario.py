"""Regression tests against Costa, Tonassi & Souza (2016)."""

import pytest

from cwnet.reporting import tables


def test_pump_selection_and_infeasible_alternative(multiscenario_study):
    study = multiscenario_study
    pump0 = study.lp_for_pump("Pump 0")
    assert not pump0.feasible
    assert study.best.design.pump_curve == "Pump 1"
    assert study.traditional["towler"].design.pump_curve == "Pump 1"


def test_table_7_capital_costs(multiscenario_study):
    best = multiscenario_study.best
    trad = multiscenario_study.traditional["towler"]
    assert best.costs.pipe_capital == pytest.approx(17516, abs=25)
    assert trad.costs.pipe_capital == pytest.approx(20941, abs=25)
    # the paper reports 3,051 USD as "pump capital cost": it is r * C_PU with FMS = 1.3
    assert best.costs.pump_capital_annualized == pytest.approx(3051, abs=5)


def test_table_9_operating_costs(multiscenario_study):
    best = multiscenario_study.best
    trad = multiscenario_study.traditional["towler"]
    assert best.costs.operating == pytest.approx(8959, abs=20)
    assert trad.costs.operating == pytest.approx(9605, abs=30)


def test_table_8_traditional_flows(multiscenario_study):
    trad = multiscenario_study.traditional["towler"]
    se = trad.scenarios[0]
    flows = dict(
        zip([h.tag for h in multiscenario_study.case.exchangers], se.exchanger_flows, strict=True)
    )
    assert flows["E-101"] == pytest.approx(13.2, abs=0.15)
    assert flows["E-102"] == pytest.approx(30.1, abs=0.15)
    assert flows["E-103"] == pytest.approx(39.6, abs=0.15)
    assert flows["E-104"] == pytest.approx(16.4, abs=0.15)
    assert flows["E-105"] == pytest.approx(4.6, abs=0.15)


def _length_of(case, design, edges, nominal):
    return sum(
        case.pipe(e).length * f
        for e in edges
        for n, f in design.pipes[e].subsections
        if case.pipe_catalog.sizes[n].nominal == nominal
    )


def test_table_5_and_6_design_and_valves(multiscenario_study):
    """Table 5 up to LP degeneracy (pipes in series with equal flows may exchange subsections)."""
    case = multiscenario_study.case
    d = multiscenario_study.best.design
    for e in (5, 6, 10, 12, 15, 17):
        assert d.pipes[e].describe(case)[0] == "6", e
    # main header 1, 3, 8: 10 in on 48.4 % of 10 m, 12 in elsewhere
    assert _length_of(case, d, (1, 3, 8), 10.0) == pytest.approx(4.84, abs=0.6)
    assert _length_of(case, d, (1, 3, 8), 12.0) == pytest.approx(405.16, abs=0.6)
    # pipes 4 and 7: 8 in on 34.2 % of pipe 4 plus the whole pipe 7 (100 m)
    assert _length_of(case, d, (4, 7), 8.0) == pytest.approx(134.2, abs=0.6)
    # pipes 9 and 14: 3 1/2 in on 25 + 2.4 % of 25 m
    assert _length_of(case, d, (9, 14), 3.5) == pytest.approx(25.6, abs=0.5)
    # pipes 11 and 16: 6 in on 24.4 % of 25 m
    assert _length_of(case, d, (11, 16), 6.0) == pytest.approx(6.1, abs=0.5)
    # pipes 13 and 18: 1 1/2 in on 20 % of 25 m
    assert _length_of(case, d, (13, 18), 1.5) == pytest.approx(5.0, abs=0.5)
    valves = tables.valve_table(multiscenario_study.best, case).set_index("Heat exchanger")
    # Table 6: scenario 2 E-101 = 0, scenario 3 E-102 = 21.75 m, scenario 4 E-104 = 0
    assert valves.loc["E-101", "Scenario 2 (m)"] == pytest.approx(0.0, abs=0.02)
    assert valves.loc["E-102", "Scenario 3 (m)"] == pytest.approx(21.75, abs=0.3)
    assert valves.loc["E-104", "Scenario 4 (m)"] == pytest.approx(0.0, abs=0.02)
    assert multiscenario_study.best.hydraulically_balanced


def test_traditional_design_table_5(multiscenario_study):
    case = multiscenario_study.case
    d = multiscenario_study.traditional["towler"].design
    expected = {
        1: "14",
        3: "14",
        4: "10",
        5: "6",
        6: "6",
        7: "10",
        8: "14",
        9: "5",
        10: "8",
        11: "8",
        12: "6",
        13: "2 1/2",
        14: "5",
        15: "8",
        16: "8",
        17: "6",
        18: "2 1/2",
    }
    for edge, label in expected.items():
        assert d.pipes[edge].describe(case)[0] == label, edge
