{Off[Solve::svars], ClearAll@FindnumRules, Protect[De2]};

ClearAll[FindnumRules]
FindnumRules[basis_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, FindnumRules[basis, p["loopmoms"], p["kinematics"], p["moms"]]]
FindnumRules[basis_List, loopmoms_List, kinematics_, moms_List] := FindnumRules[basis, loopmoms, kinematics, moms] = Module[{tp1, tp2, i, x},
   tp1 = basis // TogetherExpandDenominator // # /. kinematics & // PropsToSPD[#, SPD, moms] &;
   tp2 = Solve[tp1 == Table[De2[i], {i, Length@basis}], getS[tp1, x : _SPD /; ! FreeQ[x, Alternatives @@ loopmoms]]][[1]];
   tp2 // Collect[#, _De2, Simplify] &
   ]