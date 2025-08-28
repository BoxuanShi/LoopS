FIREEvaluate;

ClearAll[FIREEvaluate];
SetAttributes[FIREEvaluate, HoldFirst]
Options[FIREEvaluate] := CreateOptions[{}, {ParallelEvaluateS}]
FIREEvaluate[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 ParallelEvaluateS[expr, 1]