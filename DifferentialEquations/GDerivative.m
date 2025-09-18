ClearAll[GDerivative];
GDerivative[expr_G, var_, family_, loops_List, 
  process_String : "CurrentProcess"] := 
 GDerivative[expr, var, family, loops, ToExpression[process]]
GDerivative[expr_G, var_, family_, loops_List, process_Association] :=
  GDerivative[expr, var, family, loops, process["loopmoms"], 
  process["kinematics"], process["moms"]]
GDerivative[expr_G, var_, family_, loops_List, loopmoms_, kinematics_,
   moms_] := 
 Module[{i, familyN, exprSPD, exprD, exprA, rules, coe, deno, Abbr},
  
  {familyN, exprSPD} = {expr[[1]], 
    GToProps[expr, family] // PropsToSPD // Times @@ #^-1 &};
  
  exprD = D[exprSPD, var];
  
  {exprA, rules} = AbbreviateDeno[exprD, "AbbreviateDenoName" -> Abbr];
  rules = 
   Thread[rules[[All, 
       1]] -> (rules[[All, 2]] /. SPD -> Times // #^-1 &)];
  
  {coe, deno} = Separate[exprA, _Abbr, "SeparateOperation" -> List];
  deno = deno /. Dispatch@rules;
  deno = 
   CountPropsInFamily[#, family[[familyN]], kinematics] & /@ deno;
  deno = deno[[All, 2]]*(G[familyN, #] & /@ deno[[All, 1]]);
  
  coe . deno // 
    ReduceSPDToG[#, family, loopmoms, kinematics, moms] & // 
   CollectS[#, _G, Factor] &
  ]