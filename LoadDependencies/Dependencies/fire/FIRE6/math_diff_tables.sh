#!/bin/bash
source paths.inc
{ echo "Get[\"FIRE6.m\"]; result = FIRE\`CompareTables[\"$1\", \"$2\"]; Put[result, \"tests/outputs/diff.out\"];"; } | ${MATH} > /dev/null
diff tests/outputs/diff.out tests/etalon/diff.out
