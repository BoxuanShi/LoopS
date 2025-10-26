#!/bin/bash
if [[ "$1" != "" ]]; then
    calc="$1"
else
    calc=flint
fi

for p in {1..2}
do
    for d in {100..112}
    do
        tools/reconstruct --method thiele --calc ${calc} --reconstruction_variable s_57 -p ${p} tests/outputs/doublebox_3_s_${d}_${p}.tables 6
    done
done

for p in {1..2}
do
    tools/reconstruct --method thiele --calc ${calc} --reconstruction_variable d_100 -p ${p} tests/outputs/doublebox_3_57_d_${p}.tables 13
done

for p in {1..2}
do
    tools/reconstruct --method balancedNewton --calc ${calc} --balancing_variables s_57 --reconstruction_variable d_100 -p ${p} tests/outputs/doublebox_3_s_d_${p}.tables 13
done

tools/reconstruct --method rational --calc ${calc} tests/outputs/doublebox_3_s_d_0.tables 2

tools/diff -V --calc ${calc} tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_3.tables

echo "Now with Newton-Newton"

for p in {1..2}
do
    tools/reconstruct --method thiele --calc ${calc} --reconstruction_variable s_57 -p ${p} tests/outputs/doublebox_3_s_100_${p}.tables 6
    sfactor=$(tools/lcm --prime $p tests/outputs/doublebox_3_s_100_$p.tables)
    echo "sfactor is $sfactor"
    for d in {101..112}
    do
        tools/reconstruct --method newton --calc ${calc} --reconstruction_variable s_57 -p ${p} --factor $sfactor tests/outputs/doublebox_3_s_${d}_${p}.tables 6
    done
    tools/reconstruct --method thiele --calc ${calc} --reconstruction_variable d_100 -p ${p} tests/outputs/doublebox_3_57_d_${p}.tables 13
    dfactor=$(tools/lcm --prime $p tests/outputs/doublebox_3_57_d_$p.tables)
    echo "dfactor is $dfactor"
    tools/reconstruct --method newton --calc ${calc} --reconstruction_variable d_100 -p ${p} --factor $dfactor tests/outputs/doublebox_3_s_d_${p}.tables 13
done
tools/reconstruct --method rational --calc ${calc} tests/outputs/doublebox_3_s_d_0.tables 2
tools/diff -V --calc ${calc} tests/outputs/doublebox_3_s_d_0.tables tests/outputs/doublebox_3.tables

