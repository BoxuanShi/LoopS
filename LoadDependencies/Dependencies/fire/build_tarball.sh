#!/bin/bash
cd FIRE7
./configure --enable-zstd --enable-mimalloc
make dep
make
make mpi
cd ..

./package.sh
