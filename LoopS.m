BeginPackage["LoopS`"];


(*Paths*)
$LoopSInstallPath = DirectoryName[$InputFileName];
$NotebookDirectory = DirectoryName[NotebookFileName[]]


$LoopSVersion="2025-12-20";
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
    $OPITeRInstallPath
    ];


(*self-consistence check*)
If[$OperatingSystem==="Windows",

    Print[Style["Warning: PV reduction with OPITeR is not supported on Windows in LoopS, which may result in slower performance. Please use Linux or macOS for optimal performance.", FontColor->Red]];
    SetOptions[GeneratePV, "UseOPITeR" -> False]
    ,
    
    If[GeneratePVOPITeR[{},{}]=== $Failed, 
    Print[Style["OPITeR test failed! Please verify that OPITeR and FORM are correctly installed.", FontColor->Red]];
    Print[Style["LoopS can be used without OPITeR, but the efficiency of Passarino–Veltman reduction will be significantly reduced in complex cases if OPITeR is not available.", FontColor->Red]];,
    Print["OPITeR test passed."]
    ];
];


Print["################### LoopS: Dependencies Loaded ##################"];