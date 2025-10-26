#!/bin/bash

# Note: you need to set the environment variable FIRE6PATH to point to the
# absolute path of fire/FIRE6 before running this script.
# Note that FIRE6 runs use the then default simplifier Fermat, while FIRE7
# runs use the new default Flint, though this has a negligible effect on
# the prime mode benchmarked here, as analytic simplification only happens
# during trivial preparation stages of the runs.

rm -r benchmarks.log

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox with the previous version of FIRE 6.5 >> benchmarks.log
    /usr/bin/time -v $FIRE6PATH/bin/FIRE6p --calc fermat -c benchmarks/softQuadrupleBox >> benchmarks.log
    mv temp/softQuadrupleBox.tables temp/softQuadrupleBox_fire6.tables
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/softQuadrupleBox >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox with Aia ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/softQuadrupleBox_Aia  --output_override ../temp/softQuadrupleBox_Aia.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox with Apn ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/softQuadrupleBox_Apn  --output_override ../temp/softQuadrupleBox_Apn.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking softQuadrupleBox with Aipin ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/softQuadrupleBox_Aipin  --output_override ../temp/softQuadrupleBox_Aipin.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon with the previous version of FIRE 6.5 >> benchmarks.log
    /usr/bin/time -v $FIRE6PATH/bin/FIRE6p --calc fermat -c benchmarks/nonplanarDoublePentagon >> benchmarks.log
    mv temp/nonplanarDoublePentagon.tables temp/nonplanarDoublePentagon_fire6.tables
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nonplanarDoublePentagon >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon with Aia ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nonplanarDoublePentagon_Aia --output_override ../temp/nonplanarDoublePentagon_Aia.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon with Apn ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nonplanarDoublePentagon_Apn --output_override ../temp/nonplanarDoublePentagon_Apn.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nonplanarDoublePentagon with Aipin ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nonplanarDoublePentagon_Aipin --output_override ../temp/nonplanarDoublePentagon_Aipin.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w with the previous version of FIRE 6.5 >> benchmarks.log
    /usr/bin/time -v $FIRE6PATH/bin/FIRE6p --calc fermat -c benchmarks/nbox2w >> benchmarks.log
    mv temp/nbox2w.tables temp/nbox2w_fire6.tables
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nbox2w >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w with Aia ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nbox2w_Aia --output_override ../temp/nbox2w_Aia.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w with Apn ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nbox2w_Apn --output_override ../temp/nbox2w_Apn.tables >> benchmarks.log
done

for i in {1..3}
do
    rm -rf temp/db
    echo Benchmarking nbox2w with Aipin ordering >> benchmarks.log
    /usr/bin/time -v bin/FIRE7p --calc fermat -c benchmarks/nbox2w_Aipin --output_override ../temp/nbox2w_Aipin.tables >> benchmarks.log
done

grep -e Benchmarking -e STATISTICS -A 7 benchmarks.log
echo "See details in benchmarks.log"
