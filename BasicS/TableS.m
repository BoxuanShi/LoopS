ClearAll[TimingS, CreateDirectoryS]
SetAttributes[TimingS, HoldFirst]
TimingS::usage = "TimingS[expr, str] evaluate expr and print the time used with optional str. When using the second argument, do not use profix \"\\\\\".";
TimingS[expr_, str_String : ""] := Module[{tp1, tp2, tp3},
  tp2 = expr // AbsoluteTiming;
  Print[str <> "The time used is ", tp2[[1]], " s."];
  tp2[[2]]
]
CreateDirectoryS[sym_] := If[! DirectoryQ[sym], CreateDirectory[sym]]


ClearAll[FilterOptions]
FilterOptions[opts_List, name_] := Sequence @@ FilterRules[opts, Flatten[Options /@ Flatten@{name}]]


ClearAll[TableS]
Options[TableS] := CreateOptions[{"Parallelization" -> False}, {ParallelTableS}];
TableS[a_, b__List, word : Except[_Rule|_RuleDelayed, _String] : "", opt : OptionsPattern[]] := Module[{optPara, res},

  Off[Part::pkspec1];

  res = If[$KernelID === 0,
   If[OptionValue["Parallelization"],
    optPara = FilterOptions[{opt}, ParallelTableS];
    ParallelTableS[a, b, Evaluate[optPara]]
    ,
    Monitor[Table[a, b], Refresh[DeleteCases[{word, b}, ""], UpdateInterval -> 0.25, TrackedSymbols -> {}]]
    ]
   ,
   Table[a, b]
   ];

  On[Part::pkspec1];

  res

  ]
SetAttributes[TableS, HoldAll]


ClearAll[DoS]
DoS[a_, b__List] := If[$KernelID === 0, Monitor[Do[a, b], Refresh[{b}, UpdateInterval -> 0.25, TrackedSymbols -> {}]], Do[a, b]]
DoS[a_, b__List, word_String] := If[$KernelID === 0, 
  Monitor[Do[a, b], Refresh[{word, b}, UpdateInterval -> 0.25, TrackedSymbols -> {}]], 
  Do[a, b]]
SetAttributes[DoS, HoldAll]
