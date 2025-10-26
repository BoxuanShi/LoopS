#!/bin/bash

# Note: you need to set the environment variable FIRE6PATH to point to the
# absolute path of fire/FIRE6 before running this script.

echo Benchmarking threeLoopWindow with the previous version of FIRE 6.5 >> benchmarks_analytic.log
$FIRE6PATH/bin/FIRE6 --calc flint -c benchmarks/threeLoopWindow >> benchmarks_analytic.log

echo Benchmarking threeLoopWindow >> benchmarks_analytic.log
bin/FIRE7 --calc flint -c benchmarks/threeLoopWindow >> benchmarks_analytic.log

echo Benchmarking threeLoopWindow with Aia ordering >> benchmarks_analytic.log
bin/FIRE7 --calc flint -c benchmarks/threeLoopWindow_Aia >> benchmarks_analytic.log

echo Benchmarking threeLoopWindow with Apn ordering >> benchmarks_analytic.log
bin/FIRE7 --calc flint -c benchmarks/threeLoopWindow_Apn >> benchmarks_analytic.log
