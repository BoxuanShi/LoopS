FindfamilyG;

ClearAll[FindfamilyG]
Options[FindfamilyG] := 
  CreateOptions[{"FindfamilyGDefault" -> Hold[Abort[]], "FGMode" -> "GSearch",
     "Symmetry" -> <|"Rules" -> {{}}, "InvRules" -> {{}}|>}, {CanonicalLoops}];
FindfamilyG[props0_List, familyLS_List, loops_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FindfamilyG[props0, familyLS, loops, ToExpression[process], Evaluate@opt]
FindfamilyG[props0_List, familyLS_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FindfamilyG[props0, familyLS, loops, process["moms"], process["kinematics"], 
  Evaluate@opt]
FindfamilyG[props0_List | props0_FAD | props0_SFAD, familyLS_List, loops_List,
    moms_List, kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{i, default, sym, symQ, symnum, tpfamily, lx, ln, tp1, tp2, tp3, tp4,
    tp5, tpR1, tpR1x, tpR2, tpR3, propsSTD, ct, props, sign1, sign3, optLS},
  sym = OptionValue["Symmetry"];
  symQ = (sym =!= <|"Rules" -> {{}}, "InvRules" -> {{}}|>);
  
  If[symQ,
   If[Sort@sym["Rules"] =!= Sort@sym["InvRules"], 
     Print["Rules and InvRules in Symmetry should be the same set!"]; Abort[]];
   ];
  
  props = FADToProps[props0, List];
  
  optLS = FilterOptions[{opt}, CanonicalLoops];
  For[symnum = 1, symnum <= Length@sym["Rules"], symnum++,
   tp1 = props /. sym["Rules"][[symnum]] // 
      propsToLS[#, loops, kinematics] & // 
     CanonicalLoops[#, loops, moms, kinematics, Evaluate@optLS] &;
   tp2 = FirstPosition[familyLS[[2]], 
     a_List /; TrueQ@Expand[a[[1]][[All, 1 ;; 3]] == tp1[[1]][[All, 1 ;; 3]]],
      False, {2}];
   If[tp2 =!= False, Break[]]
   ];
  
  If[tp2 === False, Print["family is not complete -> ", props]; 
   ReleaseHold@OptionValue["FindfamilyGDefault"]];
  If[OptionValue["FGMode"] === "familySearch", Return["Exist"]];
  
  tpR1 = tp1[[2, 1]];
  tpR2 = inverseRule[familyLS[[2]][[Sequence @@ tp2]][[2, 1]], loops];
  
  tpR3 = Thread[loops -> (loops /. tpR1 /. tpR2)] // Together // Expand;
  
  (*sign3=If[Length@tp1===3(*for linear propagators*),Times@@tp1[[3,1]]*Times@@
  familyLS[[2]][[Sequence@@tp2]][[3,1]],1];(*for linear propagators*)*)
  
  tpfamily = familyLS[[1]][[tp2[[1]]]];
  
  propsSTD = props /. sym["Rules"][[symnum]] /. tpR3;
  
  If[Length@tp1 === 3(*for linear propagators*),
   ct = {Count[propsSTD - # // Together // Expand // # /. kinematics &, 
        0] & /@ (tpfamily),
     Count[propsSTD + # // Together // Expand // # /. kinematics &, 
        0] & /@ (tpfamily)};
   sign3 = (-1)^Total@ct[[2]];
   ct = Total@ct
   ,
   ct = Count[propsSTD - # // Together // Expand // # /. kinematics &, 
       0] & /@ (tpfamily);
   sign3 = 1;
   ];
  
  tp3 = If[symQ,
    {sign3*
      G[tp2[[1]], ct, 
       Position[sym["InvRules"], sym["Rules"][[symnum]]][[1, 1]]], 
     tpR3(*Flatten@{tpR3,sym["Rules"][[symnum]]}*)},
    {sign3*G[tp2[[1]], ct], tpR3}
    ];
  
  If[Total@ct =!= Length@props, Print["rules is wrong" -> {props0, tp3}]; 
   Abort[]];
  
  tp3
  ]


FindfamilyG[_, _, {}, x___] := {1, {}}
