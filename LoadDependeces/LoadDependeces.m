LoadDependences;

(*Parallel`Kernels`Private`$clientCode*)

(*SetSharedVariable[CurrentProcess];*)

ClearAll[ParallelNeedS]
ParallelNeedS[context_] := ParallelNeeds[context]
ParallelNeedS[context_, filepath_String] := Module[{},
  Parallelize;
  If[FileExistsQ[filepath],
   Parallel`Protected`AddInitCode[
    Parallel`Client`HoldCompound[Needs[context, filepath]]],
   ParallelNeedS[context]
   ]
  ]


$FeynCalcInstallPath = 
  If[! FileExistsQ[$FeynCalcInstallPath], "FeynCalc`", $FeynCalcInstallPath];
$MultivariateApartInstallPath = 
  If[! FileExistsQ[$MultivariateApartInstallPath], 
   "MultivariateApart`", $MultivariateApartInstallPath];


FIREInstalledQ = If[! FileExistsQ[$FIREInstallPath], 
  Print[Style["FIRE not found. Please set $FIREInstallPath as the path of FIRE's .m file. For example: \"/Users/balth/Downloads/MyLoopS/packages/fire/FIRE6/FIRE6.m\".", FontColor->Red]]; False, True];

If[! FileExistsQ[$OPITeRInstallPath], 
Print[Style["OPITeR not found. Please set $OPITeRInstallPath as the path of OPITeR's example.frm directory. For example: \"/Users/balth/Downloads/MyLoopS/packages/opiter\".", FontColor->Red]]];


Get[$FeynCalcInstallPath];
Get[$MultivariateApartInstallPath];
If[FIREInstalledQ, Get[$FIREInstallPath]];


ParallelNeedS["FeynCalc`", $FeynCalcInstallPath];
ParallelNeedS["MultivariateApart`", $MultivariateApartInstallPath]
If[FIREInstalledQ, ParallelNeedS["FIRE`", $FIREInstallPath]];
