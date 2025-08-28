SeparateFAD;

ClearAll[SeparateFAD]
SeparateFAD[amp_, loops_, process_String : "CurrentProcess"] := 
 SeparateFAD[amp, loops, ToExpression[process]]
SeparateFAD[amp_, loops_, process_Association] := 
 SeparateFAD[amp, loops, process["moms"]]
SeparateFAD[amp_, loops_List, moms_List] := 
 Module[{amp2, tp1, tp2, patt, i, tpNumlist, tpDenolist, tpNumSPD},
  patt = x : (_FAD | _SFAD) /; ! FreeQ[x, Alternatives @@ loops];
  amp2 = If[! FreeQ[amp, SFAD], amp // ToSFAD, 
    amp];(*fix a bug of FeynAmpDenominatorCombine*)
  {tpNumlist, tpDenolist} = 
   amp2 // FeynAmpDenominatorSplit // FCES // Separate[#, patt] & // 
     FeynAmpDenominatorCombine // FCES;
  (*tpNumlist=tpNumlist//FeynAmpDenominatorExplicit//ExpandDirac[#,moms]&;*)
  {tpNumlist, tpDenolist}
  ]