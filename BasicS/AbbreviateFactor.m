ClearAll[AbbreviateFactor];
AbbreviateFactor::usage = "1. AbbreviateFactor[expr, condi] can abbreviate factors satisfy the condi. 
2. Option \"AbbreviateFactorName\" can replace the default name AbbrF.";
Options[AbbreviateFactor] = {"AbbreviateFactorName" -> AbbrF};
AbbreviateFactor[expr_, condi_, opt : OptionsPattern[]] := Module[{tp1, tp2, head2, factors, name, rules, rulesdis},
  tp1 = expr // FactorCondition[#, condi, "FactorConditionHead" -> head2] &;
  factors = Union @ Flatten[{tp1}][[All, 1]];
  factors = factors // DeleteCases[#, 1] &;
  (* factors = Verbatim /@ factors; *)
  name = OptionValue["AbbreviateFactorName"];
  rules = Thread[factors -> Array[name, Length @ factors]];
  rulesdis = Dispatch@rules;
  tp2 = tp1 /. head2[x_, y_] :> Replace[x, rulesdis] * y;
  rules = Reverse /@ rules (*/. head2 -> Times*);
  {tp2, rules}]


ClearAll[FactorCondition];
FactorCondition::input = "Unexpected condition.";
Options[FactorCondition] = {"FactorConditionHead" -> List};
FactorCondition[expr_List, condi_, opt : OptionsPattern[]] := FactorCondition[#, condi, opt] & /@ expr;
FactorCondition[expr_, condi_, opt : OptionsPattern[]] := Module[{tp1, tp2},
  tp1 = expr // FactorList;
  tp2 = tp1 // GroupBy[#, condi[#[[1]]] &] &;
  If[! SubsetQ[{True, False}, Union @ Keys @ tp2], Message[FactorCondition::input]; Return[OptionValue["FactorConditionHead"][1, expr]]];
  tp2 = {tp2[True], tp2[False]} /. Missing["KeyAbsent", _] -> {};
  tp2 = FactorListRev /@ tp2;
  OptionValue["FactorConditionHead"] @@ tp2]