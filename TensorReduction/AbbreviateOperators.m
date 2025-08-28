AbbreviateOperators;

ClearAll[AbbreviateOperators];
Options[AbbreviateOperators] := CreateOptions[{}, {AbbreviatePolynomials}]
AbbreviateOperators[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 AbbreviatePolynomials[expr, OperatorPattern, Evaluate@opt, 
  "AbbreviatePolynomialsName" -> OPs]