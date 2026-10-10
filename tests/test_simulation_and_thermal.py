import numpy as np
import pytest

from cwnet.design.results import NetworkDesign
from cwnet.simulation.network_sim import simulate_design
from cwnet.simulation.thermal import thermal_check


def test_simulation_of_split_pipe_design_reproduces_specified_flows(grassroots_study):
    case = grassroots_study.case
    best = grassroots_study.best.design
    sim = simulate_design(case, best, topology=grassroots_study.topology)
    assert sim.converged
    np.testing.assert_allclose(sim.exchanger_flows, [11.8, 28.7, 35.6, 15.6, 3.1], atol=2e-3)
    # the pressure at both tower nodes is the boundary condition (0 bar g)
    assert sim.pressure_at(1) == pytest.approx(0.0, abs=1e-9)
    assert sim.pressure_at(10) == pytest.approx(0.0, abs=1e-9)
    # supply and demand external flows close the balance
    assert sim.external_flows[sim.node_ids.index(1)] == pytest.approx(94.8, abs=1e-3)
    assert sim.external_flows[sim.node_ids.index(10)] == pytest.approx(-94.8, abs=1e-3)


def test_simulation_with_valves_balances_each_scenario(multiscenario_study):
    case = multiscenario_study.case
    best = multiscenario_study.best.design
    for sc, mb in zip(case.scenarios, multiscenario_study.balances, strict=True):
        sim = simulate_design(case, best, topology=multiscenario_study.topology, scenario=sc.name)
        assert sim.converged
        np.testing.assert_allclose(sim.exchanger_flows, mb.exchanger_flows, rtol=2e-3, atol=1e-3)


def test_energy_balance_along_a_circuit(grassroots_study):
    case = grassroots_study.case
    sim = grassroots_study.best.scenarios[0].simulation
    topo = grassroots_study.topology
    # circuit of E-104: pump head = sum of losses + 5 m elevation
    lam = topo.circuits[3]
    pipes = [i for i, p in enumerate(case.pipes) if lam[topo.edge_index(p.edge)] == 1]
    losses = sum(sim.pipe_head_losses[i] for i in pipes) + sim.exchanger_head_losses[3]
    assert sim.pump_head == pytest.approx(losses + 5.0, abs=1e-6)


def test_thermal_check_design_point(grassroots_case):
    res = thermal_check(grassroots_case, [h.design_flow for h in grassroots_case.exchangers])
    assert res.tags == ["E-101", "E-102", "E-103", "E-104", "E-105"]
    # at the design flows the simplified model returns outlet temperatures close to the targets
    np.testing.assert_allclose(res.hot_outlet, res.hot_outlet_design, atol=2.0)
    assert np.all(res.effectiveness > 0) and np.all(res.effectiveness < 1)


def test_fraction_matrix_round_trip(grassroots_study):
    case = grassroots_study.case
    best = grassroots_study.best.design
    x = best.fraction_matrix(case)
    again = NetworkDesign.from_fraction_matrix(case, x, "lp", best.pump_curve)
    for p in case.pipes:
        assert again.pipes[p.edge].subsections == pytest.approx(best.pipes[p.edge].subsections)
