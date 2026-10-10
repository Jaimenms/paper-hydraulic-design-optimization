"""Load and save design cases as YAML (or JSON) documents."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import yaml

from cwnet.model import DesignCase


def case_to_dict(case: DesignCase) -> dict[str, Any]:
    """Plain-data representation of a case (JSON compatible, ``from``/``to`` aliases)."""
    return case.model_dump(mode="json", by_alias=True, exclude_none=True)


def load_case(path: str | Path) -> DesignCase:
    """Load a case from a ``.yaml``/``.yml`` or ``.json`` file."""
    path = Path(path)
    text = path.read_text(encoding="utf-8")
    data = json.loads(text) if path.suffix.lower() == ".json" else yaml.safe_load(text)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: the document must be a mapping")
    return DesignCase.model_validate(data)


def save_case(case: DesignCase, path: str | Path) -> None:
    """Write a case to a ``.yaml``/``.yml`` or ``.json`` file."""
    path = Path(path)
    data = case_to_dict(case)
    if path.suffix.lower() == ".json":
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    else:
        path.write_text(
            yaml.safe_dump(data, sort_keys=False, allow_unicode=True, width=100),
            encoding="utf-8",
        )
