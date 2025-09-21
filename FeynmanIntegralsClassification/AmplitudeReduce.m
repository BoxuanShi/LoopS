ClearAll[AmplitudeReduce]
Options[AmplitudeReduce] := 
  CreateOptions[{"AmplitudeReduceForm" -> "Expression", 
    "PowerCounting" -> (# &), "AmplitudeReduceSimplify" -> (# &), 
    "DropZeroByNumerics" -> True}, {NumeratorReduction, DenominatorToG}];
AmplitudeReduce[amp_, loops_List : {}, familyLS_List : {{}, {}}, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 AmplitudeReduce[amp, loops, familyLS, ToExpression[process], opt]
AmplitudeReduce[amp_, loops_List : {}, familyLS_List : {{}, {}}, 
   process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 AmplitudeReduce[amp, loops, familyLS, process["indices"], 
  process["operatorRules"], process["loopmoms"], process["moms"], 
  process["extmomsind"], process["purePV"], process["kinematics"], opt]
AmplitudeReduce[amp_, loops_List, familyLS_List, indices_List, 
   operatorRules_List | operatorRules_Dispatch, loopmoms_List, moms_List, 
   extmomsind_List, purePV_String, kinematics_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{i, j, k, tpNumlist, tpDenolist, tpNumSPD, PowerCounting0, 
   PowerCounting, tp1, tp2, tp3, optnum, optFR, optAP, OPERAT, ophead, 
   opttable},
  (*simple cases*)
  If[amp === 0,
   Switch[OptionValue["AmplitudeReduceForm"],
    "ListRules", Return[{{{0}, {{0}}, {0}}, {}}],
    "List", Return[{{0}, {{0}}, {0}}],
    "ExpressionRules", Return[{0, {}}],
    _, Return[0]]
   ];
  
  (*separate Numerators and loop integrals*)
  {tpNumlist, tpDenolist} = SeparateFAD[amp, loops, moms];
  
  (*NumeratorReduction*)
  optnum = FilterOptions[{opt}, NumeratorReduction];
  
  (*option PowerCounting*)
  PowerCounting = OptionValue["PowerCounting"];
  PowerCounting0 = 
   If[PowerCounting === (# &), (# &), (ExpandDirac[
       ExpandMomentum[FeynAmpDenominatorExplicit[#], moms]] &)];
  opttable = FilterOptions[{opt}, TableS];
  tpNumSPD = BlockCondition[loops === {}, {Monitor = (# &)},
    TableS[
     tp1 = tpNumlist[[i]] // PowerCounting0 // PowerCounting;
     tp1 = 
      tp1 // NumeratorReduction[#, indices, operatorRules, loopmoms, moms, 
         extmomsind, purePV, "NumeratorReductionForm" -> "ExpressionRules", 
         "OperatorHead" -> OPERAT, "NumeratorReductionDispatch" -> False, 
         Evaluate@optnum] &;
     tp1 = tp1 // PowerCounting,
     {i, Length@tpNumlist}, 
     "reducing numerator structures with NumeratorReduction...", Evaluate@opttable]
    ](*//TimingS*);
  
  (*option OperatorCollect*)
  If[OptionValue["OperatorCollect"], Return[Union@Flatten@tpNumSPD]];
  
  (*DenominatorToG*)
  optFR = FilterOptions[{opt}, {DenominatorToG}];
  tp2 = TableS[
    DenominatorToG[tpNumSPD[[i, 1]], tpDenolist[[i]], loops, familyLS, moms, 
     kinematics, "DenominatorToGForm" -> "List", Evaluate@optFR],
    {i, Length@tpNumSPD},
    "reducing denominator structures with DenominatorToG...", 
    Evaluate@opttable](*//TimingS*);
  
  (*DropZeroByNumerics*)
  If[OptionValue["DropZeroByNumerics"],
   tp2 = DropZeroByNumerics[tp2, Total[Dot @@@ tp2], _G]
   ];
  
  
  (*option AmplitudeReduceForm*)
  ophead = OptionValue["OperatorHead"];
  Switch[OptionValue["AmplitudeReduceForm"],
   "ListRules",
   If[Length@tp2 === 1,
    {tp2, Dispatch[tpNumSPD[[1, 2]] /. Dispatch[OPERAT -> ophead]]}
    ,
    Table[
     tp2[[i, {1, 3}]] = tp2[[i, {1, 3}]] /. Dispatch@tpNumSPD[[i, 2]], {i, 
      Length@tp2}];
    tp2 = AbbreviatePolynomials[tp2, OperatorPattern, _OPERAT];
    {tp2[[1]], Dispatch[tp2[[2]] /. Dispatch[OPERAT -> ophead]]}
    ],
   
   "List",
   Table[tp2[[i, {1, 3}]] = 
     tp2[[i, {1, 3}]] /. Dispatch@tpNumSPD[[i, 2]] /. 
      Dispatch[OPERAT -> ophead], {i, Length@tp2}];
   tp2,
   
   "ExpressionRules",
   Monitor[
    If[Length@tp2 === 1,
     {Dot @@ tp2[[1]] // OptionValue["AmplitudeReduceSimplify"], 
      Dispatch[tpNumSPD[[1, 2]] /. Dispatch[OPERAT -> ophead]]}
     ,
     Table[
      tp2[[i, {1, 3}]] = tp2[[i, {1, 3}]] /. Dispatch@tpNumSPD[[i, 2]], {i, 
       Length@tp2}];
     tp2 = AbbreviatePolynomials[tp2, OperatorPattern, _OPERAT];
     {Total[Dot @@@ tp2[[1]]] // OptionValue["AmplitudeReduceSimplify"], 
      Dispatch[tp2[[2]] /. Dispatch[OPERAT -> ophead]]}
     ]
    , "Simplifying with the option \"AmplitudeReduceSimplify\"..."],
   
   (*default*)
   _,
   Monitor[
    Table[
     tp2[[i, {1, 3}]] = 
      tp2[[i, {1, 3}]] /. Dispatch@tpNumSPD[[i, 2]] /. 
       Dispatch[OPERAT -> ophead], {i, Length@tp2}];
    OptionValue["AmplitudeReduceSimplify"]@Total[Dot @@@ tp2],
    "Simplifying with the option \"AmplitudeReduceSimplify\"..."]
   ]
  ]