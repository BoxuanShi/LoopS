ClearAll[AbbreviatePolynomials];
Protect[AbbrP];
Options[AbbreviatePolynomials] := 
  CreateOptions[{"AbbreviatePolynomialsName" -> AbbrP, 
    "AbbreviatePolynomialsHead" -> (# &)}, {}];

AbbreviatePolynomials[expr0_List, patt_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{expr, expr2, Op, rules, rulesInv, OpName, times, dot, hd},
  expr = CollectS[expr0, patt, # &, hd];
  Op = expr // getS[#, _hd] &;
  OpName = Array[OptionValue["AbbreviatePolynomialsName"], Length@Op];
  rules = Thread[Op -> OpName];
  expr2 = expr /. Dispatch@rules;
  rulesInv = 
   Thread[OpName -> (Op /. hd -> OptionValue["AbbreviatePolynomialsHead"])];
  {expr2, rulesInv}
  ]

AbbreviatePolynomials[expr_, patt_, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{Coe, Op, rules, OpName, nQ},
  {Coe, Op} = Separate[expr, patt];
  nQ = (Coe =!= {} && Op[[1]] === 1);
  
  Op = (OptionValue["AbbreviatePolynomialsHead"] /@ Op) /. 
    OptionValue["AbbreviatePolynomialsHead"][1] -> 1;
  rules = If[nQ, Op[[2 ;; -1]], Op];
  OpName = Array[OptionValue["AbbreviatePolynomialsName"], Length@rules];
  rules = Thread[rules -> OpName];
  Op = If[nQ, Join[{1}, OpName], OpName];
  {Coe . Op, Reverse /@ rules}
  ]