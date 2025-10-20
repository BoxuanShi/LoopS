ClearAll[countProps]
countProps[props_List, loops_List] := Module[{i, x, props1, props2, inv, ct, largePowPos, largePowProps},
  props1 = Union @ props;
  inv = Table[If[FreeQ[Denominator @ props1[[i]], Alternatives @@ loops], 1, -1], {i, Length @ props1}];
  ct = Count[TogetherExpand[props - #], 0] & /@ props1;
  props2 = props1^inv;
  (*in the case high power of linear propagator appear, 
  treat them as indepdent ones.*)
  largePowPos = Position[ct, x_ /; Abs[x] > 1] // Flatten;
  largePowProps = props2[[largePowPos]];
  If[! FreeQ[linearPropsQ[#, loops] & /@ largePowProps, True],
   props1 = props;
   inv = Table[If[Denominator @ props1[[i]] =!= 1, -1, 1], {i, Length @ props1}];
   ct = ConstantArray[1, Length @ props1];
   props2 = props1^inv;
   ];
  If[Total @ ct =!= Length @ props, Print["countProps: count wrong."]; Abort[]];
  {props2, ct*inv}
  ]


(*if there are variables in formlist and target with the same name, \
they will be trade as the same variable in the conditional expression \
finally...*)

ClearAll[EiknolPermutation]
EiknolPermutation[family_List, loops_List] := Module[{posL, permuL},
  posL = Position[family, a_ /; Max[Exponent[a, loops]] === 1, {1}];
  If[Length @ posL > 0,
   permuL = Tuples[ConstantArray[{1}, Length@family] // ReplacePart[#, posL -> {1, -1}] &],
   permuL = {ConstantArray[1, Length@family]};
   ];
  permuL
  ]


ClearAll[matchFI];
Protect[MissMatch, \[Delta]\[Delta]];
matchFI::version = "Mathematica version is less than 12.1, matchFI may gives divergent result.";
Options[matchFI] := CreateOptions[{"ExactMode" -> False, "Head" -> MF, Assumptions -> $Assumptions, "FailedReturn" -> Automatic, "matchFILog" -> False}, {Solve}];
matchFI[target_List, formlist_List, loops_List, process_String : "CurrentProcess", opt : OptionsPattern[]] := matchFI[target, formlist, loops, ToExpression[process], opt]
matchFI[target_List, formlist_List, loops_List, process_Association, opt : OptionsPattern[]] := matchFI[target, formlist, loops, process["kinematics"], opt]
matchFI[target0_?(Head@# =!= List &), ___] := target0
matchFI[target0_List, formlist_List, loops_List, kinematics_List, opt : OptionsPattern[]] := Module[{ctt, ctf, v, head, target, target1, formi, failedreturn, permu, permuL, num1, num2, num3, x, tp1, tp2, tp3, ord1, ord2, eqs, tpInd, tpAsm, tpvars, varRules, sol, optSolve, retu, i},

  {head, failedreturn} = {OptionValue["Head"], OptionValue["FailedReturn"]};
  If[zeroSectorQ[target0, loops, kinematics], Return[0]];
  
  {target, ctt} = countProps[target0, loops];
  permuL = EiknolPermutation[target, loops];
  
  For[num3 = 1, num3 <= Length @ permuL, num3++, target1 = target*permuL[[num3]];
  
   For[
    num1 = 1, num1 <= Length @ formlist, num1++,
    {formi, ctf} = countProps[formlist[[num1, 1]], loops];
    If[Sort@ctt =!= Sort @ ctf || Length @ loops =!= Length @ formlist[[num1, 2]], Continue[]];
    
    tp1 = SymanzikPolynomials[x, formi, Sequence @@ formlist[[num1, {2, 4}]]];
    ord1 = SymanzikOrder[Times @@ tp1, x];
    tpInd = SymanzikIndepentVars[tp1[[2]], x];
    
    tpAsm = Flatten @ {(# != 0 &) /@ tpInd};
    tpAsm = And @@ tpAsm;
    tpAsm = tpAsm && If[Length@formlist[[num1]] === 5, formlist[[num1, 5]], True];
    
    tpvars = Complement[getS[tp1, _Symbol], formlist[[num1, 3]]];
    varRules = Thread[tpvars -> Array[v, Length@tpvars]];
    {tp1, tpAsm} = {tp1, tpAsm} /. varRules;
    {tp1, tpAsm} = {tp1, tpAsm} /. Table[x[ord1[[1, i]]] -> x[i], {i, Length@formi}];
    
    tpAsm = tpAsm && OptionValue[Assumptions];
    
    tp3 = SymanzikPolynomials[x, target1, loops, kinematics];
    ord2 = SymanzikOrder[Times @@ tp3, x];
    
    For[
    
     num2 = 1, num2 <= Length @ ord2, num2++,
     If[ctf[[ord1[[1]]]] =!= ctt[[ord2[[num2]]]], Continue[]];
     
     tp2 = tp3 /. Table[x[ord2[[num2, i]]] -> x[i], {i, Length@target}];
     eqs = Thread[Separate[Total[tp2 - tp1], _x][[1]] == 0];
     If[Union[eqs /. (Reverse /@ varRules)] === {True}, Return[head[num1, {}]]];(*exact return*)
     
     If[! OptionValue["ExactMode"],
      If[
       OptionValue[Assumptions] === True && Length @ formlist[[num1]] === 4,
       optSolve = Sequence[],
       optSolve = FilterOptions[{opt}, Solve]];
      If[$VersionNumber < 12.1,
       sol = Solve[eqs, Array[v, Length @ tpvars], optSolve](*//TimingS*);
       Message[matchFI::version]
       ,
       sol = Solve[eqs, Array[v, Length @ tpvars], Assumptions -> tpAsm, optSolve](*//TimingS*)
       ],
      Continue[]
      ];(*solve parameter rules*)
     
     If[
      sol =!= {},
      (*when there are variable with the same name in target and formi, they will be regard as the same, the conditional expression may be undefined like: x>0&&x<0*)
      sol = sol[[1]] /. (Reverse /@ varRules);
      sol = sol // Simplify[#, Assumptions -> (tpAsm /. (Reverse /@ varRules))] & // DeleteCases[#, x -> x] &(*//TimingS*);
      (*make sure no Undefined in retu and no duplicated indepedent variable after transform, 
      idk whether the second condition is necessary...*)
      retu = Times @@ permuL[[num3]]*head[num1, sol];
      (*Print[retu];*)
      retu = Select[{retu}, FreeQ[#[[2]], Undefined] && DuplicateFreeQ[(FactorTermsList[#][[2]] &) /@ (tpInd /. Normal[getS[#, _head][[1]][[2]]])] &];
      If[retu =!= {}, Return[retu[[1]]]](*parameter rules return*)
      ]

     ]

    ]

   ];

  If[OptionValue["matchFILog"], Print["No match" -> target]];
  Return[If[failedreturn === Automatic, MissMatch @@ target0, failedreturn]]
  ]