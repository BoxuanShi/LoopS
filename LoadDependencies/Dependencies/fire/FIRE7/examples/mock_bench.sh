#!/bin/bash

echo Balanced Zippel with Separation
date
rm -f tests/outputs/*.tables
rm -f tests/outputs/*.limits
rm -f tests/outputs/*.cand
mpirun -np 2 bin/FIRE7_MPI --calc flint -P 10 -T 100_100 -E -S -Z --reconstruct -R ../examples/mock_bench_reconstruct.wls -c examples/mock_bench > mock_bench_test1.log
echo FINISHED 1ST TEST
date

echo Balanced Zippel
date
rm -f tests/outputs/*.tables
rm -f tests/outputs/*.limits
rm -f tests/outputs/*.cand
mpirun -np 2 bin/FIRE7_MPI --calc flint -P 10 -T 100_100 -E -Z --reconstruct -R ../examples/mock_bench_reconstruct.wls -c examples/mock_bench > mock_bench_test2.log
echo FINISHED 2ND TEST
date

echo Balanced Newton
date
rm -f tests/outputs/*.tables
rm -f tests/outputs/*.limits
rm -f tests/outputs/*.cand
mpirun -np 2 bin/FIRE7_MPI --calc flint -P 10 -T 100_100 -N 100 -E --reconstruct -R ../examples/mock_bench_reconstruct.wls -c examples/mock_bench > mock_bench_test3.log
echo FINISHED 3RD TEST
date
