# Releasing LoopS

This checklist defines the minimum evidence required before publishing a LoopS release.

## 1. Record the version

- Use semantic versions for Git tags, `$LoopSVersion`, Paclet metadata, and artifact names.
- Confirm that `$LoopSVersion` in `LoopS.m` matches `PacletInfo.wl`.
- Move the relevant entries in `CHANGELOG.md` from `Unreleased` to the dated release section.

## 2. Verify the source tree

- Confirm that all intended source, example input, and reference files are tracked.
- Confirm that generated `LoopSFile/` directories, logs, tables, and temporary FORM/FIRE files are
  not part of the release unless they are documented fixtures.
- Search released files for developer-specific absolute paths and credentials.
- Initialize and verify the pinned FIRE and OPITeR submodule revisions intended for the release.
- Review `THIRD_PARTY_NOTICES.md` and the preserved licenses for every bundled dependency.

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

## 4. Validate the release artifact

- Build the Paclet and its checksum and manifest from a clean checkout with initialized submodules:

  ```sh
  wolframscript -file Scripts/build-release.wl
  ```

- Extract and validate the candidate in an isolated temporary directory:

  ```sh
  sh Scripts/validate-release.sh dist/LoopS-1.2.0.paclet
  ```

- The validator must confirm the checksum and run both the fast and complete suites against the
  extracted artifact rather than the development checkout.
- Open `Examples/Notebook/examples.nb` in a supported Mathematica version and verify its main flow.
- Confirm that installation, optional dependencies, supported platforms, and citation instructions
  in `README.md` match the artifact.

## 5. Hand off to the maintainer

- Stop after producing the locally verified archive, checksum, and validation report.
- Do not create or push Git tags, branches, or releases, and do not upload the artifact.
- The maintainer may later publish the immutable archive and checksum, create an annotated Git tag,
  and update the Zenodo record and citation metadata.
- After publication, the maintainer should verify the public download and installation instructions.
