#!/bin/bash

# Do NOT run this script yourself. This script is exlusively used by the
# DockerFile during a multi-stage build process for container images.

cd FIRE7
./configure --enable-zlib --enable-zstd --enable-snappy --enable-tcmalloc --enable-debug
git submodule update --init --recursive extra/fuel
git submodule update --init --recursive extra/zstd
make dep -j$(nproc)
make -j$(nproc)
make mpi -j$(nproc)
cd ..

./package.sh # produce FIRE7.tar.gz
mkdir -p /local
mv FIRE7.tar.gz /local/
cd /local
tar -xzf FIRE7.tar.gz
