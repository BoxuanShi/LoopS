ClearAll[SeparateFAD]
SeparateFAD[amp_, process_String : "CurrentProcess"] := SeparateFAD[amp, ToExpression[process]]
SeparateFAD[amp_, process_Association] := SeparateFAD[amp, process["loopmoms"], process["moms"]]
SeparateFAD[amp_, loopmoms_List, moms_List] := Module[{amp2, patt, i, tpNumlist, tpDenolist},
  patt = x : (_FAD | _SFAD) /; ! FreeQ[x, Alternatives @@ loopmoms];
  amp2 = If[! FreeQ[amp, SFAD], amp // ToSFAD, amp];
  {tpNumlist, tpDenolist} = amp2 // FeynAmpDenominatorSplit // getDo[#, _FeynAmpDenominator, ExpandDirac[ExpandMomentum[#, moms]] &] & // Separate[#, patt] & // FeynAmpDenominatorCombine // FCES;
  {tpNumlist, tpDenolist}
]