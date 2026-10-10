from pathlib import Path

import pytest

from cwnet.cli import main
from cwnet.io.scilab_legacy import load_legacy_case
from cwnet.io.yaml_io import load_case, save_case

ROOT = Path(__file__).resolve().parents[1]
LEGACY = ROOT / "legacy" / "scilab" / "v2.2" / "Dados"


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


def test_cli_info_validate_run(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(ROOT)
    assert main(["info"]) == 0
    out = capsys.readouterr().out
    assert "paper1_grassroots" in out and "10.1080/00986445.2013.800484" in out
    assert main(["validate", "paper1_grassroots"]) == 0
    assert "5 hydraulic circuits" in capsys.readouterr().out
    assert (
        main(
            [
                "run",
                "paper1_grassroots",
                "--out",
                str(tmp_path),
                "--traditional",
                "edgar_himmelblau",
            ]
        )
        == 0
    )
    assert (tmp_path / "paper1_grassroots" / "costs.csv").exists()
    assert (tmp_path / "paper1_grassroots" / "summary.json").exists()
    assert "Proposed / Curve 1" in capsys.readouterr().out


def test_cli_eval_and_figures(tmp_path, capsys, monkeypatch):
    monkeypatch.chdir(ROOT)
    assert main(["eval", "--case", "paper1_grassroots", "--out", str(tmp_path / "eval")]) == 0
    report = (tmp_path / "eval" / "report.md").read_text()
    assert "Table XI" in report and "paper1_grassroots" in report
    assert (tmp_path / "eval" / "paper1_grassroots.csv").exists()
    assert main(["figures", "--case", "paper1_grassroots", "--out", str(tmp_path / "figures")]) == 0
    assert (tmp_path / "figures" / "paper1_grassroots_digraph.png").exists()
    assert (tmp_path / "figures" / "paper1_grassroots_costs.md").exists()
