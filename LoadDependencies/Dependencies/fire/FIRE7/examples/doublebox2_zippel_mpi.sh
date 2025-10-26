#!/bin/bash
echo "Running in conventional style to check"
bin/FIRE7 -v 3 --calc flint -c examples/doubleboxN --quiet

echo "Now with MPI"

mpirun -np 5 bin/FIRE7_MPI --delete_tables --calc flint -Z --reconstruct -c examples/doubleboxN -T 6_13 -N 7 -I 53_41 -F t_3 -P 2 -E -S

tools/diff -V --calc flint tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_3.tables

