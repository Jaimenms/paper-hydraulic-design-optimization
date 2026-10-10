"""Command line interface: ``cwnet <verb> ...`` (verbs shared by the repositories of the series)."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from cwnet import __version__
from cwnet.io.yaml_io import load_case, save_case
from cwnet.references import PAPER_CASES, PAPERS, paper_case, published_values, repository_root


def _case_path(spec: str) -> Path:
    """Resolve a case given as a paper-case name or a file path."""
    path = Path(spec)
    if path.exists():
        return path
    try:
        return repository_root() / paper_case(spec).file
    except KeyError as exc:
        names = [c.name for c in PAPER_CASES]
        raise SystemExit(f"unknown case {spec!r}: give a YAML/JSON file or one of {names}") from exc


def _traditional_methods(spec: str, override: list[str] | None) -> list[str]:
    if override:
        return override
    try:
        return list(paper_case(spec).traditional_methods)
    except KeyError:
        case = load_case(_case_path(spec))
        return [case.options.traditional_method]


def _cmd_info(args: argparse.Namespace) -> int:
    print(f"cwnet {__version__} - hydraulic design optimization of cooling water pipe networks")
    print("\nPapers:")
    for p in PAPERS:
        print(f"  [{p.key}] {p.citation()}")
    print("\nPaper cases (use the name with run/eval/figures):")
    for c in PAPER_CASES:
        print(f"  {c.name:22s} {c.file:34s} {c.description}")
    return 0


def _cmd_validate(args: argparse.Namespace) -> int:
    from cwnet.topology.incidence import build_topology

    case = load_case(_case_path(args.case))
    topo = build_topology(case)
    print(
        f"{case.name}: {topo.n_nodes} nodes, {topo.n_edges} edges, {len(case.pipes)} pipes, "
        f"{len(case.exchangers)} exchangers, {topo.n_circuits} hydraulic circuits, "
        f"{len(case.scenarios)} scenario(s) - OK"
    )
    return 0


def _cmd_run(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting import tables
    from cwnet.reporting.export import write_results

    specs = args.case or [c.name for c in PAPER_CASES]
    out = Path(args.out)
    for spec in specs:
        case = load_case(_case_path(spec))
        methods = _traditional_methods(spec, args.traditional)
        study = run_design_study(case, traditional_methods=methods)
        name = spec if spec in {c.name for c in PAPER_CASES} else Path(spec).stem
        print(f"=== {name}: {case.name}")
        print(tables.cost_comparison_table(study).to_string(index=False))
        if study.best is not None:
            print(f"best: {study.best.label}")
        write_results(study, out / name)
        print(f"results written to {out / name}\n")
    return 0


def _cmd_eval(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting.evaluation import comparisons_to_frame, evaluate_study, write_evaluation

    published = published_values()
    names = args.case or [c.name for c in PAPER_CASES]
    results, references = {}, {}
    for name in names:
        pc = paper_case(name)
        case = load_case(repository_root() / pc.file)
        study = run_design_study(case, traditional_methods=list(pc.traditional_methods))
        df = comparisons_to_frame(evaluate_study(name, case, study, published))
        results[name] = df
        references[name] = published[name].get("reference", "")
        worst = df["Relative (%)"].abs().max()
        print(f"{name}: {len(df)} quantities compared, largest relative deviation {worst:.2f} %")
    report = write_evaluation(Path(args.out), results, references)
    print(f"report written to {report}")
    return 0


def _cmd_figures(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting.export import write_figures

    names = args.case or [c.name for c in PAPER_CASES]
    for name in names:
        pc = paper_case(name)
        case = load_case(repository_root() / pc.file)
        study = run_design_study(case, traditional_methods=list(pc.traditional_methods))
        written = write_figures(study, Path(args.out), name)
        print(f"{name}: {len(written)} files written to {args.out}")
    return 0


def _cmd_simulate(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting import tables

    case = load_case(_case_path(args.case))
    study = run_design_study(case, traditional_methods=[])
    if study.best is None:
        print("no feasible design", file=sys.stderr)
        return 1
    for i, sc in enumerate(case.scenarios):
        print(f"--- scenario {sc.name}")
        print(tables.pipe_results_table(study.best, case, i).to_string(index=False))
        print(tables.network_behaviour_table(study.best, i).to_string(index=False))
    return 0


def _cmd_convert(args: argparse.Namespace) -> int:
    from cwnet.io.scilab_legacy import load_legacy_case

    case = load_legacy_case(args.legacy, pump_fms=args.fms)
    save_case(case, args.out)
    print(f"{args.legacy} -> {args.out}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="cwnet", description="Cooling water pipe network design optimization"
    )
    sub = p.add_subparsers(dest="command", required=True)

    i = sub.add_parser("info", help="papers, paper cases and version")
    i.set_defaults(func=_cmd_info)

    v = sub.add_parser("validate", help="check a case file (schema and topology)")
    v.add_argument("case", help="case file or paper-case name")
    v.set_defaults(func=_cmd_validate)

    r = sub.add_parser("run", help="run the design study of the paper cases (default: all)")
    r.add_argument("case", nargs="*", help="case files or paper-case names")
    r.add_argument("--out", default="results", help="output directory (default: results)")
    r.add_argument("--traditional", nargs="*", choices=["edgar_himmelblau", "towler"])
    r.set_defaults(func=_cmd_run)

    e = sub.add_parser("eval", help="compare the results with the published tables")
    e.add_argument(
        "--case",
        action="append",
        choices=[c.name for c in PAPER_CASES],
        help="restrict to a paper case",
    )
    e.add_argument("--out", default="results/eval")
    e.set_defaults(func=_cmd_eval)

    f = sub.add_parser("figures", help="export the figures and tables of the papers")
    f.add_argument("--case", action="append", choices=[c.name for c in PAPER_CASES])
    f.add_argument("--out", default="figures")
    f.set_defaults(func=_cmd_figures)

    s = sub.add_parser(
        "simulate", help="simulate the optimal design and print the hydraulic results"
    )
    s.add_argument("case", help="case file or paper-case name")
    s.set_defaults(func=_cmd_simulate)

    c = sub.add_parser("convert-legacy", help="convert a legacy Scilab caso*.txt file to YAML")
    c.add_argument("legacy")
    c.add_argument("out")
    c.add_argument("--fms", type=float, default=1457.4 / 1123.6, help="Marshall & Swift factor")
    c.set_defaults(func=_cmd_convert)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
