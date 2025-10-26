#!/bin/bash

# Note: you need to set the environment variable FIRE6PATH to point to the
# absolute path of fire/FIRE6 before running this script.
# Note that FIRE6 runs use the then default simplifier Fermat, while FIRE7
# runs use the new default Flint, though this has a negligible effect on
# the prime mode benchmarked here, as analytic simplification only happens
# during trivial preparation stages of the runs.

rm -r benchmarks_mp.log

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox with Aia ordering >> benchmarks_mp.log
    /usr/bin/time -v bin/FIRE7mp --calc fermat -c benchmarks/softQuadrupleBox_Aia_mp  --output_override ../temp/softQuadrupleBox_Aia_mp.tables >> benchmarks_mp.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon with Aia ordering >> benchmarks_mp.log
    /usr/bin/time -v bin/FIRE7mp --calc fermat -c benchmarks/nonplanarDoublePentagon_Aia_mp --output_override ../temp/nonplanarDoublePentagon_Aia_mp.tables >> benchmarks_mp.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w with Apn ordering >> benchmarks_mp.log
    /usr/bin/time -v bin/FIRE7mp --calc fermat -c benchmarks/nbox2w_Apn_mp --output_override ../temp/nbox2w_Apn_mp.tables >> benchmarks_mp.log
done
