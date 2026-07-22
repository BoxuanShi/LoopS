(*Paths-for subkernels*)
If[$KernelID =!= 0,
$LoopSInstallPath = DirectoryName[$InputFileName];
$NotebookDirectory = LoopS`Private`nbd;
];
$LoopSBaseDirectory[] := $NotebookDirectory;


(*LoopSNeat2*)
$Path = Union@Append[$Path, $LoopSInstallPath];
(*ProcessDefine*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"ProcessDefine"}]];
Get["ProcessDefineLoad.m"];
(*BasicFunctions*)
$Path = Union@Append[$Path, FileNameJoin[{$LoopSInstallPath,"BasicFunctions"}]];
Get["BasicFunctionsLoad.m"];
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
(* CreateDirectoryS[LoopSWorkDirectory]; *)
(*LoopSNeatEnd2*)
