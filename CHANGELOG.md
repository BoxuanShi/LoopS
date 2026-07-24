# Changelog

Notable changes to LoopS are documented in this file.

## Unreleased

### Added

- The Kira interface accepts `"KiraFermatExecutable"` and passes an explicit Fermat path to the Kira
  child process through `FERMATPATH`, while preserving Kira's automatic environment lookup by
  default.

### Changed

- FIRE, Kira, BLADE, and AMFlow now use a consistent per-family working-directory layout so that
  generated configurations, scripts, logs, caches, databases, and results from different families
  cannot collide. Existing flat FIRE and BLADE result files remain readable.

### Fixed

- Paclet validation now performs its initial package-load check from a temporary working directory
  instead of generating `LoopSFile` in the source-tree root.

## 1.2.0 - 2026-07-23

### Added

- Headless WolframScript examples for loading LoopS and exercising the ZHR and PionEMFF workflows.
- A fast `TestReport` suite covering package loading, path handling, core symbol availability, and
  selected pure functions.
- Separate input and reference-data directories for reproducible script regressions.
- Paclet metadata, a reproducible release builder, isolated artifact validation, checksums, and a
  third-party notice file.
- A Kira interface that prepares isolated family projects, runs the external reducer, imports
  Mathematica rules, and defaults to a positive-propagator-power master ordering.

### Changed

- Notebook and command-line sessions now resolve their work directories independently.
- Progress monitoring now degrades to ordinary evaluation when no notebook front end is available.
- Headless runtime output is kept out of version control.
- Release archives contain only the Mathematica components of FIRE required by LoopS and exclude
  compiled binaries, Fermat, build dependencies, and generated example output.
- FIRE now follows the official 7.1 source through a pinned submodule; release Paclets continue to
  vendor the tested minimal Mathematica runtime so end users do not need Git submodules.
- Kira's per-family worker count now defaults to `LoopSParallelKernels`, matching FIRE's internal
  parallelism policy; validation continues to request one worker explicitly.
- Headless scripts prefer the native Wolfram kernel when available, avoiding legacy launcher hangs
  on Apple Silicon.

### Fixed

- Removed a developer-specific absolute path from the FIRE dependency error message.
- Prevented `FrontEndObject::notavail` warnings during command-line reductions.
