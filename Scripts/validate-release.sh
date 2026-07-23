#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_root=$(dirname -- "$script_dir")
version=$(sed -n 's/.*"Version" -> "\([^"]*\)".*/\1/p' "$project_root/PacletInfo.wl")
archive=${1:-"$project_root/dist/LoopS-$version.paclet"}
checksum_file="$archive.sha256"

if command -v WolframKernel >/dev/null 2>&1; then
  wolfram_kernel=$(command -v WolframKernel)
elif [ -x /Applications/Mathematica.app/Contents/MacOS/WolframKernel ]; then
  wolfram_kernel=/Applications/Mathematica.app/Contents/MacOS/WolframKernel
else
  wolfram_kernel=
fi

run_wolfram_code() {
  if [ -n "$wolfram_kernel" ]; then
    "$wolfram_kernel" -noprompt -run "$1"
  else
    wolframscript -code "$1"
  fi
}

run_wolfram_file() {
  if [ -n "$wolfram_kernel" ]; then
    "$wolfram_kernel" -noprompt -script "$1"
  else
    wolframscript -file "$1"
  fi
}

if [ ! -f "$archive" ]; then
  echo "Release archive not found: $archive" >&2
  exit 1
fi

if [ ! -f "$checksum_file" ]; then
  echo "Release checksum not found: $checksum_file" >&2
  exit 1
fi

expected_checksum=$(awk 'NR == 1 {print $1}' "$checksum_file")
if command -v shasum >/dev/null 2>&1; then
  actual_checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
else
  actual_checksum=$(sha256sum "$archive" | awk '{print $1}')
fi

if [ "$actual_checksum" != "$expected_checksum" ]; then
  echo "Release checksum mismatch." >&2
  exit 1
fi

validation_root_raw=$(mktemp -d "${TMPDIR:-/tmp}/LoopS-validation.XXXXXX")
validation_root=$(CDPATH= cd -- "$validation_root_raw" && pwd -P)
validation_work_directory="$validation_root/work"
mkdir "$validation_work_directory"
trap 'rm -rf -- "$validation_root"' EXIT HUP INT TERM

LOOPS_ARCHIVE="$archive" LOOPS_VALIDATION_ROOT="$validation_root" LOOPS_VERSION="$version" run_wolfram_code \
  'archive = Environment["LOOPS_ARCHIVE"]; p = PacletObject[archive]; If[p["Name"] =!= "LoopS" || p["Version"] =!= Environment["LOOPS_VERSION"], Exit[1]]; result = ExtractPacletArchive[archive, Environment["LOOPS_VALIDATION_ROOT"]]; If[result === $Failed, Exit[2], Exit[0]]'
candidate_root="$validation_root/LoopS-$version"

if [ ! -f "$candidate_root/PacletInfo.wl" ]; then
  echo "Extracted PacletInfo.wl not found at the expected path." >&2
  exit 1
fi

generated_directories=$(find "$candidate_root" -type d -name LoopSFile -print)
if [ -n "$generated_directories" ]; then
  echo "Generated LoopSFile directories were included in the archive:" >&2
  echo "$generated_directories" >&2
  exit 1
fi

echo "Validated SHA-256: $actual_checksum"
echo "Verifying Paclet directory loading from the extracted candidate..."
LOOPS_CANDIDATE_ROOT="$candidate_root" LOOPS_VALIDATION_WORK_DIRECTORY="$validation_work_directory" LOOPS_VERSION="$version" run_wolfram_code \
  'root = Environment["LOOPS_CANDIDATE_ROOT"]; SetDirectory[Environment["LOOPS_VALIDATION_WORK_DIRECTORY"]]; PacletDirectoryLoad[root]; Needs["LoopS`"] ; If[ToExpression["LoopS`$LoopSVersion"] === Environment["LOOPS_VERSION"], Exit[0], Exit[1]]'

echo "Running fast tests from the extracted candidate..."
run_wolfram_file "$candidate_root/Tests/run-tests.wl"

echo "Running full examples from the extracted candidate..."
run_wolfram_file "$candidate_root/Examples/Scripts/run-all.wl"

echo "LoopS $version release candidate passed isolated validation."
