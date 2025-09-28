ClearProcess[] := Module[{tp1, tp2, tp3, a, b, x1},

  tp1 = DownValues[AlgebrasDefinition];
  tp2 = tp1 /. CompoundExpression -> List;
  tp3 = Reap[
    Scan[Function[x1, If[MatchQ[Head[Unevaluated[x1]], Set|SetDelayed], Sow[Hold[x1]]], HoldAll], tp2, {0, Infinity}]
  ][[2]]//Flatten;
  tp3 /. HoldPattern[(a_:=b_)|(a_=b_)] :> (a =.) // ReleaseHold;

  (*Clear user defined FeynCalcs - general*)
  FCClearScalarProducts[];
  DataType[__, _] := False;

  (*Distribute to CurrentProcess*)
  CurrentProcess = <||>;
   (* CreateProcess[<|"ProcessName" -> "", "loopmoms" -> {}, "extmomsind" -> {}, 
     "kinematics" -> {}|>]; *)
  
  (*Distribute to CurrentAlgebras*)
  CurrentAlgebras = {};

  (*Clear user defined - special*)
  ClearProcess /@ DefinedProcess;
  
  Print["The current process have been cleared."];
  ]