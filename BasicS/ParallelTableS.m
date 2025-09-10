$DistributedContexts = All;

ClearAll[ParallelEvaluateS]
SetAttributes[ParallelEvaluateS, HoldFirst]
ParallelEvaluateS::usage = "1. Block Monitor=(#&).";
Options[ParallelEvaluateS] := 
  CreateOptions[{}, {ParallelEvaluate, PrepareParallel}];
ParallelEvaluateS[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{kernelnumber, ker, mode, deltaKernel, tp1, opt1},
  If[$KernelCount == 0, 
   PrepareParallel[Evaluate@FilterOptions[{opt}, PrepareParallel]]];
  opt1 = FilterOptions[{opt}, {ParallelEvaluate}];
  ParallelEvaluate[Block[{Monitor = # &}, expr], 
   ParallelEvaluate[$KernelID][[1 ;; $KernelCount]], Evaluate@opt1]
  ]

ParallelEvaluateS[expr_, ker_Integer, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{kernelnumber, mode, deltaKernel, tp1, opt1},
  If[$KernelCount == 0, 
   PrepareParallel[Evaluate@FilterOptions[{opt}, PrepareParallel]]];
  opt1 = FilterOptions[{opt}, ParallelEvaluate];
  ParallelEvaluate[Block[{Monitor = # &}, expr], 
   ParallelEvaluate[$KernelID][[ker]], Evaluate@opt1]
  ]
SetAttributes[ParallelEvaluateS, HoldFirst]


ClearAll[ParallelTableS]
ParallelTableS::usage = "1. Block Monitor=(#&).
2. Method->(\"ItemsPerEvaluation\"->1).";
Options[ParallelTableS] := CreateOptions[{Method -> ("ItemsPerEvaluation" -> 1)}, {ParallelTable, PrepareParallel}];
ParallelTableS[expr_, rg__List, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{kernelnumber, mode, Nkernel, tp1, opt1},
  If[$KernelCount == 0, 
   PrepareParallel[Evaluate@FilterOptions[{opt}, PrepareParallel]]];
  
  tp1 = ParallelTable[
    Block[{Monitor = (# &)}, expr]
    , rg, Evaluate@FilterOptions[{opt}, ParallelTable], 
    Method -> OptionValue[Method]];
  If[mode == 0, CloseKernels[]];
  tp1
  ]
SetAttributes[ParallelTableS, HoldAll]
