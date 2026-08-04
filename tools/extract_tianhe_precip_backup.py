#!/usr/bin/env python3
"""Create and validate compact precipitation-only WRF backups on Tianhe."""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

from netCDF4 import Dataset


REQUIRED_VARIABLES = ("Times", "XLAT", "XLONG", "RAINC", "RAINNC")
OPTIONAL_ICE_PHASE_VARIABLES = ("GRAUPELNC", "HAILNC")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, help="completed WRF output file")
    parser.add_argument("--output", type=Path, help="precipitation backup NetCDF path")
    parser.add_argument("--family", help="source family, for metadata")
    parser.add_argument("--run-id", help="YYYYMMDDHH initialization, for metadata")
    parser.add_argument("--verify", type=Path, help="validate an existing backup and exit")
    args = parser.parse_args()

    if args.verify is not None:
        if any(value is not None for value in (args.input, args.output, args.family, args.run_id)):
            parser.error("--verify cannot be combined with extraction arguments")
        return args

    if args.input is None or args.output is None or not args.family or not args.run_id:
        parser.error("--input, --output, --family, and --run-id are required for extraction")
    if not re.fullmatch(r"\d{10}", args.run_id):
        parser.error("--run-id must use YYYYMMDDHH")
    return args


def copy_attributes(source, destination) -> None:
    attributes = {name: source.getncattr(name) for name in source.ncattrs() if name != "_FillValue"}
    if attributes:
        destination.setncatts(attributes)


def create_variable(destination: Dataset, source):
    kwargs: dict[str, object] = {}
    if "_FillValue" in source.ncattrs():
        kwargs["fill_value"] = source.getncattr("_FillValue")
    if source.dtype.kind in "iuf" and source.ndim:
        kwargs.update(zlib=True, complevel=4, shuffle=True)
    target = destination.createVariable(source.name, source.dtype, source.dimensions, **kwargs)
    copy_attributes(source, target)
    return target


def copy_variable_data(source, destination) -> None:
    time_dimension = next((name for name in source.dimensions if name.lower() == "time"), None)
    if time_dimension is None:
        destination[...] = source[...]
        return

    time_axis = source.dimensions.index(time_dimension)
    for time_index in range(source.shape[time_axis]):
        selection = [slice(None)] * source.ndim
        selection[time_axis] = time_index
        key = tuple(selection)
        destination[key] = source[key]


def validate_backup(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"missing or empty precipitation backup: {path}")
    with Dataset(path, "r") as dataset:
        missing = [name for name in REQUIRED_VARIABLES if name not in dataset.variables]
        if missing:
            raise ValueError(f"backup is missing variables: {', '.join(missing)}")
        if "iaplacs_backup_kind" not in dataset.ncattrs() or \
                dataset.getncattr("iaplacs_backup_kind") != "precipitation_only":
            raise ValueError("backup metadata does not identify a precipitation-only file")
        for name in REQUIRED_VARIABLES:
            if any(length == 0 for length in dataset.variables[name].shape):
                raise ValueError(f"backup variable has an empty dimension: {name}")


def extract_backup(input_path: Path, output_path: Path, family: str, run_id: str) -> None:
    if not input_path.is_file() or input_path.stat().st_size == 0:
        raise ValueError(f"missing or empty WRF source: {input_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_name(f".{output_path.name}.{os.getpid()}.part")
    temporary_path.unlink(missing_ok=True)

    try:
        with Dataset(input_path, "r") as source:
            missing = [name for name in REQUIRED_VARIABLES if name not in source.variables]
            if missing:
                raise ValueError(f"WRF source is missing variables: {', '.join(missing)}")

            selected_names = REQUIRED_VARIABLES + tuple(
                name for name in OPTIONAL_ICE_PHASE_VARIABLES if name in source.variables
            )
            selected_variables = [source.variables[name] for name in selected_names]
            required_dimensions = {
                dimension
                for variable in selected_variables
                for dimension in variable.dimensions
            }
            with Dataset(temporary_path, "w", format="NETCDF4") as destination:
                for name, dimension in source.dimensions.items():
                    if name in required_dimensions:
                        destination.createDimension(name, None if dimension.isunlimited() else len(dimension))

                copy_attributes(source, destination)
                destination.setncattr("iaplacs_backup_kind", "precipitation_only")
                destination.setncattr("iaplacs_source_family", family)
                destination.setncattr("iaplacs_source_run_id", run_id)
                destination.setncattr("iaplacs_source_path", str(input_path))
                destination.setncattr("iaplacs_source_bytes", input_path.stat().st_size)
                destination.setncattr(
                    "iaplacs_source_mtime_utc",
                    datetime.fromtimestamp(input_path.stat().st_mtime, timezone.utc).isoformat(),
                )
                destination.setncattr(
                    "iaplacs_precipitation_variables",
                    ",".join(selected_names),
                )
                destination.setncattr("iaplacs_backup_created_utc", datetime.now(timezone.utc).isoformat())

                for variable in selected_variables:
                    copy_variable_data(variable, create_variable(destination, variable))

        validate_backup(temporary_path)
        os.replace(temporary_path, output_path)
        print(f"created precipitation backup: {output_path} ({output_path.stat().st_size} bytes)")
    except Exception:
        temporary_path.unlink(missing_ok=True)
        raise


def main() -> int:
    args = parse_args()
    try:
        if args.verify is not None:
            validate_backup(args.verify)
            print(f"valid precipitation backup: {args.verify}")
        else:
            extract_backup(args.input, args.output, args.family, args.run_id)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
