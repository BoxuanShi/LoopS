ClearAll[MonitorS]
SetAttributes[MonitorS, HoldAll]

MonitorS[expr_, monitor_] := If[
  $FrontEnd === Null,
  expr,
  Monitor[expr, monitor]
]
