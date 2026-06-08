BeginPackage["LoopS`"];


$Path = Union@Append[$Path, DirectoryName[$InputFileName]];
Get["ParallelNeedS.m"];


$FeynCalcInstallPath = If[! FileExistsQ[$FeynCalcInstallPath], "FeynCalc`", $FeynCalcInstallPath];
$MultivariateApartInstallPath = If[! FileExistsQ[$MultivariateApartInstallPath], "MultivariateApart`", $MultivariateApartInstallPath];


FIREInstalledQ = If[! FileExistsQ[$FIREInstallPath], 
  Print["FIRE not found. Please set $FIREInstallPath as the path of FIRE's .m file. For example: \"/Users/balth/Downloads/MyLoopS/packages/fire/FIRE6/FIRE6.m\"."]; False, True];

If[$OperatingSystem =!= "Windows",
  If[! FileExistsQ[$OPITeRInstallPath], 
    Print["OPITeR not found. OPIteR can be added by:"];
    Print["git clone https://bitbucket.org/jaegoode/opiter.git "<> ToString[DirectoryName @ $OPITeRInstallPath]];
    Print["Or set $OPITeRInstallPath as the path of OPITeR's example.frm directory."]
    ]
];


EndPackage[];



Get[$FeynCalcInstallPath];
Print["FeynCalc is loaded by ", $FeynCalcInstallPath];

Get[$MultivariateApartInstallPath];
Print["MultivariateApart is loaded by ", $MultivariateApartInstallPath];

If[FIREInstalledQ, Get[$FIREInstallPath]];
Print["FIRE is loaded by ", $FIREInstallPath];


ParallelNeedS["FeynCalc`", $FeynCalcInstallPath];
Parallel`Protected`addBadContext["FeynCalc`"];
ParallelNeedS["MultivariateApart`", $MultivariateApartInstallPath];
If[FIREInstalledQ, ParallelNeedS["FIRE`", $FIREInstallPath]];


(*check FeynCalc version*)
If[!OrderedQ[{ToExpression@StringSplit["10.1.0", "."], ToExpression@StringSplit[$FeynCalcVersion, "."]}], Print["It is recommended to use FeynCalc version 10.1.0 or higher, as lower versions may cause unknown bugs."]];
