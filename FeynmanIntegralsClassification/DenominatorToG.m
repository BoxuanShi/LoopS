ClearAll[DenominatorToG]
Options[DenominatorToG] := 
  CreateOptions[{"DenominatorToGForm" -> "Expression", 
    "DropZeroSectorQ" -> True, 
    "DenominatorToGSimplify" :> SimplifyS}, {FindfamilyG, ApartFFS, TableS}];
DenominatorToG[nume_, deno_, loops_List, familyLS_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 DenominatorToG[nume, deno, loops, familyLS, ToExpression[process], opt]
DenominatorToG[nume_, deno_, loops_List, familyLS_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 DenominatorToG[nume, deno, loops, familyLS, process["moms"], 
  process["kinematics"], opt]
DenominatorToG[nume_, deno_, loops_List, familyLS_List, moms_List, 
   kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, j, sym, symQ, numCoe, numSPD, family, apCoe, apdeno, bsG, rule, 
   numRule, tp1, tp2, tp3, optFF, opt2, optAP, opttable},
  (*LO case and nume===0 case*)
  If[loops === {},
   Switch[OptionValue["DenominatorToGForm"],
    "List", Return[{{1}, {{1}}, {nume}}],
    _, Return[nume]]
   ];
  
  If[nume === 0,
   Switch[OptionValue["DenominatorToGForm"],
     "List", Return[{{0}, {{0}}, {0}}],
     _, Return[0]];
   ];
  
  (*separate SPD*)
  {numCoe, numSPD} = 
   Separate[nume, 
    x : _SPD /; ! FreeQ[x, Alternatives @@ loops]](*{{1},{nume}}*);
  
  (*denominator apart*)
  optAP = FilterOptions[{opt}, ApartFFS];
  {apCoe, apdeno} = ApartFFS[deno, loops, moms, kinematics, Evaluate@optAP];
  
  If[Dot[apCoe, apdeno] === 0,
   Switch[OptionValue["DenominatorToGForm"],
    "List", Return[{{0}, {{0}}, {0}}],
    _, Return[0]]
   ];
  
  apdeno = FADToProps[apdeno, List];
  
  (*denominator to G*)
  optFF = FilterOptions[{opt}, FindfamilyG];
  {bsG, rule} = 
   Transpose[(FindfamilyG[#, familyLS, loops, moms, kinematics, 
        Evaluate@optFF] &) /@ apdeno];
  
  (*option "Symmetry"*)
  sym = OptionValue["Symmetry"];
  symQ = (sym =!= <|"Rules" -> {{}}, "InvRules" -> {{}}|>);
  
  (*reduce SPD*G to G*)
  family = familyLS[[1]];
  opttable = FilterOptions[{opt}, TableS];
  tp1 = TableS[
    tp2 = ReduceSPDToG[
      (numSPD[[i]] /. If[symQ, sym["InvRules"][[bsG[[j, 3]]]], {}] /. 
         rule[[j]])*bsG[[j]],
      family, loops, kinematics, moms];
    If[symQ, tp2 /. sym["Rules"][[bsG[[j, 3]]]], tp2]
    ,
    {i, Length@numSPD}, {j, Length@bsG}, 
    "reducing SPD*G to G with ReduceSPDToG..."
    ,
    Evaluate@opttable
    ];
  
  (*option "DropZeroSectorQ"*)
  tp1 = If[OptionValue["DropZeroSectorQ"],
    Monitor[
     tp1 // 
      getDo[#, _G, 
        If[zeroSectorQ[GToProps[#, family], loops, kinematics], 0, #] &] &
     , "Dropping zero integrals with zeroSectorQ..."],
    tp1];
  (*tp1=If[OptionValue["DropZeroSectorQ"],
  tp1/.G[a_,b_,c___]:>If[zeroSectorQ[GToProps[G[a,b,c],family],loops,
  kinematics],0,G[a,b,c]],
  tp1];*)
  
  (*option "DenominatorToGSimplify"*)
  tp1 = TableS[
    CollectS[tp1[[i, j]], _G, OptionValue["DenominatorToGSimplify"]],
    {i, Length@tp1}, {j, Length@tp1[[i]]},
    "Simplifying with the option DenominatorToGSimplify"
    ,
    Evaluate@opttable
    ];
  
  
  tp1 = {apCoe, Transpose[tp1], numCoe};
  
  (*option "DenominatorToGForm"*)
  Switch[OptionValue["DenominatorToGForm"],
   "List", tp1,
   _, Dot @@ tp1
   ]
  ]


ClearAll[DropZeroSector]
DropZeroSector[expr_, family_List, loops_List, process_String : "CurrentProcess"] := 
 DropZeroSector[expr, family, loops, ToExpression@process]

DropZeroSector[expr_, family_List, loops_List, process_Association] :=
  DropZeroSector[expr, family, loops, process["kinematics"]]
  
DropZeroSector[expr_, family_List, loops_List, 
  kinematics_List | kinematics_Dispatch] := Module[{},
  expr // getDo[#, _G, If[zeroSectorQ[GToProps[#, family], loops, kinematics], 0, #] &] &
  ]