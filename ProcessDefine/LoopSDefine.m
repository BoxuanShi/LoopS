ClearAll[LoopS]
Options[LoopS] = {};
LoopS::usage = 
  "LoopS is an association that saves some defined global object used by \
LoopS. Run Keys[LoopS] to see them.";
LoopS = <|
  "LoopSWorkDirectory" :> LoopSWorkDirectory,
  "CurrentProcess" :> CurrentProcess,
  "CurrentAlgebras" :> CurrentAlgebras,
  "AlgebrasDefinition" :> AlgebrasDefinition,
  "ClearProcess" :> ClearProcess,
  "DefinedProcess" :> DefinedProcess,
  "SimplifyS" :> SimplifyS,
  "DiracPattern" :> DiracPattern,
  "OperatorPattern" :> OperatorPattern,
  "AmplitudePattern" :> AmplitudePattern,
  "LoopSParallelKernels" :> LoopSParallelKernels
|>;

SimplifyS = If[ToString[SimplifyS] === "SimplifyS", Factor, SimplifyS];

DiracPattern =  _Dot | _DiracTrace | _Spinor | _GAD | _GSD | _DiracGamma;

OperatorPattern = 
  If[ToString@OperatorPattern === "OperatorPattern", DiracPattern, 
   OperatorPattern];

AmplitudePattern = _Dot | _DiracTrace | _Spinor | _GAD | _GSD | _FVD | _MTD | _FAD | _SPD | _Pair | _DiracGamma;