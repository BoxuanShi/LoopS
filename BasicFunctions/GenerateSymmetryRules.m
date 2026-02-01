ClearAll[GenerateSymmetryRules]
GenerateSymmetryRules[generators_, symbollist_] := Module[{tp1, tp2, tp3, tp4},
   tp1 = PermutationProduct /@ GroupElements[PermutationGroup[Cycles /@ generators]];
   tp2 = InversePermutation /@ tp1;
   tp3 = Table[
    MapThread[Rule, 
      {symbollist, symbollist[[PermutationReplace[Range @ Length @ symbollist, tp1[[i]]]]]},
      Length @ Dimensions @ symbollist] // Flatten // Union
    , {i, Length @ tp1}];
   tp4 = Table[
    MapThread[
      Rule, 
      {symbollist, symbollist[[PermutationReplace[Range @ Length @ symbollist, tp2[[i]]]]]},
      Length @ Dimensions @ symbollist] // Flatten // Union
    , {i, Length @ tp2}];
   <|"Rules" -> (AtomizeRules /@ tp3), "InvRules" -> (AtomizeRules /@ tp4)|>
  ];