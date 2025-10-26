#!/bin/bash
for exec in poly/FIRE7 poly/FLAME6 poly/Ftool6 prime/FIRE7 prime/FLAME6 prime/Ftool6
do
    install_name_tool -change /workspace/fire/FIRE7/extra/kyotocabinet-1.2.77/../../usr/lib/libkyotocabinet.16.dylib @executable_path/../usr/lib/libkyotocabinet.16.dylib $exec
    install_name_tool -change @rpath/libgmp.10.dylib @executable_path/../extra/fuel/usr/lib/libgmp.10.dylib $exec
    install_name_tool -change @rpath/libzstd.1.dylib @executable_path/../usr/lib/libzstd.1.dylib $exec
    install_name_tool -change @rpath/libomp.dylib @executable_path/../usr/lib/libomp.dylib $exec
done

for exec in tools/diff tools/reconstruct
do
    install_name_tool -change @rpath/libgmpxx.4.dylib @executable_path/../extra/fuel/usr/lib/libgmpxx.4.dylib $exec
    install_name_tool -change @rpath/libgmp.10.dylib @executable_path/../extra/fuel/usr/lib/libgmp.10.dylib $exec
done
