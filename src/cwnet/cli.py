"""Command line interface: ``cwnet <command> ...``."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from cwnet.io.yaml_io import load_case, save_case


def _cmd_validate(args: argparse.Namespace) -> int:
    from cwnet.topology.incidence import build_topology

    case = load_case(args.case)
    topo = build_topology(case)
    print(
        f"{case.name}: {topo.n_nodes} nodes, {topo.n_edges} edges, "
        f"{len(case.pipes)} pipes, {len(case.exchangers)} exchangers, "
        f"{topo.n_circuits} hydraulic circuits, {len(case.scenarios)} scenario(s) - OK"
    )
    return 0


def _cmd_optimize(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting import tables

    case = load_case(args.case)
    methods = args.traditional or [case.options.traditional_method]
    study = run_design_study(case, traditional_methods=methods)
    costs = tables.cost_comparison_table(study)
    design = tables.design_comparison_table(study, traditional=methods[0])
    print(costs.to_string(index=False))
    print()
    print(design.to_string(index=False))
    if study.best is not None and study.best.design.valves:
        print()
        print(tables.valve_table(study.best, case).to_string(index=False))
    if args.out:
        out = Path(args.out)
        out.mkdir(parents=True, exist_ok=True)
        costs.to_csv(out / "costs.csv", index=False)
        design.to_csv(out / "design.csv", index=False)
        tables.mass_flow_table(study, grouped=False).to_csv(out / "mass_flows.csv", index=False)
        if study.best is not None:
            tables.valve_table(study.best, case).to_csv(out / "valves.csv", index=False)
            for i in range(len(case.scenarios)):
                tables.pipe_results_table(study.best, case, i).to_csv(
                    out / f"pipes_scenario{i + 1}.csv", index=False
                )
        print(f"\nresults written to {out}")
    return 0


def _cmd_simulate(args: argparse.Namespace) -> int:
    from cwnet.design.optimizer import run_design_study
    from cwnet.reporting import tables

    case = load_case(args.case)
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

    v = sub.add_parser("validate", help="check a case file and its topology")
    v.add_argument("case")
    v.set_defaults(func=_cmd_validate)

    o = sub.add_parser("optimize", help="run the traditional and LP designs for every pump")
    o.add_argument("case")
    o.add_argument("--out", help="directory for CSV outputs")
    o.add_argument("--traditional", nargs="*", choices=["edgar_himmelblau", "towler"])
    o.set_defaults(func=_cmd_optimize)

    s = sub.add_parser(
        "simulate", help="simulate the optimal design and print the hydraulic results"
    )
    s.add_argument("case")
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
