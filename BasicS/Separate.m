ClearAll[Separate, Separate0, Separate1, SeparatePoly, SeparatePoly0];
SeparateHead;
SeparateDropOne;
Separate::usage = 
  "1. Separate[expr, patt] separate polynomials consitituted by patt.
2. Option SeparateHead replace the default head List.
3. Separate has attribute Listable for the first argument.";

Options[Separate] := CreateOptions[{}, {Separate1}];
Separate[expr_, patt_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Separate0[expr, "patt" -> patt, 
  Evaluate@FilterOptions[{opt}, Separate1]]
Options[Separate0] := CreateOptions[{"patt" -> "patt"}, {Separate1}]
SetAttributes[Separate0, Listable];
Separate0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Separate1[expr, OptionValue["patt"], 
  Evaluate@FilterOptions[{opt}, Separate1]]

Options[Separate1] := CreateOptions[{}, {SeparatePoly}];
Separate1[expr_, patt_, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{vars}, vars = getS[{expr}, patt];
  SeparatePoly[expr, vars, 
   Evaluate@FilterOptions[{opt}, SeparatePoly]]]

Separate1[expr_, patt0_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{coe, patt},
  {coe, patt} = Separate[expr, Alternatives @@ patt0];
  patt = (ListS[#, {}, Times] &) /@ patt;
  patt = (Table[
       Select[#, MatchQ[# /. a_^b_ :> a, patt0[[i]]] &], {i, 
        Length@patt0}] &) /@ patt;
  patt = (Times @@@ # &) /@ patt;
  patt = Transpose@patt;
  OptionValue["SeparateHead"] @@ {coe, Sequence @@ patt}]

Options[SeparatePoly] = {"SeparateHead" -> List, 
   "SeparateDropOne" -> False};
SeparatePoly[expr_, vars_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := SeparatePoly0[expr, "vars" -> vars, Evaluate@opt]

Options[SeparatePoly0] := 
  CreateOptions[{"vars" -> "vars"}, {SeparatePoly}];
SetAttributes[SeparatePoly0, Listable];
SeparatePoly0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{vars, sa, ar, ltop, tp1},
  vars = OptionValue["vars"];
  If[expr === 0, Return[OptionValue["SeparateHead"] @@ {{}, {}}]];
  If[vars === {}, 
    If[OptionValue["SeparateDropOne"], 
     Return[OptionValue["SeparateHead"] @@ {{}, {}}],
     Return[OptionValue["SeparateHead"] @@ {{expr}, {1}}]]
  ];
  sa = CoefficientArrays[expr, vars];
  ar = (ArrayRules /@ sa[[2 ;; -1]])[[All, 1 ;; -2]] // Flatten;
  ltop[list_] := Times @@ (vars[[#]] & /@ list);
  tp1 = ar /. (x_ -> y_) :> {y, ltop[x]};
  tp1 = SortBy[tp1, Last];
  If[sa[[1]] =!= 0 && ! OptionValue["SeparateDropOne"], 
   PrependTo[tp1, {sa[[1]], 1}], Nothing];
  OptionValue["SeparateHead"] @@ Transpose[tp1]]