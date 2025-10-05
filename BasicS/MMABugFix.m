(*no clear here*)
Off[Solve::svars];


Options[FullSimplifyS] := CreateOptions[{}, {FullSimplify}]
FullSimplifyS[expr_, opt : OptionsPattern[], asm_ : $Assumptions] /; 
  OptRestrict[opt] := Module[{},
  ClearSystemCache[];
  FullSimplify[expr, asm, opt]
  ]

(*just fix a bug for some high numeric accuracy cases..., also SameTest is \
not an option*)

ClearAll[UnionS]
UnionS[list_List, list2__List] := Union[list, list2]
UnionS[list_List, test_ : SameQ] := 
 list // DeleteDuplicates[#, test] & // Sort

 
ClearAll[FactorAll];
FactorAll[expr_] := MapAll[Factor, expr]