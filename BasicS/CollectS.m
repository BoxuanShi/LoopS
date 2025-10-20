ClearAll[CollectS]
CollectS[expr_List, patt_, func1_ : (# &), func2_ : (# &)] := CollectS[#, patt, func1, func2] & /@ expr
CollectS[expr_, patt_, func1_ : (# &), func2_ : (# &)] := Module[{a, b},
  {a, b} = Separate[expr, patt];
  a = func1 /@ a;
  b = func2 /@ b;
  a . b]