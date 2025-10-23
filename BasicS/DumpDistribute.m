ClearAll[DumpDistribute];

SetAttributes[DumpDistribute, {HoldAll, Listable}];

DumpDistribute[vars_] := 
 Module[{dumpsavevars, str}, str = ToString[dumpsavevars] <> ".mx";
  DumpSave[str, vars];
  DistributeDefinitions[str];
  ParallelEvaluateS[ClearAll[vars]; Get[str]; Hold[vars];, DistributedContexts -> None];
  DeleteFile[str];]

DumpDistribute[vars___] := DumpDistribute[{vars}]