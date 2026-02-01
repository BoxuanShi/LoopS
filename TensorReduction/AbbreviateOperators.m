ClearAll[AbbreviateOperators, AbbreviateOperators2];
Options[AbbreviateOperators] = {"AbbreviateOperatorsName" -> OPs, "AbbreviateOperatorsHead" -> (#&)};
AbbreviateOperators[expr_, opt : OptionsPattern[]] := Module[{tp1, rules, res},
    tp1 = OperatorCollect[expr];
    rules = Thread[tp1 -> Array[OptionValue["AbbreviateOperatorsName"], Length @ tp1]];
    rules = Reverse@SortBy[rules, LeafCount@First@# &];
    res = expr /. Dispatch@rules;
    If[OperatorCollect[res] =!= {}, Print["AbbreviateOperators Failed!"]];
    {res, Thread[Array[OptionValue["AbbreviateOperatorsName"], Length @ tp1] -> (OptionValue["AbbreviateOperatorsHead"] /@ tp1)]}
]

Options[AbbreviateOperators2] := CreateOptions[{}, {AbbreviateOperators}];
AbbreviateOperators2[expr_, opt : OptionsPattern[]] := AbbreviatePolynomials[expr, OperatorPattern, "AbbreviatePolynomialsName" -> OptionValue["AbbreviateOperatorsName"], "AbbreviatePolynomialsHead" -> OptionValue["AbbreviateOperatorsHead"]]