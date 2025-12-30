BeginPackage["LoopS`"];


(*Paths-for subkernels*)
If[$KernelID =!= 0,
$LoopSInstallPath = DirectoryName[$InputFileName];
$NotebookDirectory = LoopS`Private`nbd;
];


$ContextPath = Prepend[$ContextPath, "Global`"];
$ContextPath = Prepend[$ContextPath, "FeynCalc`"];
$ContextPath = Prepend[$ContextPath, "MultivariateApart`"];
$ContextPath = Prepend[$ContextPath, "FIRE`"];


Get[FileNameJoin[{$LoopSInstallPath, "Usage.m"}]];


Begin["LoopS`Private`"];
(*LoopSNeat2*)
$Path = Union@Append[$Path, $LoopSInstallPath];
(*ProcessDefine*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"ProcessDefine"}]];
Get["ProcessDefineLoad.m"];
(*BasicS*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"BasicS"}]];
Get["BasicSLoad.m"];
(*DifferentialEquations*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"DifferentialEquations"}]];
Get["DifferentialEquationsLoad.m"];
(*TensorReduction*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"TensorReduction"}]];
Get["TensorReductionLoad.m"];
(*FeynmanIntegralsClassification*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"FeynmanIntegralsClassification"}]];
Get["FeynmanIntegralsClassificationLoad.m"];
(*EquivalentIntegrals*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"EquivalentIntegrals"}]];
Get["EquivalentIntegralsLoad.m"];
(*IBPReduction*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"IBPReduction"}]];
Get["IBPReductionLoad.m"];
(*Interfaces*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"Interfaces"}]];
Get["InterfacesLoad.m"];
(*MasterIntegralResults*)
(* $Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"MasterIntegralResults"}]]; *)
(* Get["MasterIntegralResultsLoad.m"]; *)
(*Unusual bug fix*)
(* LoopSWorkDirectory; *)
(*Generate LoopS directory*)
CreateDirectoryS[LoopSWorkDirectory];
(*LoopSNeatEnd2*)
End[];


EndPackage[];


$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"Extra"}]];
Get["ExtraLoad.m"];