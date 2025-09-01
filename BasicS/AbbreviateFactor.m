ClearAll[AbbreviateFactor];
AbbreviateFactor::usage = 
  "1. AbbreviateFactor[expr, condi] can abbreviate factors satisy the \
condi.
2. Option \"AbbreviateFactorName\" can replace the default name \
AbbrF.";
{AbbreviateFactorName, AbbrF};
Options[AbbreviateFactor] = {"AbbreviateFactorName" -> AbbrF};
AbbreviateFactor[expr_, condi_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{tp1, tp2, head2, factors, name, rules},
  tp1 = expr // 
    FactorCondition[#, condi, "FactorConditionHead" -> head2] &;
  factors = Union@Flatten[{tp1}][[All, 1]];
  factors = factors // DeleteCases[#, 1] &;
  factors = Verbatim /@ factors;
  name = OptionValue["AbbreviateFactorName"];
  rules = Thread[factors -> Array[name, Length@factors]];
  tp2 = tp1 /. Dispatch@rules;
  tp2 = tp2 /. head2 -> Times;
  rules = Reverse /@ rules /. Verbatim -> (# &) /. head2 -> Times;
  {tp2, rules}]


ClearAll[FactorCondition, FactorCondition0];
FactorCondition::usage = 
  "1. FactorNonFree[expr, vars] can factor the term non-free of vars. \

2. Option \"FactorNonFreeHead\" can replace the default head List.
3. FactorNonFree has attribute Listable on the first argument.";
FactorCondition::input = "Unexpected condition.";
FactorConditionHead;
Options[FactorCondition] = {"FactorConditionHead" -> List};
FactorCondition[expr_, condi_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FactorCondition0[expr, "condi" -> condi, 
  "head" -> OptionValue["FactorConditionHead"]]
Options[FactorCondition0] = {"condi" -> "condi", "head" -> "head"};
SetAttributes[FactorCondition0, Listable];
FactorCondition0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{tp1, tp2, condi, head},
  condi = OptionValue["condi"];
  tp1 = expr // FactorList;
  tp2 = tp1 // GroupBy[#, condi[#[[1]]] &] &;
  If[! SubsetQ[{True, False}, Union@Keys@tp2], 
   Message[FactorCondition::input]; 
   Return[OptionValue["head"][1, expr]]];
  tp2 = {tp2[True], tp2[False]} /. Missing["KeyAbsent", _] -> {};
  tp2 = FactorListRev /@ tp2;
  OptionValue["head"] @@ tp2]