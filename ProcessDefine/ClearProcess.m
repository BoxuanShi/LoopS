ClearProcess[] := Module[{},
  (*Clear defined FeynCalcs - general*)
  FCClearScalarProducts[];
  UpValues[Spinor] =.;
  DataType[__, _] := False;
  (*Clear defined FeynCalcs - special*)
  ClearProcess /@ DefinedProcess;
  
  (*Distribute to CurrentProcess*)
  CurrentProcess = 
   CreateProcess[<|"ProcessName" -> "", "loopmoms" -> {}, "extmomsind" -> {}, 
     "kinematics" -> {}|>];
  
  (*Distribute to CurrentAlgebras*)
  CurrentAlgebras = {};
  
  Print["The current process have been cleared."];
  ]