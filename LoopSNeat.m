(*LoopSNeat1*)
(*LoopSInformation*)
$LoopSVersion="2025-09-17";
$LoopSInstallPath = DirectoryName[$InputFileName];
(*LoopSNeat1*)


(*LoopSNeat2*)
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