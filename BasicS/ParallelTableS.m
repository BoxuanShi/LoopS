$DistributedContexts = All;

ClearAll[ParallelEvaluateS]
SetAttributes[ParallelEvaluateS, HoldFirst]
ParallelEvaluateS::usage = "1. Block Monitor=(#&).
2. \"Kernels\" is only useful when $KernelCount == 0.";
Options[ParallelEvaluateS] := CreateOptions[{}, {ParallelEvaluate, PrepareParallel}];
ParallelEvaluateS[expr_, opt : OptionsPattern[]] := Module[{opt1},
  If[$KernelCount == 0, PrepareParallel[Evaluate@FilterOptions[{opt}, PrepareParallel]]];
  opt1 = FilterOptions[{opt}, {ParallelEvaluate}];
  ParallelEvaluate[Block[{Monitor = # &}, expr], ParallelEvaluate[$KernelID][[1 ;; $KernelCount]], Evaluate@opt1]
  ];

ParallelEvaluateS[expr_, ker_Integer, opt : OptionsPattern[]] := Module[{opt1},
  If[$KernelCount == 0, PrepareParallel[Evaluate@FilterOptions[{opt}, PrepareParallel]]];
  opt1 = FilterOptions[{opt}, ParallelEvaluate];
  ParallelEvaluate[Block[{Monitor = # &}, expr], ParallelEvaluate[$KernelID][[ker]], Evaluate@opt1]
  ];

(*If there are subkernels, ParallelTableS will not launch new kernels according to LoopSParallelKernels or option "Kernels"*)
ClearAll[ParallelTableS]
SetAttributes[ParallelTableS, HoldAll];
ParallelTableS::usage = "1. Block Monitor=(#&).
2. Method->(\"ItemsPerEvaluation\"->1).
3. \"Kernels\" is only useful when $KernelCount == 0.";
Options[ParallelTableS] := CreateOptions[{}, {ParallelTable, PrepareParallel}];
ParallelTableS[expr_, rg__List, opt : OptionsPattern[]] := Module[{tp1},
  If[$KernelCount == 0, PrepareParallel[Evaluate @ FilterOptions[{opt}, PrepareParallel]]];
  tp1 = ParallelTable[Block[{Monitor = (# &)}, expr], rg, Evaluate @ FilterOptions[{opt}, ParallelTable], Method -> ("ItemsPerEvaluation" -> 1)];
  tp1
  ];
