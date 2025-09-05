FindfamilyG;
Symmetry;
SymmetryFirstQ;

ClearAll[FindfamilyG];
Options[FindfamilyG] := CreateOptions[{"Symmetry" -> <|"Rules" -> {{}}, "InvRules" -> {{}}|>, "SymmetryFirstQ" -> True, "FindfamilyGDefault" -> Hold[Abort[]], "FGMode" -> "GSearch"}, {CanonicalLoops}];

FindfamilyG[props0_List | props0_FAD | props0_SFAD, familyLS_List, loops_List, process_String : "CurrentProcess", opt : OptionsPattern[]] /; OptRestrict[opt] := FindfamilyG[props0, familyLS, loops, ToExpression[process], Evaluate@opt]

FindfamilyG[props0_List | props0_FAD | props0_SFAD, familyLS_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FindfamilyG[props0, familyLS, loops, process["moms"], process["kinematics"], 
  Evaluate@opt]
FindfamilyG[props0_List | props0_FAD | props0_SFAD, familyLS_List, loops_List,
    moms_List, kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{a, sym, symQ, symnum, tpfamily, tp1, tp2, tp2x, tp3, tpR1, tpR2, tpR3, propsSTD, ct, props, sign3},

  sym = OptionValue["Symmetry"];
  symQ = (sym =!= <|"Rules" -> {{}}, "InvRules" -> {{}}|>);
  
  If[symQ,
   If[Sort@sym["Rules"] =!= Sort@sym["InvRules"], 
     Print["Rules and InvRules in Symmetry should be the same set!"]; Abort[]];
   ];
  
  props = FADToProps[props0, List];
  

  If[OptionValue["SymmetryFirstQ"],

    For[symnum = 1, symnum <= Length@sym["Rules"], symnum++,

    tp1 = props /. sym["Rules"][[symnum]] // 
        propsToLS[#, loops, kinematics] & // 
      CanonicalLoops[#, loops, moms, kinematics, Evaluate @ FilterOptions[{opt}, CanonicalLoops]] &;
    tp2 = FirstPosition[familyLS[[2]], 
      a_List /; TrueQ@Expand[a[[1]][[All, 1 ;; 3]] == tp1[[1]][[All, 1 ;; 3]]],
        False, {2}];
        
    If[tp2 =!= False, Break[]]
    ];
    ,

    tp1 = TableS[
    props /. sym["Rules"][[symnum]] // propsToLS[#, loops, kinematics] & // 
    CanonicalLoops[#, loops, moms, kinematics, Evaluate @ FilterOptions[{opt}, CanonicalLoops]] &
    , {symnum, Length @ sym["Rules"]}];
    tp2x = TableS[
    FirstPosition[familyLS[[2]], a_List /; TrueQ @ Expand[a[[1]][[All, 1 ;; 3]] == tp1[[symnum]][[1]][[All, 1 ;; 3]]], False, {2}]
    , {symnum, Length @ sym["Rules"]}];

    tp2 = Select[tp2x, # =!= False &];
    tp2 = If[tp2 === {}, False, SortBy[tp2, {#[[1]], -#[[2]]} &][[1]]];
    symnum = FirstPosition[tp2x, tp2][[1]];
    tp1 = tp1[[symnum]]
    
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
