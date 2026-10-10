from pathlib import Path

import pytest

from cwnet.io.yaml_io import load_case

CASES = Path(__file__).resolve().parents[1] / "cases"


@pytest.fixture(scope="session")
def grassroots_case():
    return load_case(CASES / "paper1_grassroots.yaml")


@pytest.fixture(scope="session")
def revamp_case():
    return load_case(CASES / "paper1_revamp.yaml")


@pytest.fixture(scope="session")
def multiscenario_case():
    return load_case(CASES / "paper2_multiscenario.yaml")


@pytest.fixture(scope="session")
def grassroots_study(grassroots_case):
    from cwnet.design.optimizer import run_design_study

    return run_design_study(grassroots_case, traditional_methods=["edgar_himmelblau", "towler"])


@pytest.fixture(scope="session")
def revamp_study(revamp_case):
    from cwnet.design.optimizer import run_design_study

    return run_design_study(revamp_case)


@pytest.fixture(scope="session")
def multiscenario_study(multiscenario_case):
    from cwnet.design.optimizer import run_design_study

    return run_design_study(multiscenario_case)
