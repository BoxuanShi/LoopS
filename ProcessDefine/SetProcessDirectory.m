ClearAll[SetProcessDirectory]
SetProcessDirectory[] := Module[{dir},
  dir = ProcessPath@ProcessName;
  SetDirectory[dir];
  If[$KernelCount =!= 0,
  ParallelEvaluate[SetDirectory[dir], DistributedContexts -> All];
  ];
  Print["Directory[] has been set as: ", dir, "."]
  ]