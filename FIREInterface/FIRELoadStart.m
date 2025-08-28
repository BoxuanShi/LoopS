FIRELoadStart;

ClearAll[FIRELoadStart]
Options[FIRELoadStart] = {"FIREVerbose" -> False};
FIRELoadStart[loops_List, family_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIRELoadStart[loops, family, ToExpression[process], opt]
FIRELoadStart[loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIRELoadStart[loops, family, FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], opt]
FIRELoadStart[loops_List, family_List, FIREWorkPath_String, 
   FIREFamilyName_String, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i},
  CloseKernels[];
  Print["Kernels are closed."];
  PrepareParallel[1];
  
  FIREEvaluate[
   BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
    AppendTo[$ContextPath, "FIRE`"];
    Do[LoadStart[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}], 
      i], {i, Length@family}];
    Burn[];]
   ];
  
  Print["Starts are loaded. Use FIREEvaluate to work in the first kernel."]
  ]