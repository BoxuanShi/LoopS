ClearAll[FindRulesComplete]
FindRulesComplete::usage = 
  "FindRulesComplete return the minimal MIs only when the masters in every \
families have been found completely...";
Options[FindRulesComplete] := DeleteCases[CreateOptions[{}, {findrules2}], 
 x_ /; x[[1]] === "LinearPropagatorQ", {1}];
FindRulesComplete[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FindRulesComplete[family, MI0, loops, MaxIt, ToExpression[process], opt]
FindRulesComplete[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FindRulesComplete[family, MI0, loops, MaxIt, process["kinematics"], 
  process["extmomsind"], opt]
FindRulesComplete[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   kinematics_List, extmomsind_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{x, liq, tp1, tp2, tp3},
  
  liq = (! FreeQ[linearPropsQ[#, loops] & /@ Flatten[family], True]);
  
  If[
   liq
   ,
   tp1 = findrules2[family, MI0, loops, MaxIt, kinematics, extmomsind, 
     "LinearPropagatorQ" -> False, Evaluate@opt];
   tp2 = getS[MI0 /. Dispatch[tp1], _G];
   tp3 = findrules2[family, tp2, loops, MaxIt, kinematics, extmomsind, 
     "LinearPropagatorQ" -> True, Evaluate@opt];
   Thread[MI0 -> (MI0 /. Dispatch[tp1] /. Dispatch[tp3])] // 
    DeleteCases[#, x_ /; x[[1]] === x[[2]]] &
   ,
   findrules2[family, MI0, loops, MaxIt, kinematics, extmomsind, 
    "LinearPropagatorQ" -> False, Evaluate@opt]
   ]
  ]


ClearAll[findrules];
Options[findrules] := 
  CreateOptions[{"Parallelization" -> False, "PreferMIs" -> {}, 
    "FIREVerbose" -> False}, {PrepareParallel, FIRE}];
findrules[family2_List, MI2_List, loops_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 findrules[family2, MI2, loops, ToExpression[process], opt]
findrules[family2_List, MI2_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 findrules[family2, MI2, loops, process["kinematics"], process["extmomsind"], 
  opt]
findrules[family2_List, MI2_List, loops_List, kinematics_List, 
   extmomsind_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{nfam, family, range, MI, rules, rules2, a, b, invRules, optPS},
  
  Internal =.; External =.; Propagators =.; Replacements =.;
  invRules[expr_, condi_ : (False &)] := 
   expr /. {Rule[a_, b_] /; condi[a, b] :> (b -> a), 
     RuleDelayed[a_, b_] /; condi[a, b] :> (b :> a)};
  (*change the order of family*)
  nfam = Length[family2];
  family = Reverse[family2];
  MI = MI2 /. Dispatch[G[a_, b_] :> G[nfam - a + 1, b]];
  
  range = Range[nfam];
  Problems = range;
  Do[
   Internal[i] = loops;
   External[i] = extmomsind;
   Propagators[i] = family[[i]];
   Replacements[i] = kinematics, {i, range}
   ];
  
  Off[LaunchKernels::nodef];
  rules = If[
    OptionValue["Parallelization"] && $KernelID === 0
    ,
    If[$KernelCount == 0, 
     PrepareParallel[
      Evaluate@FilterOptions[{opt}, 
        PrepareParallel]]];(*only for launching kernels.*)
    BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)}, 
     FindRules[MI, "Parallel" -> True]]
    ,
    BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)}, 
     FindRules[MI, "Parallel" -> False]]
    ];
  On[LaunchKernels::nodef];
  
  rules2 = rules /. G[a_, b_] :> G[nfam - a + 1, b];
  rules2 // 
   invRules[#, MemberQ[tosector@OptionValue["PreferMIs"], tosector@#] &] &
  ]


ClearAll[findrulesX]
Options[findrulesX] := CreateOptions[{}, {findrules}]
findrulesX[family_List, MIs_List, loops_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 findrulesX[family, MIs, loops, ToExpression[process], Evaluate@opt]
findrulesX[family_List, MIs_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 findrulesX[family, MIs, loops, process["kinematics"], process["extmomsind"], 
  Evaluate@opt]
findrulesX[family_List, MIs_List, loops_List, kinematics_List, 
   extmomsind_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{x, familyEiknol, MIsEkinol, tpInvRules, MIRules, MIRules2, optf1, rt},
  {familyEiknol, MIsEkinol, tpInvRules} = 
   GenerateEiknolFamilies[family, MIs, loops];
  
  MIRules = 
   Block[{Print = (# &)}, 
    findrules[familyEiknol, MIsEkinol, loops, kinematics, extmomsind, 
     Evaluate@FilterOptions[{opt}, findrules]]];
  MIRules2 = MIRules /. Dispatch[tpInvRules];
  
  rt = Flatten[AtomizeRules /@ MIRules2] // 
    DeleteCases[#, x_ /; x[[1]] === x[[2]]] &;
  Print["Input: ", Length@MIs, ", output: ", 
   MIs /. Dispatch@rt // getS[#, _G] & // Length];
  
  rt
  ]


FamilyMergeSeed::usage = "Generate G seeds for family merge.";
ClearAll[FamilyMergeSeed]
FamilyMergeSeed[sector_] := Module[{tp1},
  tp1 = getS[sector, _G];
  FamilyMergeSeed /@ tp1 // Flatten
  ]
FamilyMergeSeed[sector_G] := Module[{tp1, tp2},
  tp1 = sector[[2]] // Position[#, 1] & // Flatten;
  tp2 = Table[sector // ReplacePart[#, {2, i} -> 2] &, {i, tp1}];
  
  tp2
  ]


ClearAll[findrules2]
Options[findrules2] := 
 CreateOptions[{"LinearPropagatorQ" -> False}, {findrulesX, findrules, TableS}]
(*findrules2 return the minimal MIs only when the masters in every families \
have been found completely...*)
findrules2[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 findrules2[family, MI0, loops, MaxIt, ToExpression[process], opt]
findrules2[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   process_Association, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 findrules2[family, MI0, loops, MaxIt, process["kinematics"], 
  process["extmomsind"], opt]
findrules2[family_List, MI0_List, loops_List, MaxIt_Integer : 20, 
   kinematics_List, extmomsind_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{sectors, fr, rulesSec, rulesOri, seedsNew, tp5, tp6, tp7, tp8, tp9, 
   tp10, seedsfull, rulesCom, sol, num, num1, num2, MI, MINext, MINext2, 
   opttable, optfr},
  
  If[FIREEvaluate[Burning =!= True], Return["Burn the FIRE first."]];
  
  fr = If[OptionValue["LinearPropagatorQ"], findrulesX, findrules];
  
  optfr = FilterOptions[{opt}, fr];
  opttable = FilterOptions[{opt}, TableS];
  
  MI =.;
  MINext = MI0;
  MINext2 = MI0;
  sol = MI0;
  
  For[
   num1 = 1, MI =!= MINext && num1 <= MaxIt, num1++,
   
   Print["Cycle: ", num1];
   MI = MINext;
   
   sectors = MI // tosector;
   rulesSec = 
    Monitor[Dispatch@
      fr[family, sectors, loops, kinematics, extmomsind, Evaluate@optfr], 
     "finding sector rules..."];
   rulesOri = 
    Monitor[Dispatch@
      fr[family, MI, loops, kinematics, extmomsind, Evaluate@optfr], 
     "finding origin rules..."];
   
   (*block print of findrules/FindRules*)
   seedsNew = TableS[
       Block[{Print = (# &)},
        If[(Union@Flatten@MI[[num, 2]]) === {0, 1}, MI[[num]]
         ,
         tp5 = MI[[num]] // tosector;
         tp6 = tp5 /. rulesSec // getS[#, _G][[1]] &;
         If[
          (MI[[num]] /. rulesOri // tosector) === tp6, MI[[num]]
          ,
          (*tp7=tp6[[2]]//Position[#,1]&//Flatten;*)
          tp8 = FamilyMergeSeed[tp6](*Table[tp6//ReplacePart[#,{2,
          i}\[Rule]2]&,{i,tp7}]*);
          
          tp9 = fr[family, {tp8, MI[[num]]} // Flatten, loops, kinematics, 
            extmomsind, "Parallelization" -> False];
          tp10 = MI[[num]] /. tp9
          ]
         ]
        ]
       ,
       {num, Length@MI}, Evaluate@opttable] // Flatten // Union;
   
   seedsfull = 
    FIREEvaluate[{MI, seedsNew, seedsNew /. Dispatch[G -> F]}] // 
     getS[#, _G] &;
   rulesCom = 
    Monitor[Dispatch@
      fr[family, seedsfull, loops, kinematics, extmomsind, Evaluate@optfr], 
     "finding complete rules..."];
   
   Monitor[
    sol = FIREEvaluate[sol /. rulesCom /. Dispatch[G -> F]];
    MINext2 = sol // getS[#, _G] &;
    For[
     num2 = 1, MINext =!= MINext2 && num2 <= MaxIt, num2++,
     MINext = MINext2;
     
     sol = FIREEvaluate[sol /. rulesCom /. Dispatch[G -> F]];
     MINext2 = sol // getS[#, _G] &
     ],
    {num2, MaxIt}];
   
   Print["Input: ", Length@MI0, ", output: ", Length@MINext];
   
   ];
  
  
  (*Print["Input: ",Length@MI0,", output: ",Length@MINext];*)
  
  (*result*)
  Thread[MI0 -> (sol /. Dispatch[d -> D])] // 
   DeleteCases[#, a_ /; a[[1]] === a[[2]]] &
  ]