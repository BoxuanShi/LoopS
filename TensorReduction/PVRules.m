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
Module[{i, loopsIndex, loopsPV2, Indices2, loopRules, IndexRules, tpPVRules, nLlist, tp1, sharedQ}, 
  If[Length@loopsPV =!= Length@Indices, 
   Print["PVRules: Wrong input ->", {loopsPV, Indices}]; Abort[]];
  loopsIndex = Transpose @ {loopsPV, Indices};
  loopsIndex = loopsIndex // GatherBy[#, #[[1]] &] & // SortBy[#, - Length[#] &] &;
  nLlist = Length /@ loopsIndex;
  loopsIndex = Flatten[loopsIndex, 1];
  loopsPV2 = DeleteDuplicates@loopsIndex[[All, 1]];
  Indices2 = loopsIndex[[All, 2]];

  (*if purePV is not prepared, calculate it*)
  If[
    MatchQ[ToExpression[purePV][nLlist], _Missing]
    ,

    sharedQ = If[$KernelID === 0,
    MemberQ[$SharedVariables, ToExpression[purePV, InputForm, Hold]],
    ToExpression[purePV,InputForm,UpValues] =!= {}
    ];
    If[!sharedQ, Print["PV-Reduction " <> purePV <> "[" <> ToStringInput[nLlist] <> "]" <> " is not prepared. Calculating..."]];
    
    Monitor[
      tp1 = GeneratePV[nLlist, extmomsind, Evaluate@FilterOptions[{opt}, GeneratePV]];
      ToExpression[purePV, InputForm, 
        Function[x1, 
        ToExpression[purePV <> "lock", InputForm, Function[x2, CriticalSection[x2, AppendTo[x1, nLlist -> tp1]]]]
        , HoldFirst]
      ];
      , 
      "PVRules: Calculating new PV-Reduction " <> purePV <> "[" <> ToStringInput[nLlist] <> "]" <> "..."
    ]
  ];

  loopRules = Table[PVL[i] -> loopsPV2[[i]], {i, Length@loopsPV2}];
  IndexRules = Table[PVind[i] -> Indices2[[i]], {i, Length@Indices2}];
  tpPVRules = Join[loopRules, IndexRules];
  ToExpression[purePV][nLlist] /. Dispatch@tpPVRules]