#!/bin/bash
echo "Running in conventional style to check"
bin/FIRE7 -v 3 -c examples/doubleboxN --quiet
echo "Reconstruction in d"
d0=41
s0=53

for p in {11..12}
do
    for di in {1..13}
    do
        bin/FIRE7p --calc flint --quiet --large_variables -v 3_${s0}^1_${d0}^${di}_${p} -c examples/doubleboxN
    done
    tools/reconstruct --method thiele --calc flint --geometric --reconstruction_variable d_${d0} -p ${p} tests/outputs/doublebox_3_${s0}^1_d_${p}.tables 13
done

echo "We have reconstruction in d. Here we should investigate tests/outputs/doublebox_3_${s0}^1_d_1.tables and note the maximum number of non-zero terms in numerator or denominator. Now it is 6. That's how many terms in d we need for Zippel reconstruction. But we also need to run Thiele reconstructions in s"

for p in {11..12}
do
    for si in {1..6}
    do
        bin/FIRE7p --calc flint --quiet --large_variables -v 3_${s0}^${si}_${d0}^1_${p} -c examples/doubleboxN
    done
    tools/reconstruct --method thiele --calc flint --geometric --reconstruction_variable s_${s0} -p ${p} tests/outputs/doublebox_3_s_${d0}^1_${p}.tables 6
done

echo "Now we can hav Z(x)*N(s) runs to be ready for Zippel reconstruction. We will run in for 2 primes. We can use Newton reconstruction since we know the denominators (they are split)"

for di in {1..6}
do
    for si in {1..4}
    do
        for p in {11..12}
        do
            bin/FIRE7p --calc flint --quiet --large_variables -v 3_${s0}^${si}_${d0}^${di}_${p} -c examples/doubleboxN
        done
    done
done

echo "Reconstructing in numerator Newton by s for other values of d. It used information from _${d0}^1_ table for denominator"

for di in {2..6}
do
    for p in {11..12}
    do
        tools/reconstruct --method numeratorNewton --calc flint --geometric --reconstruction_variable s_${s0} -p ${p} tests/outputs/doublebox_3_s_${d0}^${di}_${p}.tables 4
    done
done

echo "Running balanced Zippel reconstructions to obtain tables for other s values"

for si in {2..6}
do
    for p in {11..12}
    do
        tools/reconstruct --method balancedZippel --calc flint --balancing_variables d_${d0} --skeleton_variable s_${s0}_${si} -p ${p} tests/outputs/doublebox_3_s_d_${p}.tables 6
    done
done

echo "Now we can run balanced Newton to get a table reconstructed by d and s"

for p in {11..12}
do
    tools/reconstruct --method balancedNewton --geometric --calc flint --balancing_variables d_${d0} --reconstruction_variable s_${s0} -p ${p} tests/outputs/doublebox_3_s_d_${p}.tables 4
done

echo "Final rational reconstruction"

tools/reconstruct --method rational --calc flint tests/outputs/doublebox_3_s_d_0.tables 11:2

tools/diff -V --calc flint tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_3.tables
