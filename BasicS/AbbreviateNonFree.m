ClearAll[AbbreviateNonFree];
AbbreviateNonFree::usage = 
  "1. AbbreviateNonFree[expr, vars] can abbreviate factors non-free \
of vars.
2. Option \"AbbreviateNonFreeName\" can replace the default name \
AbbrNF.";
{AbbreviateNonFreeName, AbbrNF};
Options[AbbreviateNonFree] = {"AbbreviateNonFreeName" -> AbbrNF};
AbbreviateNonFree[expr_, vars_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{tp1, tp2, head2, factors, name, rules},
  tp1 = expr // FactorNonFree[#, vars, "FactorNonFreeHead" -> head2] &;
  
  factors = Union@Flatten[{tp1}][[All, 1]];
  factors = factors // DeleteCases[#, 1] &;
  factors = Verbatim /@ factors;
  
  name = OptionValue["AbbreviateNonFreeName"];
  rules = Thread[factors -> Array[name, Length@factors]];
  tp2 = tp1 /. Dispatch@rules;
  tp2 = tp2 /. head2 -> Times;
  rules = Reverse /@ rules /. Verbatim -> (# &) /. head2 -> Times;
  
  {tp2, rules}]


ClearAll[FactorNonFree, FactorNonFree0];
FactorNonFree::usage = 
  "1. FactorNonFree[expr, vars] can factor the term non-free of vars. \

2. Option \"FactorNonFreeHead\" can replace the default head List.
3. FactorNonFree has attribute Listable on the first argument.";
FactorNonFreeHead;
Options[FactorNonFree] = {"FactorNonFreeHead" -> List};
FactorNonFree[expr_, vars_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FactorNonFree0[expr, "vars" -> vars, 
  "head" -> OptionValue["FactorNonFreeHead"]]
Options[FactorNonFree0] = {"vars" -> "vars", "head" -> "head"};
SetAttributes[FactorNonFree0, Listable];
FactorNonFree0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, tp2, vars, head, patt},
  vars = OptionValue["vars"];
  patt = Alternatives @@ Flatten@{vars};
  If[FreeQ[expr, patt], Return[OptionValue["head"][1, expr]]];
  tp1 = expr // FactorList;
  tp2 = tp1 // GatherBy[#, ! FreeQ[#, patt] &] &;
  tp2 = tp2 // SortBy[#, ! FreeQ[#[[1]], patt] &] &;
  tp2 = Reverse@tp2;
  tp2 = FactorListRev /@ tp2;
  OptionValue["head"] @@ tp2]
