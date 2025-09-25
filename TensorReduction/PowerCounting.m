ClearAll[PowerCounting, PowerCounting0];
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
 Module[{powerfunc, tp1, ord, loopmoms, moms, kinematics},
  
  {ord, loopmoms, moms, kinematics} = {OptionValue["ord"], 
    OptionValue["loopmoms"], OptionValue["moms"], 
    OptionValue["kinematics"]};
  
  If[Length @ ord === 3 && ord[[2]] =!= 0, Print["PowerCounting: only support expansion around 0."]];
  If[Length @ ord === 2, ord = Insert[ord, 0, {2}]];

  powerfunc = 
   If[MatchQ[ord, {__, "Leading"}], 
    Asymptotic[#, Evaluate[ord[[1]] -> 0]] &, 
    Normal[Series[#, ord]] &];
  
  tp1 = expr // FeynAmpDenominatorExplicit // 
     ExpandMomentum[#, moms] & // ExpandDirac;
  
  If[OptionValue["PowerCountingPrintLeadingPower"], 
   Print["The leading power is ", ord[[1]], "^", 
    tp1 // Together // Exponent[#, ord[[1]], Min] &]];
  
  tp1 // powerfunc // SPDToFAD[#, loopmoms, kinematics] &
  ]