(*can significantly accelerate Series for the case every term do not need \
limit*)

ClearAll[SeriesS, SeriesS0]
Options[SeriesS] := CreateOptions[{}, {SeriesS0}];
SeriesS[expr_, x_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
  SeriesS0[expr, "SeriesS0xList" -> x, opt];
Options[SeriesS0] := 
  CreateOptions[{"SeriesS0xList" -> "SeriesS0xList"}, {Series}];
SeriesS0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{x, optS},
  x = OptionValue["SeriesS0xList"];
  optS = FilterOptions[{opt}, Series];
  Total@Normal@
    Series[If[FreeQ[#, x[[1]]] && x[[3]] < 0, 0, #] & /@ ListS@expr, x, 
     optS]]
SetAttributes[SeriesS0, Listable]