ClearAll[GeneratePV];
UseOPITeR;
Options@GeneratePV = {"UseOPITeR" -> Automatic};
GeneratePV[nLlist_List, extmomsind_List, 
   opt : OptionsPattern[]] /; (OrderedQ@Reverse@nLlist) && OptRestrict[opt] :=
  Module[{tp1},
  Switch[OptionValue["UseOPITeR"],
   Automatic,
   Monitor[tp1 = GeneratePVOPITeR[nLlist, extmomsind], 
    "GeneratePVOPITeR..."];
   If[tp1 =!= $Failed, Return[CollectS[tp1, _FVD | _MTD, Factor]]];
   Monitor[tp1 = GeneratePVMMA[nLlist, extmomsind], "GeneratePVMMA..."];
   Return[tp1],
   True,
   Monitor[tp1 = GeneratePVOPITeR[nLlist, extmomsind], 
    "GeneratePVOPITeR..."];
   If[tp1 =!= $Failed, Return[CollectS[tp1, _FVD | _MTD, Factor]], 
    Print["OPITeR is not available."]; Abort[]],
   _,
   Monitor[tp1 = GeneratePVMMA[nLlist, extmomsind], "GeneratePVMMA..."];
   Return[tp1]
   ]
  ]

GeneratePV[numberOfIndex_Integer, externalMoms_List, opt : OptionsPattern[]] :=
  GeneratePV[ConstantArray[1, numberOfIndex], externalMoms, Evaluate@opt]