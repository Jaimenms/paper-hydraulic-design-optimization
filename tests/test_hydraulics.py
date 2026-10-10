import numpy as np
import pytest

from cwnet.hydraulics.friction import churchill_friction_factor
from cwnet.hydraulics.headloss import pipe_head_loss, pipe_velocity


def test_churchill_laminar_limit():
    # In the laminar regime Churchill tends to 64/Re
    assert churchill_friction_factor(1000.0, 0.0) == pytest.approx(0.064, rel=0.02)


def test_churchill_turbulent_smooth_vs_colebrook():
    # Smooth pipe, Re = 1e5: Colebrook gives f ~ 0.0180
    assert churchill_friction_factor(1e5, 1e-9) == pytest.approx(0.018, rel=0.03)


def test_churchill_rough_fully_turbulent():
    # Fully rough: f -> (2 log10(3.7 D/e))^-2 = 0.0379 for e/D = 0.01
    assert churchill_friction_factor(1e8, 0.01) == pytest.approx(0.0379, rel=0.03)


def test_velocity_and_head_loss_scaling():
    v = pipe_velocity(94.8, 0.3033, 995.0)
    assert v == pytest.approx(1.319, rel=1e-3)
    h1 = pipe_head_loss(94.8, 0.3033, 100.0, density=995.0, viscosity=0.72e-3, roughness=46e-6)
    h2 = pipe_head_loss(94.8, 0.3033, 200.0, density=995.0, viscosity=0.72e-3, roughness=46e-6)
    assert h2 == pytest.approx(2 * h1)
    assert 0.3 < h1 < 0.6  # ~0.43 m per 100 m of 12 in pipe at 1.32 m/s
    signed = pipe_head_loss(
        -94.8, 0.3033, 100.0, density=995.0, viscosity=0.72e-3, roughness=46e-6, signed=True
    )
    assert signed == pytest.approx(-h1)
    assert np.isfinite(
        pipe_head_loss(0.0, 0.3033, 100.0, density=995.0, viscosity=0.72e-3, roughness=46e-6)
    )
