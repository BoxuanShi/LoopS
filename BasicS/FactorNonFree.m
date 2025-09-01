ClearAll[FactorNonFree, FactorNonFree0]
FactorNonFree[expr_, vars_] := FactorNonFree0[expr, "vars" -> vars]
Options[FactorNonFree0] = {"vars" -> "vars"};
SetAttributes[FactorNonFree0, Listable];
FactorNonFree0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, tp2, vars, patt},
  vars = OptionValue["vars"];
  patt = Alternatives @@ Flatten@{vars};
  If[FreeQ[expr, patt], Return[1]];
  tp1 = expr // FactorList;
  tp2 = tp1 // GatherBy[#, ! FreeQ[#, patt] &] &;
  tp2 = tp2 // SortBy[#, ! FreeQ[#[[1]], patt] &] &;
  tp2 = tp2[[2]];
  FactorListRev@tp2
  ]