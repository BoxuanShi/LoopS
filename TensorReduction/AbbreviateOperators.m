ClearAll[AbbreviateOperators, AbbreviateOperators2];
Options[AbbreviateOperators] = {"AbbreviateOperatorsName" -> OPs, "AbbreviateOperatorsHead" -> (#&)};
AbbreviateOperators[expr_, opt : OptionsPattern[]] := Module[{tp1, res},
    tp1 = OperatorCollect[expr];
    res = expr /. Dispatch @ Thread[tp1 -> Array[OptionValue["AbbreviateOperatorsName"], Length @ tp1]];
    If[OperatorCollect[res] =!= {}, Print["AbbreviateOperators Failed!"]];
    {res, Thread[Array[OptionValue["AbbreviateOperatorsName"], Length @ tp1] -> (OptionValue["AbbreviateOperatorsHead"] /@ tp1)]}
    ]

AbbreviateOperators2[expr_, opt : OptionsPattern[]] := AbbreviatePolynomials[expr, OperatorPattern, "AbbreviatePolynomialsName" -> OptionValue["AbbreviateOperatorsName"], "AbbreviatePolynomialsHead" -> OptionValue["AbbreviateOperatorsHead"]]