# Releasing LoopS

This checklist defines the minimum evidence required before publishing a source release.

## 1. Record the version

- Use semantic versions for `$LoopSVersion` and Git tags.
- Move the relevant entries in `CHANGELOG.md` from `Unreleased` to the dated release section.

## 2. Verify the source tree

- Confirm that all intended source, example input, and reference files are tracked.
- Confirm that generated `LoopSFile/` directories, logs, tables, and temporary FORM/FIRE files are
  not tracked unless they are documented fixtures.
- Search tracked source files for developer-specific absolute paths and credentials.
- Initialize and verify the pinned FIRE and OPITeR submodule revisions.
- Review `THIRD_PARTY_NOTICES.md` and the preserved licenses for every included dependency.

## 3. Run the quality gates

Run the fast suite:

```sh
wolframscript -file Tests/run-tests.wl
```

Run the full integration suite:

```sh
wolframscript -file Examples/Scripts/run-all.wl
```

Both commands must exit with status 0. The complete suite must pass the FIRE reduction, reference
comparisons, master-integral checks, and Ward identity check.

When a supported Kira executable is available, run the optional reducer integration gate:

```sh
LOOPS_KIRA_EXECUTABLE=/path/to/kira wolframscript -file Tests/kira-integration.wl
```

It must report an equivalent FIRE/Kira reduction and the same positive-power master basis.

Open `Examples/Notebook/examples.nb` in a supported Mathematica version and verify its main flow.
Confirm that installation, optional dependencies, supported platforms, and citation instructions
in `README.md` remain accurate.

## 4. Hand off to the maintainer

- Stop after producing a verified source commit.
- Do not create or push Git tags, branches, or releases unless explicitly requested.
- The maintainer may later create an annotated Git tag, publish a source release, and update the
  Zenodo record and citation metadata.
