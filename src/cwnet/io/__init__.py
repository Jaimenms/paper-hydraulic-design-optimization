"""Input/output: YAML/JSON case files and the legacy Scilab text format."""

from cwnet.io.scilab_legacy import load_legacy_case
from cwnet.io.yaml_io import case_to_dict, load_case, save_case

__all__ = ["case_to_dict", "load_case", "load_legacy_case", "save_case"]
