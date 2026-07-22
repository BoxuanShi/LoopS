BeginPackage["LoopS`"];


(*Paths*)
$LoopSInstallPath = DirectoryName[$InputFileName];
$LoopSScriptDirectory[] := Module[{cmd, kernelCmd, script, scriptPosition},
  cmd = Quiet@Check[$ScriptCommandLine, {}];
  kernelCmd = Quiet@Check[$CommandLine, {}];
  script = If[ListQ[cmd] && Length[cmd] > 0, First[cmd], ""];
  If[! StringQ[script] || ! FileExistsQ[script],
    scriptPosition = If[ListQ[kernelCmd], FirstPosition[kernelCmd, "-script"], Missing["NotFound"]];
    script = If[
      MatchQ[scriptPosition, {_Integer}] && First[scriptPosition] < Length[kernelCmd],
      kernelCmd[[First[scriptPosition] + 1]],
      ""
    ]
  ];
  If[StringQ[script] && FileExistsQ[script], DirectoryName[ExpandFileName[script]], Directory[]]
];
$LoopSBaseDirectory[] := If[$FrontEnd === Null, $LoopSScriptDirectory[],
  Quiet@Check[DirectoryName[NotebookFileName[]], Directory[]]
];
$NotebookDirectory = $LoopSBaseDirectory[];


$LoopSVersion="1.2.0";
Print[Style["LoopS",FontFamily->"Arial",FontSize->14,FontColor->Black,Bold],
Style[" - A Mathematica package for Feynman amplitudes reduction. By Bo-Xuan Shi (shibx@mail.nankai.edu.cn). 
Version "<>$LoopSVersion<>".",FontFamily->"Arial",FontSize->14,FontColor->Black]
];
Print[
Style["See ",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[Hyperlink["Github","https://github.com/BoxuanShi/LoopS"],FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[" for more information.",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style["If you use LoopS in your research, please cite it by",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[Hyperlink["Zenodo","https://doi.org/10.5281/zenodo.17383900"],FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[".",FontFamily->"Arial",FontSize->14,FontColor->Black]
];

Get[FileNameJoin[{$LoopSInstallPath, "Config.m"}]];


EndPackage[];


(*LoadDependencies*)
Print["################## LoopS: Loading Dependencies ##################"];
$Path = Union@Append[$Path,FileNameJoin[{$LoopSInstallPath,"LoadDependencies"}]];
Get["LoadDependencies.m"];


(*LoopS*)
Get[FileNameJoin[{$LoopSInstallPath, "LoopSCore.m"}]];
With[{LoopS`Private`ins = $LoopSInstallPath, LoopS`Private`nbdd = $NotebookDirectory},
Parallel`Protected`AddInitCode[Parallel`Client`HoldCompound[
      Block[{LoopS`Private`nbd = LoopS`Private`nbdd},
      (* Get[FileNameJoin[{LoopS`Private`ins, "Config.m"}]]; *)
      Get[FileNameJoin[{LoopS`Private`ins, "LoopSCore.m"}]]]
      ]]
];
(* Parallel`Protected`addBadContext["LoopS`"];*)
(*this is because of that the definitions of "AlgebrasDefinition", so as "ClearProcess", etc, are changed by the user. I can add the above line and optimize the package by adding "DumpDistribute" to the relevant functions in "PrepareParallel" in the future, since "DumpDistribute" still functions even with the above line, which is different with the MMA function DistirbuteDefinition.*)


(*setshared*)
SetSharedVariable[
    $FeynCalcInstallPath, 
    $MultivariateApartInstallPath, 
    $FIREInstallPath, 
    $KiraExecutable,
    $OPITeRInstallPath
    ];


(*self-consistence check*)
If[$OperatingSystem==="Windows",

    Print["Warning: PV reduction with OPITeR is not supported on Windows in LoopS, which may result in slower performance. Please use Linux or macOS for optimal performance."];
    SetOptions[GeneratePV, "UseOPITeR" -> False]
    ,
    
    If[GeneratePVOPITeR[{},{}]=== $Failed, 
    Print["OPITeR test failed! Please verify that OPITeR and FORM are correctly installed."];
    Print["LoopS can be used without OPITeR, but the efficiency of Passarino-Veltman reduction will be significantly reduced in complex cases if OPITeR is not available."];,
    Print["OPITeR test passed."]
    ];
];


Print["################### LoopS: Dependencies Loaded ##################"];
