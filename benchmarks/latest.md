# Latest native benchmark

Measured locally on 2026-08-19 with the repository's native target and MoonBit toolchain `moonc v0.10.7+bc794d341 (2026-08-11)`.

Command:

```text
moon run --target native cmd/gerberkit -- --bench --fixture=medium
```

The benchmark harness runs each operation three times. `Ticks` is the native runtime tick count exposed by the harness; it is useful for comparing commits on the same machine, not as a portable wall-clock promise.

| Benchmark | Input | Iterations | Ticks | Operations | Shapes |
|---|---:|---:|---:|---:|---:|
| gerber-parse | 1,834 bytes | 3 | 6 | 867 | 231 |
| excellon-parse | 530 bytes | 3 | 3 | 405 | 192 |
| dfm-check | 106 bytes | 3 | 22 | 4,134 | 33 |
| render | 106 bytes | 3 | 10 | 51,003 | 50,685 |
