from pathlib import Path

import pytest

from cwnet.cli import main
from cwnet.io.scilab_legacy import load_legacy_case
from cwnet.io.yaml_io import load_case, save_case

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "docs" / "raw" / "scilab" / "v2.2" / "Dados"


def test_yaml_round_trip(tmp_path, grassroots_case):
    out = tmp_path / "case.yaml"
    save_case(grassroots_case, out)
    again = load_case(out)
    assert again.model_dump() == grassroots_case.model_dump()
    out_json = tmp_path / "case.json"
    save_case(grassroots_case, out_json)
    assert load_case(out_json).model_dump() == grassroots_case.model_dump()


@pytest.mark.skipif(not (LEGACY / "caso1.txt").exists(), reason="legacy data not available")
def test_legacy_loader_matches_yaml_case(grassroots_case):
    legacy = load_legacy_case(LEGACY / "caso1.txt", pump_fms=1457.4 / 1123.6)
    assert [p.edge for p in legacy.pipes] == [p.edge for p in grassroots_case.pipes]
    assert [h.tag for h in legacy.exchangers] == [h.tag for h in grassroots_case.exchangers]
    assert legacy.scenarios[0].flows == grassroots_case.scenarios[0].flows
    assert legacy.fluid.viscosity == pytest.approx(0.72e-3)
    assert legacy.pipe_catalog.labels == grassroots_case.pipe_catalog.labels


@pytest.mark.skipif(not (LEGACY / "caso2.txt").exists(), reason="legacy data not available")
def test_legacy_revamp_status():
    legacy = load_legacy_case(LEGACY / "caso2.txt")
    assert legacy.pump.existing and legacy.pump.curve == "Curve 1"
    assert legacy.pipe(29).status.value == "new"
    assert legacy.pipe(1).status.value == "existing" and legacy.pipe(1).diameter == "10"


def test_cli_validate_and_optimize(tmp_path, capsys):
    case = ROOT / "cases" / "paper1_grassroots.yaml"
    assert main(["validate", str(case)]) == 0
    assert "5 hydraulic circuits" in capsys.readouterr().out
    assert main(["optimize", str(case), "--out", str(tmp_path)]) == 0
    assert (tmp_path / "costs.csv").exists()
    assert "Proposed / Curve 1" in capsys.readouterr().out
