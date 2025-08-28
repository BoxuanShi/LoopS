SPDToFAD;

ClearAll[SPDToFAD, SPDToFAD0];
SPDToFAD[expr_, loops_List, process_String : "CurrentProcess"] := 
 SPDToFAD[expr, loops, ToExpression[process]]
SPDToFAD[expr_, loops_List, process_Association] := 
 SPDToFAD[expr, loops, process["kinematics"]]
SPDToFAD[expr_, loops_List, kinematics_List | kinematics_Dispatch] := 
 SPDToFAD0[expr, "loops" -> loops, "kinematics" -> kinematics]
SetAttributes[SPDToFAD0, Listable];
Options[SPDToFAD0] = {"loops" -> "loops", "kinematics" -> "kinematics"};
SPDToFAD0[expr_, OptionsPattern[]] := 
 Module[{loops, kinematics, i, expr2, rules, tp1, tp2, tp3, tp4, Abbr},
  {loops, kinematics} = {OptionValue["loops"], OptionValue["kinematics"]};
  {expr2, rules} = AbbreviateDeno[expr, "AbbreviateDenoName" -> Abbr];
  tp1 = rules[[All, 2]];
  tp3 = Table[
    If[! FreeQ[tp2 = tp1[[i]], SPD]
     ,
     tp2 = (tp2 /. SPD -> Times)^-1;
     tp4 = PropsToFAD[{tp2}, loops, kinematics];
     If[tp4 === $Failed, tp4 = -PropsToFAD[{-tp2}, loops, kinematics]];
     tp4
     ,
     tp2]
    , {i, Length@tp1}];
  rules = Thread[rules[[All, 1]] -> tp3];
  expr2 /. Dispatch@rules
  ]