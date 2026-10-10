.PHONY: install test lint format notebooks clean

install:
	uv sync --extra dev --extra notebooks

test:
	uv run pytest

lint:
	uv run ruff check src tests scripts
	uv run ruff format --check src tests scripts

format:
	uv run ruff format src tests scripts
	uv run ruff check --fix src tests scripts

notebooks:
	uv run python scripts/build_notebooks.py

clean:
	rm -rf .pytest_cache .ruff_cache build dist *.egg-info
