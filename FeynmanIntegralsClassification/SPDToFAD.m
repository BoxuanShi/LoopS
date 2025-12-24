ClearAll[SPDToFAD, SPDToFAD0];
SPDToFAD::usage = "SPDToFAD[expr_, loopmoms_List, kinematics_List]. Make sure there is only independent SPD in the expr.";
SPDToFAD[expr_, process_String : "CurrentProcess"] := SPDToFAD[expr, ToExpression[process]]
SPDToFAD[expr_, process_Association] := SPDToFAD[expr, process["loopmoms"], process["kinematics"]]
SPDToFAD[expr_, loopmoms_List, kinematics_List] := SPDToFAD0[expr, "loopmoms" -> loopmoms, "kinematics" -> kinematics]
SetAttributes[SPDToFAD0, Listable];
Options[SPDToFAD0] = {"loopmoms" -> "loopmoms", "kinematics" -> "kinematics"};
SPDToFAD0[expr_, OptionsPattern[]] := Module[{loopmoms, kinematics, i, expr2, rules, tp1, tp2, tp3, tp4, tp5, Abbr}, 
  {loopmoms, kinematics} = {OptionValue["loopmoms"], OptionValue["kinematics"]};
  {expr2, rules} = AbbreviateDeno[Together[expr], "AbbreviateDenoName" -> Abbr];
  tp1 = rules[[All, 2]];
  tp3 = Table[If[! FreeQ[tp2 = tp1[[i]], SPD], 
      tp2 = (tp2 /. SPD -> Times)^-1; 
      (*in case of x*l1^2 appear in the deno - 1*)
      tp5 = Complement[Coefficient[tp2, loopmoms^2], {0}];
      tp5 = If[tp5 === {}, 1, tp5[[1]]];
      (*in case of x*l1^2 appear in the deno - 2*)
      tp4 = 1 / tp5 * PropsToFAD[{tp2 / tp5}, loopmoms, kinematics];
      tp4, 
      tp2], {i, Length@tp1}];
  rules = Thread[rules[[All, 1]] -> tp3];
  expr2 /. Dispatch@rules // If[! FreeQ[#, SFAD], ToSFAD[#], #] & // FeynAmpDenominatorCombine // FCES
]