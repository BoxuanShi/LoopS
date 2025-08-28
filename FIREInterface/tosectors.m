tosectors;

tosector[Gs_] := 
 Gs /. G[a_, b_] :> G[a, (b /. {c_ /; c > 1 -> 1, c_ /; c < 0 -> 0})]
samesectorQ[G1_, G2_] := Module[{tp1, tp2},
  tp1 = tosector /@ {G1, G2};
  tp1[[1]] === tp1[[2]]
  ]
subsectorQ[G1_, G2_] := Module[{tp1, tp2},
  If[Length@G1[[2]] =!= Length@G2[[2]], Return[False]];
  tp1 = tosector /@ {G1, G2};
  tp2 = tp1[[1, 2]] - tp1[[2, 2]] // Flatten // Union;
  SubsetQ[{0, 1}, tp2] && G1[[1]] === G2[[1]]
  ]
propNumG[Gs_] := Select[Gs[[2]], # > 0 &] // Length
SetAttributes[propNumG, Listable]

MasterIntegralsS[] := G @@@ MasterIntegrals[]