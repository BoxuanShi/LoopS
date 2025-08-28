sameFIQ;

ClearAll[sameFIQ];
Options[sameFIQ] := CreateOptions[{}, {matchFI, Solve}];
sameFIQ[target_List, formlist_List, loops_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 sameFIQ[target, formlist, loops, ToExpression[process], opt]
sameFIQ[target_List, formlist_List, loops_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 sameFIQ[target, formlist, loops, process["kinematics"], opt]
sameFIQ[target0_List, formlist0_List, loops_List, kinematics_List, 
    opt : OptionsPattern[]] /; OptRestrict[opt] := 
  Module[{ctt, ctf, v, head, formlist, target, target1, formi, propsL, 
    failedreturn, permu, permuL, num1, num2, num3, x, tp1, tp2, tp3, ord1, 
    ord2, eqs, tpInd, tpAsm, tpvars, varRules, sol, optSolve, retu, i},
   
   formlist = 
    Which[formlist0 === {}, {formlist0, loops, getS@kinematics[[All, 1]], 
      kinematics}, 
     Head@formlist0[[1]] =!= List, {formlist0, loops, 
      getS@kinematics[[All, 1]], kinematics}, True, formlist0];
   
   If[zeroSectorQ[target0, loops, kinematics],
    If[zeroSectorQ[formlist[[1]], formlist[[2]], formlist[[4]]], Return[True],
      Return[False]]
    ];
   
   {target, ctt} = countProps[target0, loops];
   {formi, ctf} = countProps[formlist[[1]], loops];
   
   If[Sort@ctt =!= Sort@ctf, Return[False]];
   
   tp1 = SymanzikPolynomials[x, formi, Sequence @@ formlist[[{2, 4}]]];
   ord1 = SymanzikOrder[Times @@ tp1, x];
   
   tp1 = tp1 /. Table[x[ord1[[1, i]]] -> x[i], {i, Length@formi}];
   
   tp3 = SymanzikPolynomials[x, target, loops, kinematics];
   ord2 = SymanzikOrder[Times @@ tp3, x];
   
   For[
    num2 = 1, num2 <= Length@ord2, num2++,
    If[ctf[[ord1[[1]]]] =!= ctt[[ord2[[num2]]]], Continue[]];
    
    tp2 = tp3 /. Table[x[ord2[[num2, i]]] -> x[i], {i, Length@target}];
    eqs = Thread[Separate[Total[tp2 - tp1], _x][[1]] == 0];
    If[Union@Factor@eqs === {True}, Return[True]];
    
    ];
   
   Return[False]
   
   ];