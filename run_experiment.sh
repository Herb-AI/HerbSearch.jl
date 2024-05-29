#!/bin/zsh

for seed in 958129 95812 11248956 6354 999999
do
    julia --project=. src/minecraft/benchmark.jl -e $1 -s $seed -t 3 --max-time 1200
done
