#!/bin/bash

echo RUN FLINT VERTEX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l --calc flint
done
echo RUN SYMBOLICA VERTEX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l --calc symbolica
done
echo RUN FERMAT VERTEX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l --calc fermat
done


echo RUN FLINT VERTEX HIGH 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l_high --calc flint
done
echo RUN SYMBOLICA VERTEX HIGH 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l_high --calc symbolica
done
echo RUN FERMAT VERTEX HIGH 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/v2l_high --calc fermat
done


echo RUN FLINT DOUBLE BOX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/doubleboxrp --calc flint
done
echo RUN SYMBOLICA DOUBLE BOX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/doubleboxrp --calc symbolica
done
echo RUN FERMAT DOUBLE BOX 10 times
for i in {1..10}
do
    bin/FIRE6 -c examples/doubleboxrp --calc fermat
done


echo RUN FLINT DOUBLE BOX HIGH
bin/FIRE6 -c examples/doubleboxrp_high --calc flint
echo RUN SYMBOLICA DOUBLE BOX HIGH
bin/FIRE6 -c examples/doubleboxrp_high --calc symbolica
echo RUN FERMAT DOUBLE BOX HIGH
bin/FIRE6 -c examples/doubleboxrp_high --calc fermat


echo RUN FLINT FOURLOOP
time bin/FIRE6 -c examples/softQuadrupleBox --calc flint
echo RUN SYMBOLICA FOURLOOP
time bin/FIRE6 -c examples/softQuadrupleBox --calc symbolica
echo RUN FERMAT FOURLOOP
time bin/FIRE6 -c examples/softQuadrupleBox --calc fermat


echo RUN FLINT BANANA
bin/FIRE6 -c examples/bananaUnequal --calc flint
echo RUN SYMBOLICA BANANA
bin/FIRE6 -c examples/bananaUnequal --calc symbolica
echo RUN FERMAT BANANA
bin/FIRE6 -c examples/bananaUnequal --calc fermat


echo RUN FLINT NONPLANAR DOUBLE BOX
bin/FIRE6 -c examples/nbox2w --calc flint
echo RUN SYMBOLICA NONPLANAR DOUBLE BOX
bin/FIRE6 -c examples/nbox2w --calc symbolica
echo RUN FERMAT NONPLANAR DOUBLE BOX
bin/FIRE6 -c examples/nbox2w --calc fermat
