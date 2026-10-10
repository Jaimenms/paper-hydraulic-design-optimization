"""Commercial pipe catalogue and pipe-section (edge) definitions."""

from __future__ import annotations

from enum import StrEnum
from fractions import Fraction

from pydantic import BaseModel, Field, field_validator, model_validator

from cwnet.constants import INCH


def nominal_label(nominal_inches: float) -> str:
    """Return the usual label of a nominal diameter, e.g. ``3.5 -> "3 1/2"``."""
    frac = Fraction(nominal_inches).limit_denominator(8)
    whole, rem = divmod(frac.numerator, frac.denominator)
    if rem == 0:
        return str(whole)
    part = f"{rem}/{frac.denominator}"
    return f"{whole} {part}" if whole else part


def parse_nominal(value: str | float | int) -> float:
    """Parse a nominal diameter given as a number or a label such as ``"1 1/2"``."""
    if isinstance(value, int | float):
        return float(value)
    text = value.strip().replace('"', "").replace("in", "").strip()
    total = Fraction(0)
    for token in text.split():
        total += Fraction(token)
    return float(total)


class PipeSize(BaseModel):
    """One commercial pipe size."""

    nominal: float = Field(..., gt=0, description="Nominal diameter, inches")
    inner_diameter: float = Field(..., gt=0, description="Inner diameter, m")
    outer_diameter: float | None = Field(None, gt=0, description="Outer diameter, m")

    @property
    def label(self) -> str:
        return nominal_label(self.nominal)


# ASME/ANSI B36.10, schedule STD (carbon steel) - Table II of Souza et al. (2014).
_ANSI_STD_MM: list[tuple[float, float, float]] = [
    (0.5, 15.8, 21.3),
    (0.75, 21.0, 26.7),
    (1.0, 26.6, 33.4),
    (1.25, 35.1, 42.2),
    (1.5, 40.9, 48.3),
    (2.0, 52.5, 60.3),
    (2.5, 62.7, 73.0),
    (3.0, 77.9, 88.9),
    (3.5, 90.1, 101.6),
    (4.0, 102.3, 114.3),
    (5.0, 128.2, 141.3),
    (6.0, 154.1, 168.3),
    (8.0, 202.7, 219.1),
    (10.0, 254.5, 273.0),
    (12.0, 303.3, 323.9),
    (14.0, 333.3, 355.6),
    (16.0, 381.0, 406.4),
    (18.0, 428.7, 457.2),
    (20.0, 477.8, 508.0),
    (24.0, 574.6, 609.6),
]


class PipeCatalog(BaseModel):
    """Ordered list of commercial diameters available for the design (split-pipe subsections)."""

    sizes: list[PipeSize]

    @field_validator("sizes")
    @classmethod
    def _sorted_unique(cls, sizes: list[PipeSize]) -> list[PipeSize]:
        if not sizes:
            raise ValueError("pipe catalogue must contain at least one size")
        sizes = sorted(sizes, key=lambda s: s.inner_diameter)
        nominals = [s.nominal for s in sizes]
        if len(set(nominals)) != len(nominals):
            raise ValueError("duplicated nominal diameters in pipe catalogue")
        return sizes

    @classmethod
    def ansi_b36_10_std(cls) -> PipeCatalog:
        """Carbon steel, schedule STD, 1/2 in to 24 in (default catalogue of the papers)."""
        return cls(
            sizes=[
                PipeSize(nominal=dn, inner_diameter=din / 1000.0, outer_diameter=dout / 1000.0)
                for dn, din, dout in _ANSI_STD_MM
            ]
        )

    def __len__(self) -> int:
        return len(self.sizes)

    @property
    def nominal(self) -> list[float]:
        return [s.nominal for s in self.sizes]

    @property
    def inner_diameters(self) -> list[float]:
        return [s.inner_diameter for s in self.sizes]

    @property
    def labels(self) -> list[str]:
        return [s.label for s in self.sizes]

    def index_of(self, value: str | float | int) -> int:
        """Index of a size given its nominal diameter (number or label)."""
        nominal = parse_nominal(value)
        for i, s in enumerate(self.sizes):
            if abs(s.nominal - nominal) < 1e-9:
                return i
        raise KeyError(f"nominal diameter {value!r} not in catalogue")

    def smallest_index_at_least(self, inner_diameter: float) -> int | None:
        """Index of the smallest catalogue size whose inner diameter is >= the given value."""
        for i, s in enumerate(self.sizes):
            if s.inner_diameter >= inner_diameter:
                return i
        return None

    def inner_diameter_of(self, value: str | float | int) -> float:
        return self.sizes[self.index_of(value)].inner_diameter

    @staticmethod
    def nominal_to_metres(nominal_inches: float) -> float:
        return nominal_inches * INCH


class PipeStatus(StrEnum):
    """Status of a pipe section in the design problem.

    * ``new``: the diameter is a free decision variable (grassroots design or new
      sections of a revamp).
    * ``existing``: the section is already installed with ``diameter``; keeping it has
      zero capital cost, replacing it costs a new pipe (revamp problem).
    * ``fixed``: the diameter is imposed and not optimized.
    """

    NEW = "new"
    EXISTING = "existing"
    FIXED = "fixed"


class PipeSection(BaseModel):
    """A pipe section (one edge of the digraph)."""

    edge: int = Field(..., description="Edge id of the pipe section in the network")
    tag: str | None = None
    length: float = Field(..., ge=0, description="Equivalent straight length, m")
    roughness: float = Field(46e-6, ge=0, description="Absolute roughness, m")
    fittings_ld: float = Field(0.0, ge=0, description="Equivalent L/D of fittings")
    fixed_head_loss: float = Field(0.0, ge=0, description="Fixed localized head loss, m")
    status: PipeStatus = PipeStatus.NEW
    diameter: str | float | None = Field(
        None, description="Installed nominal diameter (inches or label) for existing/fixed pipes"
    )

    @model_validator(mode="after")
    def _check_diameter(self) -> PipeSection:
        if self.status != PipeStatus.NEW and self.diameter is None:
            raise ValueError(f"pipe {self.edge}: existing/fixed pipes need a 'diameter'")
        if self.tag is None:
            self.tag = str(self.edge)
        return self

    @property
    def nominal_diameter(self) -> float | None:
        return None if self.diameter is None else parse_nominal(self.diameter)
