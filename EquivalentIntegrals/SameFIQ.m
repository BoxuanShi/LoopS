ClearAll[SameFIQ];
Options[SameFIQ] := CreateOptions[{}, {MatchFI, Solve}];

SameFIQ[target_List, formlist_List, loops_List, process_Association : CurrentProcess, opt : OptionsPattern[]] := SameFIQ[target, formlist, loops, process["kinematics"], opt]

SameFIQ[target0_List, formlist0_List, loops_List, kinematics_List, opt : OptionsPattern[]] := Module[{ctt, ctf, formlist, target, formi, num2, x, tp1, tp2, tp3, ord1, ord2, eqs, i},

   formlist = If[formlist0 === {} || Head@formlist0[[1]] =!= List, {formlist0, loops, getS@kinematics[[All, 1]], kinematics}, formlist0];
   
   If[zeroSectorQ[target0, loops, kinematics],
    If[zeroSectorQ[formlist[[1]], formlist[[2]], formlist[[4]]], Return[True], Return[False]]
    ];
   
   {target, ctt} = countProps[target0, loops, kinematics];
   {formi, ctf} = countProps[formlist[[1]], formlist[[2]], formlist[[4]]];
   
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