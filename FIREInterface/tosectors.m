ClearAll[tosector, samesectorQ, subsectorQ, propNumG, FIREMasterIntegrals]


tosector[Gs_] := 
 Gs /. G[a_, b_] :> G[a, Which[# > 1, 1, # < 0, 0, True, #] & /@ b]


samesectorQ[G1_, G2_] := Module[{tp1}, 
  tp1 = tosector /@ {G1, G2};
  tp1[[1]] === tp1[[2]]
  ]


subsectorQ[G1_, G2_] := Module[{s1, s2},
  If[Length @ G1[[2]] =!= Length @ G2[[2]], Return[False]];
  {s1, s2} = tosector /@ {G1, G2};
  AllTrue[s1[[2]] - s2[[2]], NonNegative] && s1[[1]] === s2[[1]]
  ]


propNumG[Gs_] := Select[Gs[[2]], # > 0 &] // Length
SetAttributes[propNumG, Listable]


FIREMasterIntegrals[] := FIREEvaluate[G @@@ MasterIntegrals[]]