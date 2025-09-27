ClearAll[AbbreviateOperators];
Options[AbbreviateOperators] = {"AbbreviateOperatorsName" -> OPs, "AbbreviateOperatorsHead" -> (#&)};
AbbreviateOperators[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 AbbreviatePolynomials[expr, OperatorPattern, "AbbreviatePolynomialsName" -> OptionValue["AbbreviateOperatorsName"], "AbbreviatePolynomialsHead" -> OptionValue["AbbreviateOperatorsHead"]]