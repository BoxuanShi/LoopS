ClearAll[FormDo];
Protect[formv, formPi];
FormDo[expr_, func_ : (# &)] := Module[{i, vars, rules, tp1, q, dot},
  vars = Variables[expr];
  rules = 
   Thread[vars -> 
     Table[ToExpression[ToString[formv] <> ToString[i]], {i, Length@vars}]];
  rules = Join[rules, {\[Pi] -> formPi}];
  tp1 = expr /. Dot -> dot /. Dispatch[rules /. Dot -> dot];
  tp1 = func[tp1];
  tp1 /. Dispatch[Reverse /@ (rules /. dot -> Dot)]
  ]