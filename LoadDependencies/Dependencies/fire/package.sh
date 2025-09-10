#!/bin/sh
rm -f FIRE6.tar.gz
tar -cvzf FIRE6.tar.gz FIRE6/bin FIRE6/poly/FIRE6 FIRE6/poly/FLAME6 FIRE6/poly/Ftool6 FIRE6/prime/FIRE6 FIRE6/prime/FLAME6 FIRE6/prime/Ftool6 FIRE6/mpi/FIRE_MPI FIRE6/usr/bin FIRE6/usr/lib/*.so* FIRE6/usr/lib64 FIRE6/usr/local FIRE6/extra/fuel/usr/lib/*.so* FIRE6/extra/fuel/usr/lib64 FIRE6/extra/fuel/libraryBinarySettings FIRE6/extra/fuel/extra/ferl64/ FIRE6/examples FIRE6/tests/outputs/ FIRE6/FIRE6.m FIRE6/mm/*.m
