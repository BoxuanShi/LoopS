BeginPackage["LoopS`"];


$Path = Union@Append[$Path, DirectoryName[$InputFileName]];
Get["ParallelNeedS.m"];


$FeynCalcInstallPath = If[! FileExistsQ[$FeynCalcInstallPath], "FeynCalc`", $FeynCalcInstallPath];
$MultivariateApartInstallPath = If[! FileExistsQ[$MultivariateApartInstallPath], "MultivariateApart`", $MultivariateApartInstallPath];


FIREInstalledQ = If[! FileExistsQ[$FIREInstallPath], 
  Print["FIRE not found. Set $FIREInstallPath to FIRE7.m. For a LoopS source checkout, initialize dependencies with: git submodule update --init --recursive"];
  False,
  True
];

If[$OperatingSystem =!= "Windows",
  If[! FileExistsQ[$OPITeRInstallPath], 
    Print["OPITeR not found. For a LoopS source checkout, run: git submodule update --init --recursive"];
    Print["Or set $OPITeRInstallPath to OPITeR's opiter directory."]
    ]
];


EndPackage[];



Get[$FeynCalcInstallPath];
Print["FeynCalc is loaded by ", $FeynCalcInstallPath];

Get[$MultivariateApartInstallPath];
Print["MultivariateApart is loaded by ", $MultivariateApartInstallPath];

If[
  FIREInstalledQ,
  Get[$FIREInstallPath];
  Print["FIRE is loaded by ", $FIREInstallPath],
  Print["FIRE was not loaded. FIRE-dependent functions remain unavailable."]
];


ParallelNeedS["FeynCalc`", $FeynCalcInstallPath];
Parallel`Protected`addBadContext["FeynCalc`"];
ParallelNeedS["MultivariateApart`", $MultivariateApartInstallPath];
If[FIREInstalledQ, ParallelNeedS["FIRE`", $FIREInstallPath]];


(*check FeynCalc version*)
If[!OrderedQ[{ToExpression@StringSplit["10.1.0", "."], ToExpression@StringSplit[$FeynCalcVersion, "."]}], Print["It is recommended to use FeynCalc version 10.1.0 or higher, as lower versions may cause unknown bugs."]];
