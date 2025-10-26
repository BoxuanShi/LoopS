#!/bin/bash
mpirun -np 3 bin/FIRE7_MPI --calc flint -P 10 -T 100_100 -E -S -Z --reconstruct -R ../examples/mock_reconstruct_graph5.wls -c examples/mockgraph5
