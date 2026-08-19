# moonbit-gerberkit

MoonBit library and CLI for inspecting Gerber and Excellon PCB manufacturing data before fabrication.

## Project positioning

moonbit-gerberkit parses manufacturing records into a shared geometry model, validates input, applies DFM rules, analyzes geometric connectivity, and emits JSON, SVG, ASCII, SARIF, CSV, HTML, and text reports.

## Quick start

~~~
moon update
moon check --deny-warn
moon test --deny-warn
moon run --target native cmd/gerberkit -- --help
~~~

~~~
moon run --target native cmd/gerberkit -- board.gbr --format=json
moon run --target native cmd/gerberkit -- PTH.drl --format=sarif
moon run --target native cmd/gerberkit -- --bench --fixture=medium
~~~

## Core capabilities

- Gerber and Excellon parsing with units, modal state, regions, arcs, apertures, tools, and slots.
- Geometry, DFM, validation, outline, spatial, connectivity, metrics, and fabrication-profile analysis.
- Deterministic JSON/SVG/ASCII/SARIF/CSV/HTML/text output for local tools and CI.
- Reproducible benchmark fixtures and cross-platform MoonBit CI.

See README.mbt.md for the complete API, architecture, format coverage, benchmark table, test commands, and license details.
