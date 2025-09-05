AbbreviateVariables;

ClearAll[AbbreviateVariables];
Protect[AbbrV];
Options[AbbreviateVariables] = {"AbbreviateVariablesName" -> AbbrD};
AbbreviateVariables[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, vs, ns, vs2, rule, name},

  name = OptionValue["AbbreviateVariablesName"];
  vs = Variables[expr];
  ns = Length @ vs;
  vs2 = Array[name, ns];
  
  rule = Thread[(Verbatim /@ vs) -> vs2];
  
  {expr /. rule, Reverse /@ rule /. Verbatim -> Identity}
  ]