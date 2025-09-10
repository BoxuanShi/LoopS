(*IntegerPartitions[12,{8},{1,2,3}]//TimingS*)

ClearAll[IncrementListElement]
IncrementListElement[vec_List, patt_, b_Integer] := Module[{i, pos, tp1},
  pos = Position[vec, patt, {1}] // DeleteCases[#, {0}] &;
  tp1 = Table[
    vec // ReplacePart[#, pos[[i]] :> (#[[Sequence @@ pos[[i]]]] + b)] &, {i, 
     Length@pos}];
  (*Join[{vec},tp1]//DeleteDuplicates*)
  tp1 // DeleteDuplicates
  ]


ClearAll[PossibleMIsInSector];
Options[PossibleMIsInSector] = {"MixedIndex" -> False};
MixedIndex;
PossibleMIsInSector::usage = 
  "rx: Total of positive index (0 means no constraint), sx: minimum and \
maximum index, dx: minimum and maximum sum of total negative and enhanced \
index.
MixedIndex means whether negative and enhanced indices appear at the same \
time.";
PossibleMIsInSector[g0_G, rx_Integer : 0, sx_List : {0, 2}, dx_List : {0, 1}, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{x, num, rx2, sec, s1, s2, f1, f2, d1, d2, tp1, tp2, tp3, tp4},
  
  sec = tosector[g0][[2]];
  {s1, s2} = sx;
  {d1, d2} = dx;
  rx2 = If[rx === 0, Total[sec] + d2, rx];
  
  f1[x_] := 
   Flatten[(IncrementListElement[#, Alternatives @@ Range[s1 + 1, 0], -1] &) /@
       x, 1] // DeleteDuplicates;
  f2[x_] := 
   Flatten[(IncrementListElement[#, Alternatives @@ Range[1, s2 - 1], 1] &) /@
       x, 1] // DeleteDuplicates;
  
  tp1 = {sec};
  tp2 = tp1;
  For[num = 1, num <= Abs[d1], num++,
   tp2 = f1[tp2];
   tp1 = Join[tp1, tp2]
   ];
  
  tp3 = If[OptionValue["MixedIndex"], tp1, {sec}];
  tp4 = tp3;
  For[num = 1, num <= Min[{Abs[d2], rx2 - Total[sec]}], num++,
   tp4 = f2[tp4];
   tp3 = Join[tp3, tp4]
   ];
  
  (g0[[0]][g0[[1]], #] &) /@ Join[tp1, tp3[[2 ;; -1]]]
  ]


ClearAll[PossibleDAction];
SetAttributes[PossibleDAction, Listable]
PossibleDAction[g0_G] := Module[{x, i, pos, vec, g1, g2, g3},
  vec = g0[[2]];
  g1 = IncrementListElement[vec, x_ /; x > 0, 1];
  g2 = IncrementListElement[#, _, -1] & /@ g1 // Flatten[#, 1] &;
  g1 = g0[[0]][g0[[1]], #] & /@ g1;
  g2 = g0[[0]][g0[[1]], #] & /@ g2;
  
  Join[g1, g2] // DeleteDuplicates
  ]


ClearAll[PossibleIntForDEInSector]
Options[PossibleIntForDEInSector] := 
  CreateOptions[{}, {PossibleMIsInSector}];
PossibleIntForDEInSector[g0_G, rx_Integer : 0, sx_List : {0, 2}, 
  dx_List : {0, 1}, opt : OptionsPattern[]] := Module[{vec, tp1, optPMS},
  
  optPMS = FilterOptions[{opt}, PossibleMIsInSector];
  tp1 = PossibleMIsInSector[g0, rx, sx, dx, Evaluate[optPMS]];
  
  DeleteDuplicates[Flatten[PossibleDAction /@ tp1]]
  ]
