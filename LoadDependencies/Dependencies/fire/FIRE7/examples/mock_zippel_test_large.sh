#!/bin/bash
# rm -f tests/outputs/mock*
mpirun -np 5 bin/FIRE7_MPI -P 20 -E -S -Z --reconstruct -R ../examples/mock_reconstruct.wls -c examples/mock --reduction_program_args "--coeff ((s+10)^100*(d^2+9)^43+1)/((s-4)^99*(d^2-1)^41) --copies 1000"
