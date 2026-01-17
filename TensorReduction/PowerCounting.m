ClearAll[PowerCounting, PowerCounting0, LeadingPower, LeadingPower0];
Options[PowerCounting] = {"PowerCountingPrintLeadingPower" -> False};
PowerCounting[expr_, ord_, process_String : "CurrentProcess", opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCounting[expr, ord, ToExpression[process], opt]
PowerCounting[expr_, ord_, process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCounting[expr, ord, process["loopmoms"], process["moms"], process["kinematics"], opt]
PowerCounting[expr_, ord_, loopmoms_List, moms_List, kinematics_List | kinematics_Dispatch, opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCounting0[expr, "ord" -> ord, "loopmoms" -> loopmoms, "moms" -> moms, "kinematics" -> kinematics, opt]

Options[PowerCounting0] := CreateOptions[{"ord" -> "ord", "loopmoms" -> "loopmoms", "moms" -> "moms", "kinematics" -> "kinematics"}, {PowerCounting}];
SetAttributes[PowerCounting0, Listable];

PowerCounting0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{powerfunc, tp1, ord, loopmoms, moms, kinematics, max}, {ord, loopmoms, moms, kinematics} = {OptionValue["ord"], OptionValue["loopmoms"], OptionValue["moms"], OptionValue["kinematics"]};
  If[Length@ord === 3 && ord[[2]] =!= 0, Print["PowerCounting: only support expansion around 0."]];
  If[Length@ord === 2, ord = Insert[ord, 0, {2}]];
  tp1 = expr // FeynAmpDenominatorExplicit // ExpandMomentum[#, moms] & // ExpandDirac;
  powerfunc = If[MatchQ[ord, {__, "Leading"}], 
    max = tp1 // Together // Exponent[#, ord[[1]], Min] &;
    max = If[NumberQ[max], max, 0];
    If[OptionValue["PowerCountingPrintLeadingPower"], Print["The leading power is ", ord[[1]], "^", max]];
    Normal[SeriesS[#, ReplacePart[ord, 3 -> max]]] &
    ,
    Normal[SeriesS[#, ord]] &
  ];
  tp1 // CollectS[#, DiracPattern| _FVD| _MTD, powerfunc] & // SPDToFAD[#, loopmoms, kinematics] &
]


ClearAll[PowerCountingNumerator]
Options[PowerCountingNumerator] = {"PowerCountingNumeratorPrintLeadingPower" -> False, "UseSeriesCoefficient" -> False};
PowerCountingNumerator[expr_, ord_, process_String : "CurrentProcess", opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCountingNumerator[expr, ord, ToExpression[process], opt]
PowerCountingNumerator[expr_, ord_, process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCountingNumerator[expr, ord, process["loopmoms"], process["moms"], process["kinematics"], opt]
PowerCountingNumerator[expr_List, ord_, loopmoms_List, moms_List, kinematics_List | kinematics_Dispatch, opt : OptionsPattern[]] /; OptRestrict[opt] := PowerCountingNumerator[#, ord, loopmoms, moms, kinematics, opt] & /@ expr
PowerCountingNumerator[expr_, ord0_, loopmoms_List, moms_List, kinematics_List | kinematics_Dispatch, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{powerfunc, tp1, max, ff, ord = ord0, series}, 
  If[Length@ord === 3 && ord[[2]] =!= 0, Print["PowerCounting: only support expansion around 0."]];
  If[Length@ord === 2, ord = Insert[ord, 0, {2}]];
  tp1 = expr // FeynAmpDenominatorExplicit // ExpandMomentum[#, moms] & // DiracGammaExpand // ExpandScalarProduct // DiracTraceExpand // FCES;
  tp1 = tp1 /. HoldPattern[Dot[x___]] :> Distribute[Dot @@ (Collect[#, ord[[1]], ff] & /@ {x}), Plus, Dot];
  tp1 = tp1 // Separate[#, DiracPattern]&;
  tp1[[2]] = (# /. ff -> Identity /. ord[[1]]^a_. * b_ :> ff[a] * b // ((# /. _ff :> 1) * ord[[1]]^Total[Cases[#, _ff, {0, Infinity}] /. ff[x_] :> x] &))& /@ tp1[[2]];
  tp1 = Dot @@ tp1;
  series = If[OptionValue["UseSeriesCoefficient"], SeriesCoefficient, SeriesS];
  powerfunc = If[MatchQ[ord, {__, "Leading"}], 
    max = tp1 // Together // Exponent[#, ord[[1]], Min] &;
    If[OptionValue["PowerCountingNumeratorPrintLeadingPower"], Print["The leading power is ", ord[[1]], "^", max]];
    Normal[series[#, ReplacePart[ord, 3 -> max]]] * If[OptionValue["UseSeriesCoefficient"], ord[[1]]^ord[[3]], 1] &
    ,
    Normal[series[#, ord]] * If[OptionValue["UseSeriesCoefficient"], ord[[1]]^ord[[3]], 1] &
  ];
  (* tp1 // CollectFlat[#, DiracPattern| _FVD| _MTD, powerfunc] & // SPDToFAD[#, loopmoms, kinematics] & *)
  tp1 // CollectS[#, DiracPattern| _FVD| _MTD, powerfunc] &
]

(* LeadingPower[expr_, para_, process_String : "CurrentProcess"] := 
 LeadingPower[expr, para, ToExpression[process]]
LeadingPower[expr_, para_, process_Association] := 
 LeadingPower[expr, para, process["moms"]]
LeadingPower[expr_, para_, moms_] := 
 LeadingPower0[expr, "para" -> para, "moms" -> moms]
Options[LeadingPower0] = {"para" -> "para", "moms" -> "moms"};
SetAttributes[LeadingPower0, Listable];
LeadingPower0[expr_, opt : OptionsPattern[]] := 
 Module[{para, moms, tp1},
  {para, moms} = {OptionValue["para"], OptionValue["moms"]};
  tp1 = expr // FeynAmpDenominatorExplicit // 
     ExpandMomentum[#, moms] & // ExpandDirac;
  tp1 // Together // Exponent[#, para, Min] &
  ] *)