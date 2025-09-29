ClearAll[PowerCounting, PowerCounting0, LeadingPower, LeadingPower0];
Options[PowerCounting] = {"PowerCountingPrintLeadingPower" -> False};
PowerCounting[expr_, ord_, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 PowerCounting[expr, ord, ToExpression[process], opt]
PowerCounting[expr_, ord_, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 PowerCounting[expr, ord, process["loopmoms"], process["moms"], 
  process["kinematics"], opt]
PowerCounting[expr_, ord_, loopmoms_List, moms_List, 
   kinematics_List | kinematics_Dispatch, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 PowerCounting0[expr, "ord" -> ord, "loopmoms" -> loopmoms, 
  "moms" -> moms, "kinematics" -> kinematics, opt]

Options[PowerCounting0] := 
  CreateOptions[{"ord" -> "ord", "loopmoms" -> "loopmoms", 
    "moms" -> "moms", 
    "kinematics" -> "kinematics"}, {PowerCounting}];
SetAttributes[PowerCounting0, Listable];

PowerCounting0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{powerfunc, tp1, ord, loopmoms, moms, kinematics, 
   max}, {ord, loopmoms, moms, kinematics} = {OptionValue["ord"], 
    OptionValue["loopmoms"], OptionValue["moms"], 
    OptionValue["kinematics"]};
  If[Length@ord === 3 && ord[[2]] =!= 0, 
   Print["PowerCounting: only support expansion around 0."]];
  If[Length@ord === 2, ord = Insert[ord, 0, {2}]];
  tp1 = expr // FeynAmpDenominatorExplicit // 
      ExpandMomentum[#, moms] & // ExpandDirac;
  max = tp1 // Together // Exponent[#, ord[[1]], Min] &;
  powerfunc = 
   If[MatchQ[ord, {__, "Leading"}], 
    Normal[Series[#, ReplacePart[ord, 3 -> max]]] &, 
    Normal[Series[#, ord]] &];
  If[OptionValue["PowerCountingPrintLeadingPower"], 
   Print["The leading power is ", ord[[1]], "^", max]];
  tp1 // powerfunc // SPDToFAD[#, loopmoms, kinematics] &]

LeadingPower[expr_, para_, process_String : "CurrentProcess"] := 
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
  ]