AbbreviateOperators;

ClearAll[AbbreviateOperators];
Options[AbbreviateOperators] := CreateOptions[{"AbbreviatePolynomialsName" -> OPs}, {AbbreviatePolynomials}]
AbbreviateOperators[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 AbbreviatePolynomials[expr, OperatorPattern, Evaluate@opt, 
  "AbbreviatePolynomialsName" -> OptionValue["AbbreviatePolynomialsName"]]