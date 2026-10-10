import pytest

from cwnet.costs.pipes import pipe_unit_cost
from cwnet.costs.pumps import pump_capital_cost, pump_operating_cost
from cwnet.model.economics import Economics, PipeCostModel, PumpCostModel


def test_annualizing_factor():
    assert Economics(interest_rate=0.12, project_years=20).annualizing_factor == pytest.approx(
        0.1339, abs=1e-4
    )


def test_pipe_unit_cost_12_inch():
    # C1/0.3048 * (12/12)^m = 23.09 USD/m
    assert pipe_unit_cost(12.0, PipeCostModel()) == pytest.approx(23.09, abs=0.01)


def test_pump_capital_cost_paper_value():
    # Curve 1 at 94.8 kg/s (14.87 m): r * C = 3045 USD/y in Table XI with FMS = 1457.4/1123.6
    model = PumpCostModel(fms=1457.4 / 1123.6)
    c = pump_capital_cost(94.8, 14.865, 995.0, model)
    assert 0.1339 * c == pytest.approx(3045, abs=5)


def test_operating_cost():
    eco = Economics(energy_price=0.10, operating_hours=8760)
    # 94.8 kg/s, 14.865 m, eta 0.6 -> 23.04 kW -> 20,183 USD/y (Table XI, curve 1)
    assert pump_operating_cost(94.8, 14.865, 0.6, eco) == pytest.approx(20183, abs=10)
