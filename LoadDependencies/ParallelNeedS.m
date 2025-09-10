ParallelNeedS;


Begin["LoopS`Private`"];


(*Parallel`Kernels`Private`$clientCode*)
(*SetSharedVariable[CurrentProcess];*)
ClearAll[ParallelNeedS]
ParallelNeedS[context_] := ParallelNeeds[context]
ParallelNeedS[context_, filepath_String] := Module[{},
  Parallelize;
  If[FileExistsQ[filepath],
   Parallel`Protected`AddInitCode[
    Parallel`Client`HoldCompound[
      Block[{Print=(#&)}, Needs[context, filepath]]
      ]],
   ParallelNeeds[context]
   ]
  ]


End[];