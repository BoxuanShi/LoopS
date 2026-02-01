ClearAll[countProps]
countProps[props_List, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, countProps[props, loops, p["kinematics"]]]
countProps[props_List, loops_List, kinematics_List] := Module[{i, inv, props2},
  inv = Table[If[FreeQ[Denominator@Together@props[[i]],Alternatives@@loops],1,-1],{i,Length@props}];
  props2 = MapThread[List,{props^inv,inv}];
  props2 = GatherBy[props2, TogetherExpandDenominator[#[[1]]]/.kinematics&];
  props2 = {#[[1,1]],Total@#[[All,2]]}&/@props2;
  Transpose@props2
]


ClearAll[EiknolPermutation]
EiknolPermutation[family_List, loops_List] := Module[{posL, permuL},
  posL = Position[family, a_ /; Max[Exponent[a, loops]] === 1, {1}];
  If[Length @ posL > 0,
   permuL = Tuples[ConstantArray[{1}, Length@family] // ReplacePart[#, posL -> {1, -1}] &],
   permuL = {ConstantArray[1, Length@family]};
   ];
  permuL
]


ClearAll[MatchFI];
Protect[MF, MissMatch];
MatchFI::missing = "target integral `1` is not matched in formlist.";
Options[MatchFI] := CreateOptions[{"ExactMode" -> False, "MatchFIHead" -> MF, Assumptions -> $Assumptions}, {Solve}];

MatchFI[target_List, formlist_List, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, MatchFI[target, formlist, loops, p["kinematics"], opt]]

MatchFI[target0 : Except[_List], ___] := target0

MatchFI[target0_List, formlist_List, loops_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, ctt, ctf, v, head, target, target1, formi, permuL, num1, num2, num3, x, tp1, tp2, tp3, ord1, ord2, eqs, tpInd, tpAsm, tpvars, varRules, sol, retu},

  {head} = {OptionValue["MatchFIHead"]};

  If[zeroSectorQ[target0, loops, kinematics], Return[0]];
  
  {target, ctt} = countProps[target0, loops, kinematics];
  permuL = EiknolPermutation[target, loops];
  
  For[num3 = 1, num3 <= Length @ permuL, num3++, target1 = target*permuL[[num3]];
  
   For[num1 = 1, num1 <= Length @ formlist, num1++,

    {formi, ctf} = countProps[formlist[[num1, 1]], loops, formlist[[num1, 4]]];
    If[Sort @ ctt =!= Sort @ ctf || Length @ loops =!= Length @ formlist[[num1, 2]], Continue[]];
    tp1 = SymanzikPolynomials[x, formi, Sequence @@ formlist[[num1, {2, 4}]]];
    ord1 = SymanzikOrder[Times @@ tp1, x];
    tpInd = SymanzikIndepentVars[tp1[[2]], x];
    tpAsm = Flatten @ {(# != 0 &) /@ tpInd};
    tpAsm = And @@ tpAsm;
    tpAsm = tpAsm && If[Length @ formlist[[num1]] === 5, formlist[[num1, 5]], True];
    (* tpvars = Complement[getS[tp1, _Symbol], formlist[[num1, 3]]]; *)
    tpvars = Complement[DeleteCases[getS[tp1], _x], formlist[[num1, 3]]];
    varRules = Thread[tpvars -> Array[v, Length @ tpvars]];
    {tp1, tpAsm} = {tp1, tpAsm} /. varRules;
    {tp1, tpAsm} = {tp1, tpAsm} /. Table[x[ord1[[1, i]]] -> x[i], {i, Length @ formi}];
    tpAsm = tpAsm && OptionValue[Assumptions];
    

    tp3 = SymanzikPolynomials[x, target1, loops, kinematics];
    ord2 = SymanzikOrder[Times @@ tp3, x];
    For[num2 = 1, num2 <= Length @ ord2, num2++,
     If[ctf[[ord1[[1]]]] =!= ctt[[ord2[[num2]]]], Continue[]];
     tp2 = tp3 /. Table[x[ord2[[num2, i]]] -> x[i], {i, Length@target}];
     eqs = Thread[Separate[Total[tp2 - tp1], _x][[1]] == 0];
     If[Union[eqs /. (Reverse /@ varRules)] === {True}, Return[Times @@ (permuL[[num3]]^ctt) * head[num1, {}]]];(*exact return*)
     If[! OptionValue["ExactMode"],
      If[$VersionNumber < 12.1,
       sol = Solve[eqs, Array[v, Length @ tpvars], FilterOptions[{opt}, Solve]](*//TimingS*);
       sol = DeleteCases[sol, x_ /; Reduce[tpAsm && (And @@ (x /. Rule -> Equal))] === False];
       ,
       sol = Solve[eqs, Array[v, Length @ tpvars], Assumptions -> tpAsm, FilterOptions[{opt}, Solve]](*//TimingS*)
       ],
      Continue[]
      ];
     If[
      sol =!= {},
      (*when there are variable with the same name in target and formi, they will be regard as the same, the ConditionalExpression may be undefined with False as condition like: x>0&&x<0*)
      sol = sol[[1]] /. (Reverse /@ varRules);
      sol = sol // Simplify[#, Assumptions -> (tpAsm /. (Reverse /@ varRules))] &(*//TimingS*);
      (*make sure no Undefined in retu and no duplicated indepedent variable after transform, idk whether the second condition is necessary...*)
      retu = Times @@ (permuL[[num3]]^ctt) * head[num1, sol];
      (*Print[retu];*)
      retu = Select[{retu}, FreeQ[#[[2]], Undefined] && DuplicateFreeQ[(FactorTermsList[#][[2]] &) /@ (tpInd /. Normal[getS[#, _head][[1]][[2]]])] &];
      If[retu =!= {}, Return[retu[[1]]]](*parameter rules return*)
      ]
     ]

    ]

   ];

  Message[MatchFI::missing, target0];
  MissMatch @@ target0
]