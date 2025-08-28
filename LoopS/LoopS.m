LoopS;

ClearAll[LoopS]
Options[LoopS] = {};
LoopS::usage = 
  "LoopS is an association that saves some defined global object used by \
LoopS. Run Keys[LoopS] to see them.";
LoopS = <|
   "CurrentProcess" :> CurrentProcess,
   "LoopSWorkDirectory" :> LoopSWorkDirectory,
   "CurrentAlgebras" :> CurrentAlgebras,
   "DefinedProcess" :> DefinedProcess,
   "SimplifyS" :> SimplifyS,
   "DiracPattern" :> DiracPattern,
   "OperatorPattern" :> OperatorPattern,
   "LoopSParallelKernels" :> LoopSParallelKernels
   |>;

SimplifyS = If[ToString[SimplifyS] === "SimplifyS", Factor, SimplifyS];

DiracPattern = _Dot | _Spinor | _GAD | _GSD | _DiracTrace;
OperatorPattern = 
  If[ToString@OperatorPattern === "OperatorPattern", DiracPattern, 
   OperatorPattern];