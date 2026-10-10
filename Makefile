# cwnet - series conventions: see docs/conventions.md
.PHONY: setup lint format test test-all run eval figures notebooks clean

CASES = cases/paper1_grassroots.yaml cases/paper1_revamp.yaml cases/paper2_multiscenario.yaml

setup:            ## create .venv with uv and install the package with all extras
	uv sync --all-extras

lint:             ## static checks
	uv run ruff check src tests scripts
	uv run ruff format --check src tests scripts

format:           ## format the code
	uv run ruff format src tests scripts
	uv run ruff check --fix src tests scripts

test:             ## fast tests
	uv run pytest

test-all:         ## all tests, including the slow ones
	uv run pytest -m ""

run:              ## run every paper case and write results/
	uv run cwnet run --out results

eval:             ## compare the results with the published tables and write results/eval/
	uv run cwnet eval --out results/eval

figures:          ## export the figures and tables of the papers to figures/
	uv run cwnet figures --out figures

notebooks:        ## regenerate and execute the notebooks
	uv run python scripts/build_notebooks.py

clean:
	rm -rf .pytest_cache .ruff_cache build dist *.egg-info
	find . -name "__pycache__" -type d -prune -exec rm -rf {} +
