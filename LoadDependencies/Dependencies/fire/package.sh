#!/bin/bash
UNAME_S=$(uname -s)
rm -f FIRE7.tar.gz
echo "$UNAME_S"
if [[ "$UNAME_S" == 'Darwin' ]]; then
tar -cvzf FIRE7.tar.gz FIRE7/bin FIRE7/poly/{FIRE7,FLAME7,Ftool7} FIRE7/prime/{FIRE7,FLAME7,Ftool7} FIRE7/multiprime/{FIRE7,FLAME7,Ftool7} FIRE7/tools/{diff,reconstruct,substitute,tables2rules,lcm,FIRE7_MPI,add,combine,reconstruct_mpi} FIRE7/usr/bin FIRE7/usr/lib/*.dylib* FIRE7/usr/lib64 FIRE7/usr/local FIRE7/extra/fuel/usr/lib/*.dylib* FIRE7/extra/fuel/usr/lib64 FIRE7/extra/fuel/libraryBinarySettings FIRE7/extra/fuel/extra/ferm64/ FIRE7/examples FIRE7/tests/outputs/ FIRE7/FIRE7.m FIRE7/mm
else
tar -cvzf FIRE7.tar.gz FIRE7/bin FIRE7/poly/{FIRE7,FLAME7,Ftool7} FIRE7/prime/{FIRE7,FLAME7,Ftool7} FIRE7/multiprime/{FIRE7,FLAME7,Ftool7} FIRE7/tools/{diff,reconstruct,substitute,tables2rules,lcm,FIRE7_MPI,add,combine,reconstruct_mpi} FIRE7/usr/bin FIRE7/usr/lib/*.so* FIRE7/usr/lib64 FIRE7/usr/local FIRE7/extra/fuel/usr/lib/*.so* FIRE7/extra/fuel/usr/lib64 FIRE7/extra/fuel/libraryBinarySettings FIRE7/extra/fuel/extra/ferl64/ FIRE7/examples FIRE7/tests/outputs/ FIRE7/FIRE7.m FIRE7/mm
fi
