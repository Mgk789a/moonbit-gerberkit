# moonbit-gerberkit

MoonBit library and CLI for inspecting PCB manufacturing data before fabrication. It parses Gerber RS-274X and Excellon drill files into a shared geometry model, applies deterministic DFM rules, and emits reports suitable for local tooling and CI.

## Project positioning

moonbit-gerberkit sits between PCB export and manufacturing review:

1. decode manufacturing records and modal state;
2. normalize units and geometry into a board model;
3. validate input and check fabrication constraints;
4. produce JSON, SVG, ASCII, SARIF, CSV, HTML, and text reports.

The project is designed for reproducible inspection. It does not claim to reconstruct schematic net names or replace a full PCB boolean-geometry kernel.

## Core capabilities

- Gerber tokenizer, source diagnostics, coordinate formats, units, modal operations, regions, circular interpolation, apertures, and aperture macros.
- Excellon tool tables, metric/inch units, leading/trailing/explicit coordinate modes, absolute/incremental moves, and routed slots.
- Geometry primitives for points, rectangles, polylines, circles, arcs, intersections, containment, bounds, and spatial indexing.
- DFM checks for minimum width, clearance, drill size, annular ring, board envelope, duplicate geometry, finite coordinates, outline closure, layer balance, and unknown apertures.
- Manufacturing profiles for prototype, standard, fine-pitch, aluminum, and flexible boards.
- Geometric connectivity analysis for trace endpoints, pads, drills, regions, components, and isolated terminals.
- Deterministic fixtures, metrics, validation, benchmark reporting, SARIF annotations, and machine-readable output.

## Quick start

The repository uses the MoonBit stable toolchain available through the official installer. A native toolchain is preferred for the CLI.

~~~
moon version --all
moon update
moon check --deny-warn
moon test --deny-warn
moon run --target native cmd/gerberkit
~~~

## Installation

Add the published library to another MoonBit project:

~~~
moon add Mgk789a/moonbit-gerberkit@0.2.1
~~~

The command-line examples below run from this repository.

The default CLI input is a built-in sample. To inspect a file:

~~~
moon run --target native cmd/gerberkit -- board.gbr --format=json
moon run --target native cmd/gerberkit -- PTH.drl --format=sarif
~~~

Gerber and Excellon input is detected from its headers and records. Coordinates are normalized to millimeters in the board model.

## CLI

~~~
moon run --target native cmd/gerberkit [file] [options]

--format=json|svg|ascii|text|csv|sarif|html|fabrication
--check
--connectivity
--bench --fixture=tiny|small|medium|large
~~~

Examples:

~~~
moon run --target native cmd/gerberkit -- board.gbr --format=svg
moon run --target native cmd/gerberkit -- board.gbr --format=fabrication
moon run --target native cmd/gerberkit -- board.gbr --connectivity
moon run --target native cmd/gerberkit -- --bench --fixture=medium
~~~

--check prints the legacy issue count for scripts that only need a scalar result. For CI integration, SARIF and CSV preserve individual DFM findings.

## Library API

The src package exposes the main integration points:

~~~moonbit nocheck
///|
let layer = parse_auto(text, name="F.Cu")

///|
let board = board_from_layers([layer])

///|
let validation = validate_board(board)

///|
let dfm = run_dfm(board)

///|
let report = report(board)

///|
let graph = connectivity_from_board(board)

///|
let estimate = assess_fabrication(board)
~~~

Useful output functions include report_to_json, document_to_json, dfm_to_sarif, dfm_to_csv, board_to_html, to_svg, to_ascii, ConnectivityGraph::to_json, and FabricationAssessment::to_json.

## Architecture

| Area | Modules | Responsibility |
|---|---|---|
| Input | lexer, parse, advanced_parser, excellon, aperture, attributes | Decode records and retain diagnostics |
| Representation | types, primitives, arcs, geometry, outline | Shared board and geometry model |
| Analysis | dfm, validation, spatial, connectivity, fabrication, metrics | Manufacturing checks and measurements |
| Delivery | pipeline, reporting, render, benchmark, fixtures | Reports, CLI-oriented processing, and reproducible data |

The parser and analysis layers communicate through Board, Layer, and Shape. This keeps file-format details out of DFM rules and lets integrations use the geometry model directly.

## Format coverage and limits

Supported Gerber records include common parameter blocks, format/unit statements, aperture definitions, D-code selection, D01/D02/D03 operations, regions, and G02/G03 arcs. Supported Excellon records include tool definitions, metric/inch modes, zero suppression, absolute/incremental moves, and G85 slots.

Unknown records are retained in diagnostics where possible. The library provides geometric netlist inference, stackup and impedance estimates, source provenance, thermal pre-checks, toolpath planning, and release audits; it does not claim to replace a full PCB editor, schematic-authoritative netlist, or vendor-specific boolean copper engine.

## Benchmarks

The checked-in latest native benchmark records a real local run using the medium deterministic fixture and three iterations per operation:

| Benchmark | Input | Ticks | Operations | Shapes |
|---|---:|---:|---:|---:|
| Gerber parse | 1,834 bytes | 5 | 867 | 231 |
| Excellon parse | 530 bytes | 1 | 405 | 192 |
| DFM check | 106 bytes | 13 | 4,134 | 33 |
| Render | 106 bytes | 7 | 51,003 | 50,685 |

Runtime ticks are comparison data from the native harness and are not portable wall-clock guarantees. Re-run the exact command on the same machine when comparing changes:

~~~
moon run --target native cmd/gerberkit -- --bench --fixture=medium
~~~

## Tests and quality gates

The repository has 111 passing MoonBit tests covering parsing, malformed input, units, modal state, arcs, regions, apertures, Excellon modes, DFM boundaries, geometry boundaries, stackups, toolpaths, netlists, source spans, thermal grids, release audits, batch execution, reporting, spatial queries, connectivity, fabrication profiles, and deterministic fixtures.

~~~
moon fmt --check
moon check --deny-warn
moon test --deny-warn
moon check --deny-warn --target all
moon test --deny-warn --target all
moon info
~~~

Generated interfaces are checked with git diff --exit-code. The CI matrix runs Ubuntu, macOS, and Windows, plus native CLI and benchmark smoke tests. The benchmark workflow can also be started independently.

## License

Released under the Apache License 2.0 in LICENSE.
