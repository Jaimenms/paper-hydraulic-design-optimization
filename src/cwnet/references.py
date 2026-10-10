"""Bibliographic references of the papers reproduced by this package and the paper cases."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Paper:
    key: str
    authors: str
    title: str
    journal: str
    volume: str
    pages: str
    year: int
    doi: str

    def citation(self) -> str:
        return (
            f"{self.authors} ({self.year}). {self.title}. {self.journal} {self.volume}, "
            f"{self.pages}. doi:{self.doi}"
        )


PAPERS: tuple[Paper, ...] = (
    Paper(
        key="paper1",
        authors="Souza, J. N. M., Ventin, F. F., Tavares, V. B. G., Costa, A. L. H.",
        title="A matrix approach for optimization of pipe networks in cooling water systems",
        journal="Chemical Engineering Communications",
        volume="201(8)",
        pages="1054-1076",
        year=2014,
        doi="10.1080/00986445.2013.800484",
    ),
    Paper(
        key="paper2",
        authors="Costa, A. L. H., Tonassi, E. L. R., Souza, J. N. M.",
        title=(
            "Hydraulic design optimization of multi-scenario of cooling water distribution system"
        ),
        journal="Chemical Engineering Transactions",
        volume="52",
        pages="1189-1194",
        year=2016,
        doi="10.3303/CET1652199",
    ),
)


@dataclass(frozen=True)
class PaperCase:
    """A case study of the papers: case file, paper and traditional methods to evaluate."""

    name: str
    file: str
    paper: str
    description: str
    traditional_methods: tuple[str, ...] = field(default_factory=tuple)


PAPER_CASES: tuple[PaperCase, ...] = (
    PaperCase(
        name="paper1_grassroots",
        file="cases/paper1_grassroots.yaml",
        paper="paper1",
        description="Grassroots design (Tables I-XI, Figures 1-4)",
        traditional_methods=("edgar_himmelblau", "towler"),
    ),
    PaperCase(
        name="paper1_revamp",
        file="cases/paper1_revamp.yaml",
        paper="paper1",
        description="Revamp with existing pump and pipes, valves (Tables XII-XVI, Figure 5)",
        traditional_methods=("edgar_himmelblau",),
    ),
    PaperCase(
        name="paper2_multiscenario",
        file="cases/paper2_multiscenario.yaml",
        paper="paper2",
        description="Four operating scenarios with control valves (Tables 1-10, Figure 1)",
        traditional_methods=("towler",),
    ),
)


def paper_case(name: str) -> PaperCase:
    for c in PAPER_CASES:
        if c.name == name:
            return c
    raise KeyError(f"unknown paper case {name!r}; choose from {[c.name for c in PAPER_CASES]}")


def repository_root(start: Path | None = None) -> Path:
    """Root of the repository (directory holding ``cases/``), searched upwards from ``start``."""
    here = (start or Path.cwd()).resolve()
    for p in [here, *here.parents]:
        if (p / "cases").is_dir() and (p / "pyproject.toml").exists():
            return p
    return here


def published_values(root: Path | None = None) -> dict:
    """Published values of the papers (``data/reference/published_values.json``)."""
    import json

    path = repository_root(root) / "data" / "reference" / "published_values.json"
    return json.loads(path.read_text(encoding="utf-8"))
