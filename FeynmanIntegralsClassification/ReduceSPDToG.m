ClearAll[ReduceSPDToG, De2GRules]
ReduceSPDToG::usage = 
  "ReduceSPDToG[expr0_,familylist_,moms_:moms] can transform an expr with \
SPD[_,_]*G[_,_] or {SPD[_,_],G[_,_]} into pure G.";
ReduceSPDToG[expr0_, familylist_, process_String : "CurrentProcess"] := 
 ReduceSPDToG[expr0, familylist, ToExpression[process]]
ReduceSPDToG[expr0_, familylist_, process_Association] := 
 ReduceSPDToG[expr0, familylist, process["loopmoms"], process["kinematics"], 
  process["moms"]]
ReduceSPDToG[expr0_, familylist_, loopmoms_, kinematics_, moms_] := 
 Module[{expr, tp1, tp2, tp3, tp1f, num},

  If[FreeQ[expr0, G] && expr0 =!= 0,
   If[familylist == {}, Return[expr0],
    Print["No G[___] provided."]; Abort[]],
   If[familylist == {}, Print["familyLS is empty."]; Abort[]]
   ];
  
  (*expr=If[Head@expr0===List,Times@@expr0,expr0];*)
  expr = expr0 // ExpandMomentum[#, moms] & // ExpandDirac;(*to fix a bug SPD[
  l1,y*p] -> y SPD[l1,p]*)
  (*expr=expr/.x:_SPD/;FreeQ[x,Alternatives@@loopmoms]:>spd@@
  x;*)(*to make spd[extmomind,extmomind] consistent*)
  
  If[! FreeQ[tp2 = Denominator@ListS@expr0, SPD], 
   Print["There is SPD in the denominator." -> tp2]; Abort[]];
  
  tp1f[expr1_, G0_] := Module[{tp4, tpcoe, tpSPD, tp5, tp6, tp7, tp8, tp9},
    tp4 = FindnumRules[familylist[[G0[[1]]]], loopmoms, kinematics, moms];
    tp8 = expr1*G0 /. tp4;
    tp9 = De2GRules@tp8;
    If[! FreeQ[tp9, De2], Print["De2 still exist in " -> tp9]; Abort[]];
    tp9
    ];
  
  tp1 = Which[
    MatchQ[expr, {{_, _G}, ___}],
    expr,
    MatchQ[expr, {_, _G}],
    {expr},
    True,
    Transpose@Separate[expr, _G]
    ];
  
  Sum[tp1f[tp1[[num, 1]], tp1[[num, 2]]], {num, Length@tp1}]
  ]

De2GRules[expr_] := Module[{tp1, tp2},
  CollectS[
   expr, _G | _De2,
   # &, # //. {De2[a_]^c_*G[famno_, b_, d___] :> 
       G[famno, ReplacePart[b, a :> b[[a]] - c], d], 
      De2[a_]*G[famno_, b_, d___] :> 
       G[famno, ReplacePart[b, a :> b[[a]] - 1], d]} &
   ]
  ]