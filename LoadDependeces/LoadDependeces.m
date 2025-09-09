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
  If[! FileExistsQ[DirectoryName @ $OPITeRInstallPath], 
  CreateDirectory[DirectoryName @ $OPITeRInstallPath];
  Monitor[
  RunProcess[{"git", "clone", "https://bitbucket.org/jaegoode/opiter.git", DirectoryName @ $OPITeRInstallPath}]
  , "OPITeR is not installed. Downloading OPITeR by \"git clone https://bitbucket.org/jaegoode/opiter.git\"..."]
  ,
  Print[Style["OPITeR not found. Please set $OPITeRInstallPath as the path of OPITeR's example.frm directory. For example: \"/Users/balth/Downloads/MyLoopS/packages/opiter\".", FontColor->Red]]
  ]
];


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
