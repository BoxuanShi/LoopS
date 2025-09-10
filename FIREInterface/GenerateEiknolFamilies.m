ClearAll[GenerateEiknolFamilies]
GenerateEiknolFamilies[family_List, MIs_List, loops_List] := 
 Module[{y, i, j, tpPermu, familyEiknol, nfamEki, signEki, tpMap, tpMapInv, 
   tpInvRules, MIsEkinol, tp1, hd},
  tpPermu = Table[EiknolPermutation[family[[i]], loops], {i, Length@family}];
  signEki = Flatten[tpPermu, 1];
  
  familyEiknol = Table[family[[i]]*# & /@ tpPermu[[i]], {i, Length@family}];
  nfamEki = Length /@ familyEiknol;
  familyEiknol = Flatten[familyEiknol, 1];
  
  tpMap = 
   Table[Total@nfamEki[[1 ;; i - 1]] + j, {i, Length@nfamEki}, {j, 
     nfamEki[[i]]}];
  tpMapInv = Table[Thread[tpMap[[i]] -> i], {i, Length@tpMap}] // Flatten;
  tpInvRules = 
   tpMapInv /. (a_ -> b_) :> {G[a, y_], hd[signEki[[a]], y]*G[b, y]};
  tpInvRules = RuleDelayed @@@ tpInvRules;
  tpInvRules = tpInvRules /. hd -> (Times @@ (#1^#2) &);
  
  tp1 = GatherGInFamily[MIs, family];
  MIsEkinol = 
   Table[tp1[[i]] /. Dispatch[G[x_, y_] :> G[tpMap[[i, j]], y]], {i, 
      Length@tp1}, {j, nfamEki[[i]]}] // Flatten;
  {familyEiknol, MIsEkinol, tpInvRules}
  ]