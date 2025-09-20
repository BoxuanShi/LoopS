ClearAll[FIREEvaluate];
SetAttributes[FIREEvaluate, HoldFirst]
Options[FIREEvaluate] := CreateOptions[{"FIREdReplace" -> D}, {ParallelEvaluateS}]
FIREEvaluate[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 ParallelEvaluateS[expr, 1, Evaluate @ opt] /. d -> OptionValue["FIREdReplace"]