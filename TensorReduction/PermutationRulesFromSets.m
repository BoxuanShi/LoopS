PermutationRulesFromSets;

(*to generate dummy indices in different fermion lines*)

ClearAll[PermutationRulesFromSets(*,tp1,tp2,tp3,tp4,tp5*)]
PermutationRulesFromSets[si___List] := 
 Module[{tp1, tp2, tp3, tp4, tp5, i, j},
  tp1 = Flatten@{si};
  If[DuplicateFreeQ@tp1 === False, 
   Print["PermutationRulesFromSets: input is wrong!"]; Abort[]];
  tp2 = Permutations@tp1;
  tp4 = {si} /. Thread[tp1 -> Range@Length@tp1];
  tp3 = Table[
    Select[tp2[[i]], MemberQ[{si}[[j]], #] &], {i, Length@tp2}, {j, 
     Length@tp4}];
  tp5 = TableS[If[tp3[[i]] =!= {si}, Nothing, tp2[[i]]], {i, Length@tp2}];
  (inverseRule[Thread[tp1 -> #], tp1] &) /@ tp5
  ]  