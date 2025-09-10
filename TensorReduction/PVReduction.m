ClearAll[loopRulesPV];
Protect[\[Lambda]PV, indPV];
Options[loopRulesPV] = {"PVPatt" -> Automatic};
loopRulesPV[expr_, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 loopRulesPV[expr, ToExpression[process], opt]
loopRulesPV[expr_, process_Association, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 loopRulesPV[expr, process["loopmoms"], process["extmomsind"], opt]
loopRulesPV[expr_, loopmoms_List, extmomsind_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{num, tp1, head, n, PVPatt},
  PVPatt = 
   If[OptionValue["PVPatt"] == 
     Automatic, (GSD[_] | 
      FVD[_, _] | (SPD[_, PVmom_] /; ! 
         MatchQ[PVmom, Alternatives @@ Join[loopmoms, extmomsind]])), 
    OptionValue["PVPatt"]];
  
  For[
   num = 1;
   (*to fix a bug for the form SPD[l1,p1t]^2*)
   tp1 = expr /. {
      SPD[b_, c_]^a_Integer /; a > 1 :> head @@ ConstantArray[SPD[b, c], a],
      FVD[b_, c_]^a_Integer /; a > 1 :> FCES[FCContract[FVD[b, c]^a]]
      },
   num <= Length@loopmoms, num++,
   n = 1; 
   tp1 = tp1 /. 
      x : PVPatt /; ! 
         FreeQ[x, loopmoms[[num]]] :> (\[Lambda]PV[num]*FCI[x] /. 
         Momentum[loopmoms[[num]], D] :> LorentzIndex[indPV[num, n++], D]) // 
     FCES
   ]; tp1 /. head -> Times]


ClearAll[PVReduce];
PVReduce[expr_, process_String : "CurrentProcess"] := 
 PVReduce[expr, ToExpression[process]]
PVReduce[expr_, process_Association] := 
 PVReduce[expr, process["loopmoms"], process["purePV"]]
PVReduce[expr_, loopmoms_List, purePV_] := 
 Module[{\[Delta]\[Delta], i, j, tp1, tp2, tp3, patt, name, tph1},
  
  tp1[a_] := 
   Join @@ Table[ConstantArray[loopmoms[[i]], a[[i]]], {i, Length@loopmoms}];
  tp2[a_] := Join @@ Table[indPV[i, j], {i, Length@loopmoms}, {j, a[[i]]}];
  tp3[a_] := PVRules[tp1[a], tp2[a], purePV];
  patt = Table[
    "a" <> ToString[i] <> "_" // ToExpression, {i, Length@loopmoms}];
  name = Table["a" <> ToString[i] // ToExpression, {i, Length@loopmoms}];
  
  CollectFlat[
     expr*Times @@ (
       Array[\[Lambda]PV, Length@loopmoms]^\[Delta]\[Delta]), \[Lambda]PV[_], 
     Factor] /. 
    Times @@ Table[\[Lambda]PV[i]^patt[[i]], {i, Length@loopmoms}] -> 
     tph1[name - \[Delta]\[Delta]] /. tph1 -> tp3]
