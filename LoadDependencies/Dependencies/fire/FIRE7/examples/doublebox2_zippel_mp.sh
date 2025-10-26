#!/bin/bash
echo "Running in conventional style to check"
bin/FIRE7 -v 3 -c examples/doubleboxN --quiet
d0=41
s0=53

echo "Corner table"
for p in {1..2}
do
    bin/FIRE7p --calc flint --quiet --large_variables -v 3_${s0}^1_${d0}^1_${p} -c examples/doubleboxN
done

echo "Reconstruction in d"
for p in {1..2}
do
    for di in {2..2}
    do
        bin/FIRE7mp --calc flint --quiet --large_variables -v 3_${s0}^1_${d0}^${di}+_${p} -c examples/doubleboxN
    done
    tools/reconstruct --method thiele --calc flint --geometric --reconstruction_variable d_${d0} -p ${p} -M -F 1 tests/outputs/doublebox_3_${s0}^1_d_${p}.tables 13
done

echo "We have reconstruction in d. Here we should investigate tests/outputs/doublebox_3_${s0}^1_d_1.tables and note the maximum number of non-zero terms in numerator or denominator. Now it is 6. That's how many terms in d we need for Zippel reconstruction. But we also need to run Thiele reconstructions in s"

for p in {1..2}
do
    for si in {2..2}
    do
        bin/FIRE7mp --calc flint --quiet --large_variables -v 3_${s0}^${si}+_${d0}^1_${p} -c examples/doubleboxN
    done
    tools/reconstruct --method thiele --delete_tables --calc flint --geometric --reconstruction_variable s_${s0} -p ${p} -M -F 1 tests/outputs/doublebox_3_s_${d0}^1_${p}.tables 6
done


echo "Now we can have Z(x)*N(s) runs to be ready for Zippel reconstruction. We will run in for 2 primes. We can use Newton reconstruction since we know the denominators (they are split)"

for di in {2..2}
do
    for si in {2..4}
    do
        for p in {1..2}
        do
            bin/FIRE7mp --calc flint --quiet --large_variables -v 3_${s0}^${si}_${d0}^${di}+_${p} -c examples/doubleboxN
        done
    done
done

echo "Numerator Newton with multiple mode. First is one to use Thiele result"

for di in {2..2}
do
    for p in {1..2}
    do
        tools/reconstruct --method numeratorNewton --delete_tables --calc flint --geometric --reconstruction_variable s_${s0} -p ${p} tests/outputs/doublebox_3_s_${d0}^${di}+_${p}.tables 4
    done
done

echo "Running joined balanced Zippel+Newton to reconstruct the table with both variables"

for p in {1..2}
do
    tools/reconstruct --method balancedZippelNewton --delete_tables --calc flint --balancing_variables d_${d0} --reconstruction_variable s_${s0}_6 -p ${p} -M -F 1 tests/outputs/doublebox_3_s_d_${p}.tables 6
done

echo "Final rational reconstruction"

tools/reconstruct --method rational --delete_tables --calc flint tests/outputs/doublebox_3_s_d_0.tables 2

tools/diff -V --calc flint tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_3.tables

