ClearAll[ReplaceSymmetryG]
ReplaceSymmetryG[expr_, symRules_Association, rules__] := 
 Fold[ReplaceSymmetryG[#1, symRules, #2] &, expr, {rules}]
ReplaceSymmetryG[expr_, symRules_Association, rules_List | rules_Dispatch] := 
 Module[{tp1},
  expr /. 
   G[a_, b_, 
     c_] :> (G[a, b] /. rules /. G[e_, f_] :> G[e, f, c] /. 
      symRules["Rules"][[c]])
  ]