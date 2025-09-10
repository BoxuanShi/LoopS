ClearAll[TimingS, CreateDirectoryS]
SetAttributes[TimingS, HoldAll]
TimingS[expr_, str_String : ""] := Module[{tp1, tp2, tp3},
  tp2 = expr // AbsoluteTiming;
  Print[str <> "The time used is ", tp2[[1]], " s."];
  tp2[[2]]
  ]
CreateDirectoryS[sym_] := If[! DirectoryQ[sym], CreateDirectory[sym]]


ClearAll[FilterOptions]
FilterOptions[opts_List, name_] := 
 Sequence @@ FilterRules[opts, Flatten[Options /@ Flatten@{name}]]


ClearAll[TableS]
Options[TableS] := 
  CreateOptions[{"Parallelization" -> False}, {ParallelTableS}];
TableS[a_, b__List, word_String : "", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{optPara},
  If[$KernelID === 0,
   If[OptionValue["Parallelization"],
    optPara = FilterOptions[{opt}, ParallelTableS];
    ParallelTableS[a, b, Evaluate[optPara]]
    ,
    Monitor[Table[a, b], 
     Refresh[DeleteCases[{word, b}, ""], UpdateInterval -> 0.25, 
      TrackedSymbols -> {}]]
    ]
   ,
   Table[a, b]
   ]
  ]
SetAttributes[TableS, HoldAll]


ClearAll[DoS]
DoS[a_, b__List] := 
 If[$KernelID === 0, 
  Monitor[Do[a, b], 
   Refresh[{b}, UpdateInterval -> 0.25, TrackedSymbols -> {}]], Do[a, b]]
DoS[a_, b__List, word_String] := 
 If[$KernelID === 0, 
  Monitor[Do[a, b], 
   Refresh[{word, b}, UpdateInterval -> 0.25, TrackedSymbols -> {}]], Do[a, b]]
SetAttributes[DoS, HoldAll]
