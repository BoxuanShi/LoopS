ClearAll[ProcessPath, PVPath, FIREWorkPath, LoopSWorkDirectory, OPITeRWorkPath]
LoopSWorkDirectory := 
  LoopSWorkDirectory = 
   PathName@FileNameJoin[{ExpandFileName[NotebookDirectoryS[]], "LoopSFile","Processes"}];

ProcessPath[process_String] := FileNameJoin[{LoopSWorkDirectory, process}]

PVPath[process_String] := FileNameJoin[{ProcessPath[process], "PV"}]

FIREWorkPath[process_String] := FileNameJoin[{ProcessPath[process], "FIRE"}];
FIREFamilyName[loops_List] := Module[{str},
  str = StringJoin @@ Table["N", {i, Length@loops}];
  "family" <> str <> "LO"]

OPITeRWorkPath := 
 FileNameJoin[{ParentDirectory@LoopSWorkDirectory, "tempopiter"}]
