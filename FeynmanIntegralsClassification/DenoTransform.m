ClearAll[FADToProps];
FADToProps[expr_, head_ : List] := Module[{x, head2, SFADToProps, pFADToProps},
  SFADToProps[sfad_SFAD] := Module[{i, tpt1, tpt2, trans},
  trans = ConstantArray[(#[[1, 1]]^2 + (#[[1, 2]] /. Dot -> Times) - #[[2, 1]]) ^ Sign[#[[3]]], Abs@#[[3]]] &;
  tpt1 = trans /@ (List @@ sfad);
  tpt2 = head2 @@ Flatten@tpt1];
  pFADToProps[fad_FAD] := fad // ToSFAD // FCES // SFADToProps;
  FCES @ expr /. {SFAD[x___] :> SFADToProps@SFAD[x], FAD[x___] :> pFADToProps@FAD[x]} /. head2 -> head
]


ClearAll[PropsToFAD]
PropsToFAD[props_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, PropsToFAD[props, p["loopmoms"], p["kinematics"]]]
PropsToFAD[props_List, loopmoms_List, kinematics_List] := Module[{LS, fadlist}, 
  LS = props // propsToLS[#, loopmoms, kinematics] &;
  If[! FreeQ[LS, "Wrong propagator"], Return[$Failed]];
  fadlist = (If[#[[1]] === #[[2]], FAD[{#[[1]], (-#[[3]])^(1/2), #[[4]]}], SFAD[{{0, Dot[#[[1]]] . #[[2]]}, {-#[[3]], 1}, #[[4]]}]] &) /@ LS;
  Times @@ fadlist]


ClearAll[LSToFAD]
LSToFAD[propsLS_List] := Module[{fadlist},
  fadlist = (If[#[[1]] === #[[2]], 
    FAD[{#[[1]], (-#[[3]])^(1/2), #[[4]]}], 
    SFAD[{{0, Dot[#[[1]]] . #[[2]]}, {-#[[3]], 1}, #[[4]]}]
    ] &) /@ propsLS;
  Times @@ fadlist]
  
  
ClearAll[GToProps]
GToProps[expr_, familylist_List, head_ : List] := Module[{i}, 
  expr /. G[a_, b_, c___] :> head @@ Flatten @ Table[ConstantArray[familylist[[a, i]] ^ Sign[b[[i]]], Abs @ b[[i]]], {i, Length @ b}]]


ClearAll[PropsToSPD]
PropsToSPD[expr_, head : Except[_Association] : SPD, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, PropsToSPD[expr, head, p["moms"]]]
PropsToSPD[expr_, head_ : SPD, moms_List] := Module[{tp1},
  If[Head @ moms =!= List, Print["Define moms firstly."]; Abort[]];
  tp1 = ExpandNumerator @ ExpandDenominator @ expr;
  tp1 //. Dispatch @ {
    a_ * b_ /; SubsetQ[moms, {a, b}] :> SPD[a, b], 
    a_^2 /; SubsetQ[moms, {a, a}] :> SPD[a, a], 
    (a_*b_)^-1 /; SubsetQ[moms, {a, b}] :> SPD[a, b]^-1, 
    a_^-2 /; SubsetQ[moms, {a, a}] :> SPD[a, a]^-1
    } /. SPD -> head
  ]


ClearAll[PropsToM]
PropsToM[props_, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, PropsToM[props, loops, p["extmomsind"], p["kinematics"]]]
PropsToM[props_List, loops_List, extmomsind_List, kinematics_List] := PropsToM[#, loops, extmomsind, kinematics] & /@ props
PropsToM[props_, loops_List, extmomsind_List, kinematics_List] := Module[{tp1},
  tp1 = CoefficientS[props, spdlist[loops, Times, extmomsind]];
  tp1 // TogetherExpand // # /. kinematics &]


ClearAll[LinearPropsExistQ, linearPropsQ]
LinearPropsExistQ[props_, loops_List] := !FreeQ[linearPropsQ[props, loops], True]
linearPropsQ[props_List, loops_List] := linearPropsQ[#, loops] & /@ props
linearPropsQ[props_, loops_List] := Module[{tp1},
  tp1 = Max @ Exponent[props, loops];
  Which[tp1 === 2, False, tp1 === 1, True, True, Print["linearPropsQ: False props form."]; Abort[]]
  ]


ClearAll[spdlist]
spdlist[loops_List, head : Except[_String] : SPD, process_String : "CurrentProcess"] := spdlist[loops, head, ToExpression[process]]
spdlist[loops_List, head_ : SPD, process_Association] := spdlist[loops, head, process["extmomsind"]]
spdlist[loops_List, head_ : SPD, extmomsind_List] := spdlist[loops, head, extmomsind] = Module[{tp1, momss, condi},
   momss = Join[loops, extmomsind];
   tp1 = FactorTermsList[#][[2]] & /@ (ListS@Expand[(Plus @@ momss)^2]) // Select[#, ! FreeQ[#, Alternatives @@ loops] &] &;
   condi = {! FreeQ[#, Alternatives @@ extmomsind], -Exponent[#, momss]} &;
   tp1 = tp1 // SortBy[#, condi] &;
   tp1 /. Dispatch @ {a_*b_ :> head[a, b], a_^2 :> head[a, a]}]


ClearAll[IndependentArray, CompleteProps]
IndependentArray[matrix_List] := Module[{tp1},
  If[matrix === {}, Return[{}]];
  tp1 = RowReduce[Transpose[matrix]];
  tp1 = Select[tp1, ! AllTrue[#, # === 0 &] &];
  Flatten[FirstPosition[#, 1] & /@ tp1]
  ]


ClearAll[CompleteProps]
Options[CompleteProps] = {"CompleteBasis" -> Automatic};
CompleteProps[props_List, loops_List, process : Except[_Rule|_RuleDelayed, _String] : "CurrentProcess", opt : OptionsPattern[]] := CompleteProps[props, loops, ToExpression[process], opt]
CompleteProps[props_List, loops_List, process_Association, opt : OptionsPattern[]] := CompleteProps[props, loops, process["extmomsind"], opt]
CompleteProps[props_List, loops_List, extmomsind_List, opt : OptionsPattern[]] := 
 Module[{spd, prop, tp1, tp2},
  spd = spdlist[loops, Times, extmomsind];
  prop = If[OptionValue["CompleteBasis"] === Automatic, spd /. a_*b_ :> (a + b)^2, OptionValue["CompleteBasis"]];
  tp1 = props ~ Join ~ prop;
  tp2 = (Coefficient[#, spd] &) /@ tp1;
  tp1[[IndependentArray @ tp2]]
  ]