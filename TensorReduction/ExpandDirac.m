ClearAll[DiracTraceExpand, DiracTraceExpand0]
DiracTraceExpand[expr_] := getDo[FCES@expr, _DiracTrace, DiracTraceExpand0]
DiracTraceExpand0[expr_DiracTrace] := Module[{i, tp1},
  tp1 = expr[[1]];
  tp1 = ListS@TogetherExpand@tp1;
  tp1 = Table[Separate[tp1[[i]], _Dot | _GAD | _GSD], {i, Length@tp1}];
  tp1[[All, 2]] = Table[DiracTrace /@ tp1[[i, 2]], {i, Length@tp1}];
  Total[Dot @@@ tp1]
  ]


ClearAll[ExpandMomentum]
ExpandMomentum::usage = 
  "ExpandMomentum[expr_,moms_:moms] factor out non-momentum parameter in \
Momentum[a_*p,D]->a*Momentum[p,D] according to Momentum list \"moms\"";
ExpandMomentum[expr_, process_String : "CurrentProcess"] := 
 ExpandMomentum[expr, ToExpression[process]]
ExpandMomentum[expr_, process_Association] := 
 ExpandMomentum[expr, process["moms"]]

ExpandMomentum[expr_, moms_List] := Module[{expsingleMom},
  
  If[moms === {}, Return[expr]];
  
  expsingleMom[momarg_, d___] := Module[{i, tp0, momarg2, vs, coe},
    If[FreeQ[momarg, Alternatives @@ moms], Return[Momentum[momarg, d]]];
    momarg2 = ListS@Expand@momarg;
    vs = Variables /@ momarg2;
    vs = Intersection[moms, #] & /@ vs;
    If[Union[Length /@ vs] =!= {1}, 
     Print["Wrong momenta power in Momentum[" <> ToString[momarg] <> ",D]."]; 
     Abort[]];
    coe = Table[Coefficient[momarg2[[i]], vs[[i, 1]]], {i, Length@vs}];
    coe . (Momentum[#, D] & /@ Flatten[vs])
    ];
  
  FCI[expr] /. Momentum[momarg_, d___] :> expsingleMom[momarg, d]
  ]


ClearAll[ExpandDirac]
ExpandDirac[expr_] := 
 expr // DiracGammaExpand // ExpandScalarProduct // DotExpand(*//FCES*)// 
  DiracTraceExpand