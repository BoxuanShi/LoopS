ClearAll[PVRules]
Options[PVRules] := CreateOptions[{}, {GeneratePV}]
PVRules[loopsPV_List, Indices_List, process_String : "CurrentProcess",
   opt : OptionsPattern[]] := 
 PVRules[loopsPV, Indices, ToExpression[process], opt]

PVRules[loopsPV_List, Indices_List, process_Association, 
  opt : OptionsPattern[]] := 
 PVRules[loopsPV, Indices, process["purePV"], process["extmomsind"], 
  opt]

PVRules[loopsPV_List, Indices_List, purePV_String, extmomsind_List, 
  opt : OptionsPattern[]] := 
 Module[{i, loopsIndex, loopsPV2, Indices2, loopRules, IndexRules, 
   tpPVRules, nLlist, tp1}, 
  If[Length@loopsPV =!= Length@Indices, 
   Print["PVRules: Wrong input ->", {loopsPV, Indices}]; Abort[]];
  loopsIndex = Transpose@{loopsPV, Indices};
  loopsIndex = 
   loopsIndex // GatherBy[#, #[[1]] &] & // 
    SortBy[#, -Length[#] &] &;
  nLlist = Length /@ loopsIndex;
  loopsIndex = Flatten[loopsIndex, 1];
  loopsPV2 = DeleteDuplicates@loopsIndex[[All, 1]];
  Indices2 = loopsIndex[[All, 2]];
  If[MatchQ[ToExpression[purePV][nLlist], _Missing],
   GeneratePV;
   Monitor[
    tp1 = ToStringInput
      [GeneratePV[nLlist, extmomsind, 
       Evaluate@FilterOptions[{opt}, GeneratePV]]];
    ToExpression[
     "CriticalSection[" <> purePV <> "lock," <> purePV <> "[[Key[" <> 
      ToStringInput[nLlist] <> "]]]=" <> tp1 <> "]"], 
    "PVRules: Calculating new PV-Reduction " <> purePV <> "[" <> 
     ToStringInput[nLlist] <> "]" <> "..."]];
  loopRules = Table[PVL[i] -> loopsPV2[[i]], {i, Length@loopsPV2}];
  IndexRules = 
   Table[PVind[i] -> Indices2[[i]], {i, Length@Indices2}];
  tpPVRules = Join[loopRules, IndexRules];
  ToExpression[purePV][nLlist] /. Dispatch@tpPVRules]