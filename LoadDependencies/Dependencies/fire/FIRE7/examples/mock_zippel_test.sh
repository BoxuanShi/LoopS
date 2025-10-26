#!/bin/bash
mpirun -np 5 bin/FIRE7_MPI -P 5 -E -S -Z --reconstruct -R ../examples/mock_reconstruct.wls -c examples/mock --reduction_program_args "--coeff (s-d)^2/(s*(d-1))"
