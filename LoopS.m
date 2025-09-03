(*LoopSInformation1*)
$LoopSVersion="2025-08-28";
$LoopSInstallPath = DirectoryName[$InputFileName];


(*LoadDependeces*)
Print["################## LoopS: Loading Dependences ##################"];
$Path = Union@Append[$Path,FileNameJoin[{$LoopSInstallPath,"LoadDependeces"}]];
Get["LoadDependeces.m"];
Print["################### LoopS: Dependences Loaded ##################"];


(*LoopSInformation2*)
Print[Style["LoopS",FontFamily->"Arial",FontSize->14,FontColor->Black,Bold],
Style[" - A Mathematica package for Feynman amplitudes reduction. By Bo-Xuan Shi (shibx@mail.nankai.edu.cn). 
Version "<>$LoopSVersion<>".",FontFamily->"Arial",FontSize->14,FontColor->Black]
];
Print[
Style["See ",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[Hyperlink["https://github.com/BoxuanShi/LoopS","https://github.com/BoxuanShi/LoopS"],FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[" for more information.",FontFamily->"Arial",FontSize->14,FontColor->Black]
]


(*ProcessDefine*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"ProcessDefine"}]];
Get["ProcessDefineLoad.m"];
(*BasicS*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"BasicS"}]];
Get["BasicSLoad.m"];
(*PVReduction*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"PVReduction"}]];
Get["PVReductionLoad.m"];
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


(*self-consistence check*)
If[$OperatingSystem==="Windows",

    Print[Style["Warning: PV reduction with OPITeR is not supported on Windows in LoopS, which may result in slower performance. Please use Linux or macOS for optimal performance.", FontColor->Red]];
    SetOptions[GeneratePV, "UseOPITeR" -> False]
    ,
    
    If[GeneratePVOPITeR[{},{}]=== $Failed, 
    Print[Style["GeneratePVOPITeR test failed! Please verify that OPITeR and FORM are correctly installed.", FontColor->Red]]];
];