# moonbit-gerberkit

MoonBit library and CLI for inspecting Gerber and Excellon PCB manufacturing data before fabrication.

## Project positioning

The project turns manufacturing files into a shared board model and applies deterministic review gates before a design reaches a fabricator. It is useful for export validation, DFM review, toolpath preparation, provenance tracking, thermal pre-checks, and reproducible CI reports.

## Core capabilities

- Gerber RS-274X and Excellon parsing with units, modal state, regions, arcs, apertures, tools, slots, and diagnostics.
- Geometry, outline, spatial indexing, connectivity, netlist inference, stackup/impedance estimation, and mesh inspection.
- DFM, fabrication-profile, manufacturing-constraint, thermal, machine-tool, and production-readiness analysis.
- Incremental record streaming, source-span indexing, release audits, and multi-board batch execution.
- Deterministic JSON, SVG, ASCII, SARIF, CSV, HTML, G-code, OBJ, and text output.

## Quick start

~~~sh
moon update
moon check --deny-warn
moon test --deny-warn
moon run --target native cmd/gerberkit -- --help
~~~

## Installation

Add the published library to another MoonBit project:

~~~sh
moon add Mgk789a/moonbit-gerberkit@0.2.2
~~~

The command-line examples below run from this repository.

## CLI

~~~text
moon run --target native cmd/gerberkit -- [file] [options]

--format=json|svg|ascii|text|csv|sarif|html|fabrication
--check
--connectivity
--bench --fixture=tiny|small|medium|large
~~~

Examples:

~~~sh
moon run --target native cmd/gerberkit -- board.gbr --format=json
moon run --target native cmd/gerberkit -- PTH.drl --format=sarif
moon run --target native cmd/gerberkit -- board.gbr --connectivity
moon run --target native cmd/gerberkit -- --bench --fixture=medium
~~~

## Architecture

| Area | Modules | Responsibility |
|---|---|---|
| Input | lexer, parse, advanced_parser, excellon, streaming | Decode records, retain diagnostics, and support chunked input |
| Model | types, primitives, arcs, geometry, geometry_kernel, stackup | Board geometry, outlines, intersections, layers, and impedance data |
| Analysis | dfm, fabrication, constraints, connectivity, netlist, metrics, mesh, thermal | Manufacturing, electrical, geometric, thermal, and mesh checks |
| Delivery | pipeline, reporting, render, toolpath, inspection | Reusable APIs, reports, machine paths, and acceptance gates |
| Release | source_index, release_audit, batch_pipeline, benchmark, fixtures | Provenance, reproducible release evidence, batch review, and benchmarks |

The parser and analysis layers communicate through Board, Layer, and Shape, keeping format details out of downstream manufacturing rules.

## Benchmarks

The following table is a real native run of the checked-in deterministic medium fixture with three iterations per operation:

| Benchmark | Input (bytes) | Ticks | Operations | Shapes |
|---|---:|---:|---:|---:|
| Gerber parse | 1,834 | 5 | 867 | 231 |
| Excellon parse | 530 | 1 | 405 | 192 |
| DFM check | 106 | 13 | 4,134 | 33 |
| Render | 106 | 7 | 51,003 | 50,685 |

Ticks are native harness comparison units, not portable wall-clock guarantees. Re-run with:

~~~sh
moon run --target native cmd/gerberkit -- --bench --fixture=medium
~~~

## Tests

The repository currently has 111 passing MoonBit tests covering parsing, malformed input, geometry boundaries, stackups, toolpaths, netlists, source spans, thermal grids, release audits, batch execution, DFM, reporting, connectivity, and deterministic fixtures.

~~~sh
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon check --deny-warn --target all
moon test --deny-warn --target all
moon info
~~~

## CI

.github/workflows/ci.yml installs the stable MoonBit toolchain on Ubuntu, macOS, and Windows, then runs formatting, generated-interface, all-target check/test, CLI smoke, and benchmark smoke checks. .github/workflows/benchmark.yml provides a manually triggerable and main-branch benchmark job.

## License

Apache License 2.0. See [LICENSE](LICENSE).
