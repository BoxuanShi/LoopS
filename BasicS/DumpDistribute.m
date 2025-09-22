ClearAll[DumpDistribute];
SetAttributes[DumpDistribute, {HoldAll, Listable}];
DumpDistribute[vars_] := Module[{dumpsavevars, str},
  str = ToString[dumpsavevars] <> ".mx";
  DumpSave[str, vars];
  ParallelEvaluate[Get[str]];
  DeleteFile[str];
  ]
DumpDistribute[vars__] := DumpDistribute[{vars}]