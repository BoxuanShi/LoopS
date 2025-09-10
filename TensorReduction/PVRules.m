ClearAll[PVRules]
PVRules[loopsPV_List, Indices_List, head_ : purePV] := 
 Module[{i, loopsIndex, loopsPV2, Indices2, loopRules, IndexRules, tpPVRules, 
   nLlist},
  If[Length@loopsPV =!= Length@Indices, 
   Print["PVRules: Wrong input ->", {loopsPV, Indices}]; Abort[]];
  
  loopsIndex = Transpose@{loopsPV, Indices};
  loopsIndex = 
   loopsIndex // SplitBy[#, #[[1]] &] & // SortBy[#, -Length[#] &] &;
  nLlist = Length /@ loopsIndex;
  loopsIndex = Flatten[loopsIndex, 1];
  loopsPV2 = DeleteDuplicates@loopsIndex[[All, 1]];
  Indices2 = loopsIndex[[All, 2]];
  
  If[! FreeQ[head[nLlist], head], 
   Print["PVRules: Calculate " <> ToString[head[nLlist]] <> " firstly."]; 
   Abort[]];
  
  loopRules = Table[PVL[i] -> loopsPV2[[i]], {i, Length@loopsPV2}];
  IndexRules = Table[PVind[i] -> Indices2[[i]], {i, Length@Indices2}];
  tpPVRules = Join[loopRules, IndexRules];
  
  head[nLlist] /. Dispatch@tpPVRules
  ]
