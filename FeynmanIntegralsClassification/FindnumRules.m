FindnumRules;

{Off[Solve::svars], ClearAll@FindnumRules, Protect[De2]};
FindnumRules[basis_List, process_String : "CurrentProcess"] := 
 FindnumRules[basis, ToExpression[process]]
FindnumRules[basis_List, process_Association] := 
 FindnumRules[basis, process["loopmoms"], process["kinematics"], 
  process["moms"]]
FindnumRules[basis_List, loopmoms_List, kinematics_, moms_List] := 
 FindnumRules[basis, loopmoms, kinematics, moms] = 
  Module[{rules, tp1, tp2, i, x},
   tp1 = basis // Expand // # /. kinematics & // PropsToSPD[#, SPD, moms] &;
   tp2 = Solve[tp1 == Table[De2[i], {i, Length@basis}], 
      getS[tp1, x : _SPD /; ! FreeQ[x, Alternatives @@ loopmoms]]][[1]];
   (*tp2=tp2/.x:_SPD/;FreeQ[x,Alternatives@@loopmoms]:>spd@@x;*)
   tp2 // Collect[#, _De2, Simplify] &]