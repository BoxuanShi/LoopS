ClearAll[texRational]
texRational[expr_] := Module[{tp1, tp2, tpR},
  tp1 = getS@expr;
  tpR = Thread[tp1 -> (texH[#, texD] & /@ tp1)];
  tp2 = expr /. tpR /. {
     c_*Rational[a_, b_] /; a/b > 0 && FreeQ[c, Alternatives @@ tp1] :> 
      HoldForm[(a*c)/b],
     c_*Rational[a_, b_] /; a/b > 0 && ! FreeQ[c, Alternatives @@ tp1] :> 
      c*HoldForm[a/b],
     c_*Rational[a_, b_] /; 
       a/b < 0 && FreeQ[c, Alternatives @@ tp1] :> -HoldForm[
        Evaluate[-((a*c)/b)]],
     c_*Rational[a_, b_] /; a/b < 0 && ! FreeQ[c, Alternatives @@ tp1] :> -c*
       HoldForm[Evaluate[-(a/b)]]
     }
  ]