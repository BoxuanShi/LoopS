ClearAll[Separate, SeparatePoly];
Separate::usage = "1. Separate[expr, patt] separate polynomials consitituted by patt.
2. Option SeparateHead replace the default head List.
3. Separate has attribute Listable for the first argument.";

Options[Separate] := CreateOptions[{"SeparatePattMatch" -> getS}, {SeparatePoly}];
Separate[expr_List, patt_, opt : OptionsPattern[]] := Separate[#, patt, opt] & /@ expr;
Separate[expr : Except[_List], patt_List, opt : OptionsPattern[]] := Module[{coe, patt2},
  {coe, patt2} = Separate[expr, Alternatives @@ patt];
  patt2 = (ListS[#, {}, Times] &) /@ patt2;
  patt2 = (Table[Select[#, MatchQ[# /. a_^b_ :> a, patt[[i]]] &], {i, Length @ patt}] &) /@ patt2;
  patt2 = (Times @@@ # &) /@ patt2;
  patt2 = Transpose @ patt2;
  OptionValue["SeparateHead"] @@ {coe, Sequence @@ patt2}]
Separate[expr : Except[_List], patt : Except[_List], opt : OptionsPattern[]] := Module[{vars}, 
  vars = OptionValue["SeparatePattMatch"][{expr}, patt];
  SeparatePoly[expr, vars, Evaluate @ FilterOptions[{opt}, SeparatePoly]]]

SeparatePoly::poly = "SeparatePoly: non polynomial expression `1`. `2` are not separated.";
Options[SeparatePoly] = {"SeparateHead" -> List, "SeparateOperation" -> Times};
SeparatePoly[expr_List, vars_List, opt : OptionsPattern[]] := SeparatePoly[#, vars, opt] & /@ expr;
SeparatePoly[expr_, vars_List, opt : OptionsPattern[]] := Module[{sa, ar, ltop, tp1, opr, plq},
  opr = OptionValue["SeparateOperation"];
  If[expr === 0, Return[OptionValue["SeparateHead"] @@ {{}, {}}]];
  (* If[vars === {} || (plq = !PolynomialQ[expr, vars]), 
    If[plq, Message[SeparatePoly::poly, expr, vars]];
    Return[OptionValue["SeparateHead"] @@ {{expr}, {1}}]
  ]; *)
  If[vars === {}, Return[OptionValue["SeparateHead"] @@ {{expr}, {1}}]];

  If[Length@vars <= 5,
    sa = Check[CoefficientList[expr, vars], Abort[], {CoefficientList::poly}];
    ar = ArrayRules[sa][[1 ;; -2]];
    ltop[list_] := opr @@ (vars ^ (list-1));
    tp1 = ar /. (x_ -> y_) :> {y, ltop[x]};
    tp1 = SortBy[tp1, {#[[2]] =!= 1 &, Last}];
    OptionValue["SeparateHead"] @@ Transpose[tp1]
    ,
    sa = Check[CoefficientArrays[expr, vars], Abort[], {CoefficientArrays::poly, CoefficientArrays::ivar}];
    ar = (ArrayRules /@ sa[[2 ;; -1]])[[All, 1 ;; -2]] // Flatten;
    ltop[list_] := opr @@ (vars[[#]] & /@ list);
    tp1 = ar /. (x_ -> y_) :> {y, ltop[x]};
    tp1 = SortBy[tp1, Last];
    If[sa[[1]] =!= 0, PrependTo[tp1, {sa[[1]], opr @@ {1}}], Nothing];
    OptionValue["SeparateHead"] @@ Transpose[tp1]
  ]
]