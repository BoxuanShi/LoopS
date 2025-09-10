ClearAll[PrepareParallel]
LoopSParallelKernels = 
  If[NumberQ[LoopSParallelKernels], LoopSParallelKernels, 4];
Options[PrepareParallel] := 
  CreateOptions[{"Kernels" :> LoopSParallelKernels}, {ParallelEvaluate}];
PrepareParallel[kernels0_Integer : 0, opt : OptionsPattern[]] := 
 Module[{kernels, deltaKernel, optE},
  
  kernels = If[kernels0 == 0, OptionValue["Kernels"], kernels0];
  deltaKernel = kernels - $KernelCount;
  Which[deltaKernel > 0, LaunchKernels[deltaKernel](*,deltaKernel<0,
   CloseKernels[ParallelEvaluate[$KernelID][[deltaKernel;;-1]]]*)];
  
  ParallelEvaluate[
   Block[{Monitor = (# &)},
    ParallelLoad[];
    Block[{Print = (# &)}, 
     SetupProcess[Sequence @@ CurrentAlgebras, "CreateFiles" -> False]]]
   , DistributedContexts :> OptionValue[DistributedContexts]
   ];
  
  Print["Parallelization is prepared for ", kernels, " Kernels."];
  Print["The default number of the kernel prepared is controlled by \
LoopSParallelKernels."];
  ]