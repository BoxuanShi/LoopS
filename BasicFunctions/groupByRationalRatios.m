ClearAll[groupByRationalRatios, groupByRationalRatios2]
groupByRationalRatios::usage = 
  "there are two modes of groupByRationalRatios[matrix, pre0, inverseQ]. 
i. pre0 is a number which limits the sum of numerator and denominator of the \
rational number, pre0 has default value: \!\(\*SuperscriptBox[\(10\), \(3\)]\);
ii. pre0 is a list, which limits the possible rational number appearing. 
for the case ii, groupByRationalRatios automatically includes the 1/pre0 list \
(inverseQ has default value: True)";
groupByRationalRatios[mat_?MatrixQ, pre0_ : 10^3, inverseQ_ : True] := 
 Module[{pre, preR, rg, condi, i, i2, j, tp1, tp2, tp3, tp4, tp5, group1, 
   group2, group0},
  pre = If[Head@pre0 === List, 
    If[True, UnionS@Flatten@Simplify@{pre0, 1/pre0}, pre0], pre0];
  preR = Min@Map[Precision, mat[[All, 1]]];
  condi[x_] := 
   And[x =!= 0, Head@x === Integer || Head@x === Rational, 
    Total@NumeratorDenominator@Abs@x < pre];
  rg = Flatten@Position[mat, a_List /; UnionS@a =!= {0}, {1}];
  group1 = TableS[
    tp1 = Rationalize[mat/mat[[rg[[i]]]][[1]], 10^(-preR + 5)];
    tp2 = 
     If[Head@pre =!= List, Flatten@tp1 // Select[#, condi] & // UnionS, pre];
    tp2 = UnionS@Flatten@{1, tp2};
    tp3 = Position[tp1, #, {2}] & /@ tp2;
    tp4 = 
     Table[Append[tp3[[i2, j]], tp2[[i2]]], {i2, Length@tp3}, {j, 
          Length@tp3[[i2]]}] // Flatten[#, 1] & // 
       SortBy[#, {#[[1]] =!= rg[[i]], #[[2]]} &] & // Transpose
    , {i, Length@rg}];
  tp5 = Complement[Range@Length@mat, rg];
  group0 = {{tp5, ConstantArray[1, Length@tp5], ConstantArray[0, Length@tp5]}};
  group1~Join~group0
  ]
groupByRationalRatios2::usage = 
  "groupByRationalRatios2[group1_?MatrixQ,symlist_List] further reduce \
group1.
i. select certain sym relation from the full group1.
ii. retain only one independent set.
iii. several check.";
groupByRationalRatios2[group1_List, symlist_List] := 
 Module[{i, group2, group3, group4},
  group2 = 
   Table[group1[[i]] // Transpose // 
      DeleteCases[#, a_ /; ! MemberQ[symlist, a[[2]]]] & // Transpose, {i, 
     Length@group1}];
  group3 = GatherBy[group2, UnionS[#[[1]]] &];
  (*check 1 - consistency in every group*)
  Print["consistency in every group -> ", 
   Table[Length@Union[Sort /@ group3[[i]][[All, 1]]], {i, Length@group3}] === 
    ConstantArray[1, Length@group3]];
  (*check 2 - no overlap between different group*)
  Print["no overlap between different group -> ", 
   Intersection @@ group3[[All, 1, 1]] === {}];
  (*check 3 - all group have 12 symmetries*)
  Print["all group symmetries -> ", Union[Union /@ group3[[All, 1, 2]]]];
  group4 = group3[[All, 1]];
  Table[Transpose@Sort@Transpose@group4[[i]], {i, Length@group4}]
  ]