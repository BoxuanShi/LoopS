BeginPackage["LoopS`"];


(*LoopSNeat1*)
(*LoopSInformation*)
$LoopSVersion="2025-09-17";
$LoopSInstallPath = DirectoryName[$InputFileName];
(*LoopSNeat1*)


Print[Style["LoopS",FontFamily->"Arial",FontSize->14,FontColor->Black,Bold],
Style[" - A Mathematica package for Feynman amplitudes reduction. By Bo-Xuan Shi (shibx@mail.nankai.edu.cn). 
Version "<>$LoopSVersion<>".",FontFamily->"Arial",FontSize->14,FontColor->Black]
];
Print[
Style["See ",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[Hyperlink["https://github.com/BoxuanShi/LoopS","https://github.com/BoxuanShi/LoopS"],FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[" for more information.",FontFamily->"Arial",FontSize->14,FontColor->Black]
]

Get[FileNameJoin[{$LoopSInstallPath, "Config.m"}]];


EndPackage[];



(*LoadDependencies*)
Print["################## LoopS: Loading Dependencies ##################"];
$Path = Union@Append[$Path,FileNameJoin[{$LoopSInstallPath,"LoadDependencies"}]];
Get["LoadDependencies.m"];


(*LoopS*)
BeginPackage["LoopS`"];


$ContextPath = Prepend[$ContextPath, "Global`"];
$ContextPath = Prepend[$ContextPath, "FeynCalc`"];
$ContextPath = Prepend[$ContextPath, "MultivariateApart`"];
$ContextPath = Prepend[$ContextPath, "FIRE`"];
ParallelLoad["AddLoopSContext"]:= Module[{},
  If[!MemberQ[$ContextPath, "LoopS`"],
   $ContextPath = Prepend[$ContextPath, "LoopS`"];
   ];
];


Get[FileNameJoin[{$LoopSInstallPath, "Usage.m"}]];


Begin["LoopS`Private`"];
(*LoopSNeat2*)
(*ProcessDefine*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"ProcessDefine"}]];
Get["ProcessDefineLoad.m"];
(*BasicS*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"BasicS"}]];
Get["BasicSLoad.m"];
(*TensorReduction*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"TensorReduction"}]];
Get["TensorReductionLoad.m"];
(*FeynmanIntegralsClassification*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"FeynmanIntegralsClassification"}]];
Get["FeynmanIntegralsClassificationLoad.m"];
(*EquivalentIntegrals*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"EquivalentIntegrals"}]];
Get["EquivalentIntegralsLoad.m"];
(*FIREInterface*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"FIREInterface"}]];
Get["FIREInterfaceLoad.m"];
(*AMFlowInterface*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"AMFlowInterface"}]];
Get["AMFlowInterfaceLoad.m"];
(*MasterIntegralResults*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"MasterIntegralResults"}]];
Get["MasterIntegralResultsLoad.m"];
(*Unusual bug fix*)
LoopSWorkDirectory;
(*Generate LoopS directory*)
CreateDirectoryS[LoopSWorkDirectory];
(*LoopSNeatEnd2*)
End[];


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


EndPackage[];