ParallelNeedS;


Begin["LoopS`Private`"];


(*Parallel`Kernels`Private`$clientCode*)
ClearAll[ParallelNeedS]
ParallelNeedS[context_] := ParallelNeeds[context]
ParallelNeedS[context_, filepath_String] := Module[{},
  Parallelize;
  If[FileExistsQ[filepath],
   Parallel`Protected`AddInitCode[
    Parallel`Client`HoldCompound[
      Block[{Print=(#&)}, Needs[context, filepath]]
      ]];
    (* Parallel`Protected`addBadContext[context] *)
    ,
   ParallelNeeds[context]
   ]
  ]


End[];