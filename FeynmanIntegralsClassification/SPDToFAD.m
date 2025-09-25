ClearAll[SPDToFAD, SPDToFAD0];
SPDToFAD[expr_, process_String : "CurrentProcess"] := 
 SPDToFAD[expr, ToExpression[process]]
SPDToFAD[expr_, process_Association] := 
 SPDToFAD[expr, process["loopmoms"], process["kinematics"]]
SPDToFAD[expr_, loopmoms_List, 
  kinematics_List | kinematics_Dispatch] := 
 SPDToFAD0[expr, "loopmoms" -> loopmoms, "kinematics" -> kinematics]
SetAttributes[SPDToFAD0, Listable];
Options[SPDToFAD0] = {"loopmoms" -> "loopmoms", 
   "kinematics" -> "kinematics"};
SPDToFAD0[expr_, OptionsPattern[]] := 
 Module[{loopmoms, kinematics, i, expr2, rules, tp1, tp2, tp3, tp4, 
   Abbr}, {loopmoms, kinematics} = {OptionValue["loopmoms"], 
    OptionValue["kinematics"]};
  {expr2, rules} = 
   AbbreviateDeno[expr, "AbbreviateDenoName" -> Abbr];
  tp1 = rules[[All, 2]];
  tp3 = Table[
    If[! FreeQ[tp2 = tp1[[i]], SPD], tp2 = (tp2 /. SPD -> Times)^-1;
     tp4 = PropsToFAD[{tp2}, loopmoms, kinematics];
     If[tp4 === $Failed, 
      tp4 = -PropsToFAD[{-tp2}, loopmoms, kinematics]];
     tp4, tp2], {i, Length@tp1}];
  rules = Thread[rules[[All, 1]] -> tp3];
  expr2 /. Dispatch@rules // If[! FreeQ[#, SFAD], ToSFAD[#], #] & // 
    FeynAmpDenominatorCombine // FCES]