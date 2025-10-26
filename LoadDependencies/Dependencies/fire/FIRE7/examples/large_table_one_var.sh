#!/bin/sh

# Run this script under FIRE7/

# The following command, commented out, is how you could regenerate examples/large_table_one_var.tables. It can take a few minutes to run
# math -script examples/large_table_one_var_generate_data.wl

rm -f tests/outputs/large_table_one_var*
cp examples/large_table_one_var.tables tests/outputs/
/usr/bin/time -v  mpirun -n 2 bin/FIRE7_MPI --thiele_parts 3 --thiele_limits_search_period 10 -P 10 -T 100 -E --reconstruct -R substitute -c examples/large_table_one_var
