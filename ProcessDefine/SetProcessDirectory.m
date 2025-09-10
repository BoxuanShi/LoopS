ClearAll[SetProcessDirectory]
SetProcessDirectory[] := Module[{dir},
  dir = ProcessPath@ProcessName;
  SetDirectory[dir];
  Print["Directory[] has been set as: ", dir, "."]
  ]