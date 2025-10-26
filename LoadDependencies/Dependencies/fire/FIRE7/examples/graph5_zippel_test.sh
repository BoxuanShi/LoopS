#!/bin/bash
cp examples/graph5.tables tests/outputs/mockgraph5.tables
mpirun -np 3 bin/FIRE7_MPI --calc flint -P 10 -T 100_100 -E -S -Z --reconstruct -R substitute -c examples/mockgraph5
bin/diff -V --calc flint --variables d_y tests/outputs/mockgraph5_d_y_0.tables tests/outputs/mockgraph5.tables
