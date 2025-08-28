generateSymmetryRules;

(*generate symmetry transformation rules for permutation group generators \
{(1,2),(3,4),(1,3)(2,4)...}, the second arguement is the corresponding \
variables of "1, 2, 3, 4..."*)

ClearAll[generateSymmetryRules]
generateSymmetryRules[generators_, symbollist_] := 
  Module[{i, j, num, tp1, tp2, tp3, tp4},
   tp1 = PermutationProduct /@ 
     GroupElements[PermutationGroup[Cycles /@ generators]];
   tp2 = InversePermutation /@ tp1;
   tp3 = Table[
     MapThread[
        Rule, {symbollist, 
         symbollist[[PermutationReplace[Range@Length@symbollist, tp1[[i]]]]]},
         Length@Dimensions@symbollist] // Flatten // Union
     , {i, Length@tp1}];
   tp4 = Table[
     MapThread[
        Rule, {symbollist, 
         symbollist[[PermutationReplace[Range@Length@symbollist, tp2[[i]]]]]},
         Length@Dimensions@symbollist] // Flatten // Union
     , {i, Length@tp2}];
   {tp3, tp4}];

(*example, we used this rule in pion EMFF*)

(*generateSymmetryRules[{{{1,2}},{{3,4}},{{1,3},{2,4}}},{{x1,p1},{x2,p2},{y1,\
p3},{y2,p4}}]*)