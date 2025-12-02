ClearProcess[] := Module[{tp1, tp2, tp3, a, b, x1},
  (*bugs when Module[{kinematics,...}]*)
  tp1 = DownValues[AlgebrasDefinition];
  tp2 = tp1 /. CompoundExpression -> List;
  tp3 = Reap[
    Scan[Function[x1, If[MatchQ[Head[Unevaluated[x1]], Set|SetDelayed], Sow[Hold[x1]]], HoldAll], tp2, {0, Infinity}]
    ][[2]] // Flatten;
  tp3 /. HoldPattern[(a_:=b_)|(a_=b_)] :> (a =.) // ReleaseHold // Quiet;
  (*Clear user defined FeynCalcs - general*)
  FCClearScalarProducts[];
  DataType[__, _] := False;

  CurrentProcess =.;
  CurrentAlgebras =.;
  ProcessPath =.;

  (*Clear user defined - special*)
  ClearProcess /@ DefinedProcess;
  Print["The current process have been cleared."];
]


ClearAll[SetupProcess];
SetupProcess::spddefine = "Irreducible scalar product `1` exist.";
Options[SetupProcess] := {"DefineSPD" -> True, "CreateFiles" -> True};
(*clear process*)
SetupProcess[] := ClearProcess[];
(*define process*)
SetupProcess["CurrentProcess", ___] := Print["CurrentProcess has been used by LoopS, please choose another name for your process."]
SetupProcess[process_String, b___, opt : OptionsPattern[]] := Module[{x, i, j, outerSPD, processA},

  (*ClearProcess*)
  Block[{Print = (# &)}, ClearProcess[]];
  
  (*check*)
  processA = ToExpression @ process;
  If[Head @ processA =!= Association, Print["Define the process " <> process <> " firstly."]; Abort[]];
  Quiet[If[ToExpression[process]["ProcessName"] =!= process, Print[process <> "[\"ProcessName\"] should be the same as \"" <> process <> "\"."]; Abort[]]];

  (*distribute to CurrentProcess*)
  ToExpression[process, InputForm, Function[{x1}, CurrentProcess := x1, HoldAll]];
  Print["CurrentProcess have been set as " <> process, "."];
  (*distribute to DefinedProcess*)
  Unprotect[DefinedProcess];
  DefinedProcess = Append[DefinedProcess, process] // Union;
  (*distribute to CurrentAlgebras*)
  CurrentAlgebras = {process, b};
  Print["CurrentAlgebras have been set as: " <> ToString @ CurrentAlgebras, "."];

  (*Distribute to some global variables*)
  Unprotect[ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, kinematics, indices, purePV];
  {ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, kinematics, indices, purePV, operatorRules} = CurrentProcess /@ {"ProcessName", "moms", "loopmoms", "extmoms", "extmomsind", "extramoms", "kinematics", "indices", "purePV", "operatorRules"};
  Protect[ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, kinematics, indices, purePV];

  (*setshared*)
  If[$KernelID == 0, "SetSharedVariable[" <> processA["purePV"] <> "]" // ToExpression];
  Print[processA["ProcessName"] <> " and " <> processA["purePV"] <> " are shared for subkernels."];

  (*Define algebras*)
  If[OptionValue["DefineSPD"],
   Table[SPD[extmomsind[[i]], extmomsind[[j]]] = extmomsind[[i]]*extmomsind[[j]] /. kinematics, {i, Length@extmomsind}, {j, i}];
   ];
  AlgebrasDefinition[process, b];

  (*check extramom definitions*)
  outerSPD = Outer[SPD, extramoms, extramoms] // ExpandMomentum // ExpandDirac // getS[#, x : _SPD /; FreeQ[x, Alternatives @@ loopmoms]] &;
  If[outerSPD =!= {}, Message[SetupProcess::spddefine, outerSPD]];


  ProcessPath = FileNameJoin[{LoopSWorkDirectory, process}];
  (*CreateFiles*)
  If[OptionValue["CreateFiles"], 
    CreateDirectoryS[ProcessPath];
    Put[processA, FileNameJoin[{ProcessPath, process}]]];

  Print["LoopS work directory is LoopSWorkDirectory -> ", LoopSWorkDirectory, "."];

  ]

SetupProcess[CurrentAlgebras_List, opt : OptionsPattern[]] := Block[{Print = (# &)}, SetupProcess[Sequence @@ CurrentAlgebras, opt]]


ClearAll[SetProcessDirectory]
SetProcessDirectory[] := (
  SetDirectory[ProcessPath];
  If[$KernelCount =!= 0, ParallelEvaluate[SetDirectory[ProcessPath], DistributedContexts -> All];];
  Print["Directory[] has been set as: ", ProcessPath, "."]
)