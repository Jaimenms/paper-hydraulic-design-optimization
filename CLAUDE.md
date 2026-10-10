# cwnet — project guide

Python reimplementation of the cooling-water pipe-network optimization of Souza et al.
(2014, Chem. Eng. Comm.) and Costa, Tonassi & Souza (2016, CET). Original Scilab code and
papers live in `docs/raw/` (read-only reference material).

## Commands
- `uv sync --extra dev --extra notebooks` — create the environment (Python 3.12, see `.python-version`).
- `uv run pytest` — unit + regression tests against the published tables (`tests/`).
- `uv run ruff check src tests scripts && uv run ruff format --check src tests scripts` — lint.
- `uv run python scripts/build_notebooks.py` — regenerate and execute `notebooks/*.ipynb`.
- `uv run cwnet optimize cases/paper1_grassroots.yaml` — CLI.

## Layout
- `src/cwnet/model` pydantic data model (`DesignCase` is the root; YAML in `cases/`).
- `src/cwnet/topology` incidence / selection / circuit matrices, mass balance (Eqs. 1-10).
- `src/cwnet/hydraulics` Churchill friction factor, head-loss tables per scenario.
- `src/cwnet/costs` Narang pipe cost, Couper pump cost, operating cost.
- `src/cwnet/design` traditional sizing, LP per pump (`scipy.optimize.linprog`, HiGHS),
  optional QP post-processing, evaluation (simulation + costs), orchestration, sensitivity.
- `src/cwnet/simulation` rigorous Newton simulation of the network; ε-NTU thermal check.
- `src/cwnet/reporting` pandas tables and matplotlib figures mirroring the papers.
- `docs/formulation.md` equations ↔ code; `docs/reproduction_notes.md` known discrepancies.

## Conventions
- SI units internally (m, kg/s, Pa.s, m of head); nominal diameters in inches; pressures bar g.
- `economics.objective_basis = "published"` reproduces the published totals (pipe capital not
  annualized); `"annualized"` applies `r` to both capital terms.
- LP optima are degenerate: compare designs by cost and by total length per diameter along
  series groups, never by the exact split of one pipe.
- Keep tests green and ruff clean; notebooks are generated, do not edit the `.ipynb` by hand.
