import numpy as np
import pytest

from cwnet.model import DesignCase, Edge, HeatExchanger, Network, PipeSection, PumpCurve, PumpUnit
from cwnet.topology.incidence import TopologyError, build_topology
from cwnet.topology.massbalance import solve_mass_balance


def test_node_classification_and_circuits(grassroots_case):
    topo = build_topology(grassroots_case)
    assert topo.n_nodes == 20 and topo.n_edges == 23
    assert topo.supply_node == 1 and topo.demand_node == 10
    assert int(topo.u_connection.sum()) == 18
    assert topo.circuits.shape == (5, 23)
    # every circuit contains the pump (edge 2) and the common headers 1, 3, 8
    for e in (1, 2, 3, 8):
        assert np.all(topo.circuits[:, topo.edge_index(e)] == 1)
    # circuit of E-104 (edge 22): 1,2,3,4,5,12,22,17,6,7,8
    c = topo.circuits[3]
    assert sorted(topo.edge_ids[i] for i in np.nonzero(c)[0]) == [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        12,
        17,
        22,
    ]


def test_mass_balance_table_viii(grassroots_case):
    topo = build_topology(grassroots_case)
    mb = solve_mass_balance(grassroots_case, topo, grassroots_case.scenarios[0])
    expected = {
        1: 94.8,
        2: 94.8,
        3: 94.8,
        8: 94.8,
        4: 54.3,
        7: 54.3,
        5: 18.7,
        6: 18.7,
        9: 11.8,
        14: 11.8,
        19: 11.8,
        10: 28.7,
        15: 28.7,
        20: 28.7,
        11: 35.6,
        16: 35.6,
        21: 35.6,
        12: 15.6,
        17: 15.6,
        22: 15.6,
        13: 3.1,
        18: 3.1,
        23: 3.1,
    }
    for e, k in expected.items():
        assert mb.flow_of_edge(topo, e) == pytest.approx(k, abs=1e-9)
    assert mb.supply_flow == pytest.approx(94.8) and mb.demand_flow == pytest.approx(94.8)


def test_revamp_mass_balance_table_xiii(revamp_case):
    topo = build_topology(revamp_case)
    mb = solve_mass_balance(revamp_case, topo, revamp_case.scenarios[0])
    assert mb.pump_flow == pytest.approx(109.2)
    assert mb.flow_of_edge(topo, 25) == pytest.approx(73.0)
    assert mb.flow_of_edge(topo, 29) == pytest.approx(15.6)
    assert topo.n_circuits == 6


def _tiny_case(edges, pipes, exchangers):
    return DesignCase(
        network=Network(edges=[Edge(id=i, tail=a, head=b) for i, a, b in edges]),
        pipes=[PipeSection(edge=e, length=10.0) for e in pipes],
        pump=PumpUnit(edge=2),
        pump_catalog=[PumpCurve(tag="P", coefficients=[30.0])],
        exchangers=[
            HeatExchanger(edge=e, tag=f"E{e}", design_flow=1.0, design_head_loss=1.0)
            for e in exchangers
        ],
    )


def test_topology_error_for_two_supply_nodes():
    # two sources feeding the same pump node
    case = _tiny_case([(1, 1, 3), (5, 2, 3), (2, 3, 4), (3, 4, 5), (4, 5, 6)], [1, 5, 3], [4])
    with pytest.raises(TopologyError):
        build_topology(case)


def test_implicit_connection_nodes_are_created():
    case = _tiny_case([(1, 1, 2), (2, 2, 3), (3, 3, 4), (4, 4, 5)], [1, 3], [4])
    assert case.network.node_ids == [1, 2, 3, 4, 5]
    topo = build_topology(case)
    assert topo.n_circuits == 1
