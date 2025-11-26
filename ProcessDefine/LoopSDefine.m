ClearAll[LoopS]
Options[LoopS] = {};
LoopS::usage = "LoopS is an association that saves some defined global and process correlated objects that can be modified by users. PrepareParallel will distribute their definitions into subkernels.";
LoopS = <|
  "LoopSWorkDirectory" :> LoopSWorkDirectory,
  "SimplifyS" :> SimplifyS,
  "DiracPattern" :> DiracPattern,
  "OperatorPattern" :> OperatorPattern,
  "AmplitudePattern" :> AmplitudePattern,
  "LoopSParallelKernels" :> LoopSParallelKernels,

  "AlgebrasDefinition" :> AlgebrasDefinition,
  "ClearProcess" :> ClearProcess,

  "ProcessPath" :> ProcessPath,
  "CurrentProcess" :> CurrentProcess,
  "CurrentAlgebras" :> CurrentAlgebras,
  "DefinedProcess" :> DefinedProcess
|>;

Once[
  DefinedProcess = {};
]

LoopSWorkDirectory = PathName @ FileNameJoin[{ExpandFileName[$NotebookDirectory], "LoopSFile","Processes"}];
SimplifyS = If[ToString[SimplifyS] === "SimplifyS", Factor, SimplifyS];
DiracPattern =  _Dot | _DiracTrace | _Spinor | _GAD | _GSD | _DiracGamma;
OperatorPattern = If[ToString@OperatorPattern === "OperatorPattern", DiracPattern, OperatorPattern];
AmplitudePattern = _Dot | _DiracTrace | _Spinor | _GAD | _GSD | _FVD | _MTD | _FAD | _SFAD| _SPD | _Pair | _DiracGamma;