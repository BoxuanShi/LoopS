DenoTransform;

(*FADToProps[FAD[l1,l1+p,{l1+nb,m,1}]]==={l1^2,(l1+p)^2,-m^2+(l1+nb)^2}
FADToProps[FAD[l1,l1+p,{l1+nb,m,1}]]==={l1^2,(l1+p)^2,-m^2+(l1+nb)^2}*)

ClearAll[FADToProps];
FADToProps[expr_, head_ : List] := 
 Module[{x, head2, tp1, tp2, SFADToProps, pFADToProps},
  
  SFADToProps[sfad_SFAD] := Module[{i, tpt1, tpt2, trans},
    trans = 
     ConstantArray[(#[[1, 1]]^2 + (#[[1, 2]] /. Dot -> Times) - #[[2, 1]])^
       Sign[#[[3]]], Abs@#[[3]]] &;
    tpt1 = trans /@ (List @@ sfad);
    (*tpt1=Table[ConstantArray[(sfad[[i,1,1]]^2+(sfad[[i,1,2]]/.Dot->Times)-
    sfad[[i,2,1]])^Sign[sfad[[i,3]]],Abs@sfad[[i,3]]],{i,Length@sfad}];*)
    tpt2 = head2 @@ Flatten@tpt1];
  
  pFADToProps[fad_FAD] := fad // ToSFAD // FCES // SFADToProps;
  FCES@expr /. {SFAD[x___] :> SFADToProps@SFAD[x], 
     FAD[x___] :> pFADToProps@FAD[x]} /. head2 -> head]


ClearAll[PropsToFAD]
PropsToFAD[props_List, loops_List, process_String : "CurrentProcess"] := 
 PropsToFAD[props, loops, ToExpression[process]]
PropsToFAD[props_List, loops_List, process_Association] := 
 PropsToFAD[props, loops, process["kinematics"]]
PropsToFAD[props_List, loops_List, kinematics_List] := Module[{LS, fadlist},
  LS = props // propsToLS[#, loops, kinematics] &;
  If[! FreeQ[LS, "Wrong propagator"], Return[$Failed]];
  fadlist = (If[#[[1]] === #[[2]],
       FAD[{#[[1]], (-#[[3]])^(1/2), #[[4]]}],
       SFAD[{{0, Dot[#[[1]]] . #[[2]]}, {-#[[3]], 1}, #[[4]]}]] &) /@ LS;
  Times @@ fadlist
  ]


ClearAll[GToProps]
GToProps[expr_, familylist_, head_ : List] := 
 Module[{i}, 
  expr /. G[a_, b_, c___] :> 
    head @@ Flatten@
      Table[ConstantArray[familylist[[a, i]]^Sign[b[[i]]], Abs@b[[i]]], {i, 
        Length@b}]]


ClearAll[PropsToSPD]
PropsToSPD[expr_, head_ : SPD, process_String : "CurrentProcess"] := 
 PropsToSPD[expr, head, ToExpression[process]]
PropsToSPD[expr_, head_ : SPD, process_Association] := 
 PropsToSPD[expr, head, process["moms"]]
PropsToSPD[expr_, head_ : SPD, moms_List] := Module[{tp1},
  If[Head@moms =!= List, Print["Define moms firstly."]; Abort[]];
  tp1 = ExpandNumerator@ExpandDenominator@expr;
  tp1 //. 
    Dispatch@{a_*b_ /; SubsetQ[moms, {a, b}] :> SPD[a, b], 
      a_^2 /; SubsetQ[moms, {a, a}] :> 
       SPD[a, a], (a_*b_)^-1 /; SubsetQ[moms, {a, b}] :> SPD[a, b]^-1, 
      a_^-2 /; SubsetQ[moms, {a, a}] :> SPD[a, a]^-1} /. SPD -> head]


ClearAll[PropsToM, PropsToM0]
SetAttributes[PropsToM0, Listable]
PropsToM[props_, loops_List, process_String : "CurrentProcess"] := 
 PropsToM[props, loops, ToExpression[process]]
PropsToM[props_, loops_List, process_Association] := 
 PropsToM[props, loops, process["extmomsind"], process["kinematics"]]
PropsToM[props_, loops_List, extmomsind_List, kinematics_List] := 
 PropsToM0[props, "loops" -> loops, "extmomsind" -> extmomsind, 
  "kinematics" -> kinematics]
Options[PropsToM0] = {"loops" -> "loops", "kinematics" -> "kinematics", 
   "extmomsind" -> "extmomsind"};
PropsToM0[props_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1},
  tp1 = CoefficientS[props, 
    spdlist[OptionValue["loops"], Times, OptionValue["extmomsind"]]];
  tp1 // Together // Expand // # /. OptionValue["kinematics"] &]


ClearAll[linearPropsQ, linearPropsQ0]
linearPropsQ[props_, loops_List] := linearPropsQ0[props, "loops" -> loops]
Options[linearPropsQ0] = {"loops" -> "loops"};
linearPropsQ0[props_, opt : OptionsPattern[]] := Module[{tp1, loops},
  loops = OptionValue["loops"];
  tp1 = Max@Exponent[props, loops]; 
  Which[tp1 === 2, False, tp1 === 1, True, True, Print["False props form."]; 
   Abort[]]]
SetAttributes[linearPropsQ0, Listable]


ClearAll[spdlist]
spdlist::usage = 
  "spdlist[loops_List,head_:SPD,extmomsind_List] gives the complete SPD \
basis.";
spdlist[loops_List, head_ : SPD, process_String : "CurrentProcess"] := 
 spdlist[loops, head, ToExpression[process]]
spdlist[loops_List, head_ : SPD, process_Association] := 
 spdlist[loops, head, process["extmomsind"]]
spdlist[loops_List, head_ : SPD, extmomsind_List] := 
 spdlist[loops, head, extmomsind] = Module[{tp1, momss, condi},
   momss = Join[loops, extmomsind];
   tp1 = FactorTermsList[#][[2]] & /@ (ListS@Expand[(Plus @@ momss)^2]) // 
     Select[#, ! FreeQ[#, Alternatives @@ loops] &] &;
   condi = {! FreeQ[#, Alternatives @@ extmomsind], -Exponent[#, momss]} &;
   tp1 = tp1 // SortBy[#, condi] &;
   tp1 /. Dispatch@{a_*b_ :> head[a, b], a_^2 :> head[a, a]}
   ]


ClearAll[IndependentArray, CompleteProps]
IndependentArray[matrix_List] := Module[{tp1},
  If[matrix === {}, Return[{}]];
  tp1 = RowReduce[Transpose[matrix]];
  tp1 = Select[tp1, ! AllTrue[#, # === 0 &] &];
  Flatten[FirstPosition[#, 1] & /@ tp1]
  ]

Options[CompleteProps] = {"CompleteBasis" -> Automatic};
CompleteProps[props_List, loops_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 CompleteProps[props, loops, ToExpression[process], opt]
CompleteProps[props_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 CompleteProps[props, loops, process["extmomsind"], opt]
CompleteProps[props_List, loops_List, extmomsind_List, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{spd, prop, indpos, tp1, tp2},
  spd = spdlist[loops, Times, extmomsind];
  prop = If[
    OptionValue["CompleteBasis"] === Automatic,
    spd /. a_*b_ :> (a + b)^2,
    OptionValue["CompleteBasis"]
    ];
  tp1 = props~Join~prop;
  tp2 = (Coefficient[#, spd] &) /@ tp1;
  tp1[[IndependentArray@tp2]]]