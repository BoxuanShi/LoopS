CollectS;

ClearAll[CollectS, CollectS0]
CollectS[expr_, form_, func1_ : (# &), func2_ : (# &)] /; 
  SubsetQ[{Function, Symbol}, Flatten@{Head@func1, Head@func2}] := 
 CollectS0[expr, "form" -> form, "func1" -> func1, "func2" -> func2]

Options[CollectS0] := 
  CreateOptions[{"form" -> "form", "func1" -> (# &), "func2" -> (# &)}, {}];
CollectS0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{a, b, form, func1, func2},
  
  form = OptionValue["form"];
  func1 = OptionValue["func1"];
  func2 = OptionValue["func2"];
  
  {a, b} = Separate[expr, Alternatives @@ Flatten@{form}];
  a = func1 /@ a;
  b = func2 /@ b;
  a . b
  
  ]

SetAttributes[CollectS0, Listable]