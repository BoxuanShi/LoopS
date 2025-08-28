AMFInterface;

GToj[expr_] := 
 expr /. G[a_, b_] :> j[ToExpression["family" <> ToString[a]], Sequence @@ b]
jToG[expr_] := 
 expr /. j[a_, b___] :> 
   G[StringCases[ToString[a], NumberString][[1]] // ToExpression, {b}]

Clear[amfConventionTrans]
amfConventionTrans[rules_List, loops_, amforder_] := Module[{tp1, tp2},
  tp1 = rules[[All, 2]] /. eps -> \[Epsilon];
  tp2 = tp1*E^(\[Epsilon]*EulerGamma*Length@loops) // 
      Series[#, {\[Epsilon], 0, amforder - 2*Length@amforder}] & // Normal // 
    Expand;
  Thread[rules[[All, 1]] -> tp2] // jToG
  ]