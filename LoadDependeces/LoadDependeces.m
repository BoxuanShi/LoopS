LoadDependences;

(*Parallel`Kernels`Private`$clientCode*)

(*SetSharedVariable[CurrentProcess];*)

ClearAll[ParallelNeedS]
ParallelNeedS[context_] := ParallelNeeds[context]
ParallelNeedS[context_, filepath_String] := Module[{},
  Parallelize;
  If[FileExistsQ[filepath],
   Parallel`Protected`AddInitCode[
    Parallel`Client`HoldCompound[
      Block[{Print=(#&)}, Needs[context, filepath]]
      ]],
   ParallelNeeds[context]
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
  Print[Style["OPITeR not found. OPIteR can be add by:", FontColor->Red]];
  DeleteDirectory[DirectoryName @ $OPITeRInstallPath, DeleteContents -> True];
  Print[Style["OPIteR can be add by: git clone https://bitbucket.org/jaegoode/opiter.git "<> ToString[DirectoryName @ $OPITeRInstallPath], FontColor->Red]];
  Print[Style["Or set $OPITeRInstallPath as the path of OPITeR's example.frm directory.", FontColor->Red]]
]


Get[$FeynCalcInstallPath];
Print["FeynCalc is loaded by ", $FeynCalcInstallPath];

Get[$MultivariateApartInstallPath];
Print["MultivariateApart is loaded by ", $MultivariateApartInstallPath];

If[FIREInstalledQ, Get[$FIREInstallPath]];
Print["FIRE is loaded by ", $FIREInstallPath];


ParallelNeedS["FeynCalc`", $FeynCalcInstallPath];
ParallelNeedS["MultivariateApart`", $MultivariateApartInstallPath];
If[FIREInstalledQ, ParallelNeedS["FIRE`", $FIREInstallPath]];


(*check FeynCalc version*)
If[!OrderedQ[{ToExpression@StringSplit["10.1.0", "."], ToExpression@StringSplit[$FeynCalcVersion, "."]}], Print[Style["It is recommended to use FeynCalc version 10.1.0 or higher, as lower versions may cause unknown bugs.", FontColor->Red]]];
