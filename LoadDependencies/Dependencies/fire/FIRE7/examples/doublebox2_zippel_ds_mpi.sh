#!/bin/bash
echo "Running in conventional style to check"
bin/FIRE7 -v 3 -c examples/doubleboxN_ds --quiet

echo "Now with MPI"

mpirun -np 5 bin/FIRE7_MPI --delete_tables --calc flint -Z --reconstruct -c examples/doubleboxN_ds -T 13_6 -N 4 -I 41_53 -F t_3 -P 2 -E -S

tools/diff -V --calc flint tests/outputs/doublebox_3_d_s_0.tables tests/outputs/doublebox_3.tables

