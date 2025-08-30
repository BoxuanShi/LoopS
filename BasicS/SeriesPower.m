SeriesPower;

ClearAll[SeriesPower, SeriesPower0]
SeriesPower[expr_, \[Lambda]__List] := 
 SeriesPower0[expr, "\[Lambda]" -> {\[Lambda]}]
Options[SeriesPower0] = {"\[Lambda]" -> "\[Lambda]"};
SeriesPower0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{a, \[Lambda], \[Lambda]1, \[Lambda]2, \[Lambda]3, para1, power1, 
   para2, para3, power2, power3, rules1, rules2, rules3, head, c, i, tp1, tp2,
    tp3},
  \[Lambda] = Sequence @@ OptionValue["\[Lambda]"];
  \[Lambda]1 = Select[{\[Lambda]}, #[[2]] == 0 &];
  \[Lambda]2 = Select[{\[Lambda]}, #[[2]] > 0 &];
  \[Lambda]3 = Select[{\[Lambda]}, #[[2]] < 0 &];
  {para1, power1} = If[\[Lambda]1 === {}, {{}, {}}, Transpose@\[Lambda]1];
  {para2, power2} = If[\[Lambda]2 === {}, {{}, {}}, Transpose@\[Lambda]2];
  {para3, power3} = If[\[Lambda]3 === {}, {{}, {}}, Transpose@\[Lambda]3];
  rules1 = {((para1[[#]]^a_Integer /; a > power1[[#]] :> 0) & /@ 
      Range[Length@para1]), (para1[[#]]^a_ :> head[c[#], a]) & /@ 
     Range[Length@para1], (para1[[#]] :> 0) & /@ 
     Range[Length@para1], (head[c[#], a_] :> para1[[#]]^a) & /@ 
     Range[Length@para1]};
  rules2 = (para2[[#]]^a_Integer /; a > power2[[#]] :> 0) & /@ 
    Range[Length@para2];
  rules3 = {((para3[[#]]^a_Integer /; a > power3[[#]] :> 0) & /@ 
      Range[Length@para3]), (para3[[#]]^a_ :> head[c[#], a]) & /@ 
     Range[Length@para3], (para3[[#]] :> 0) & /@ 
     Range[Length@para3], (head[c[#], a_] :> para3[[#]]^a) & /@ 
     Range[Length@para3]};
  tp1 = CollectFlat[expr,
             para1~Join~para2~Join~para3,
             # &,
             If[para3 =!= {} && FreeQ[#, Alternatives @@ para3], 0, #] &
             ] /. Dispatch@rules1[[1]] /. Dispatch@rules1[[2]] /. 
          Dispatch@rules1[[3]] /. Dispatch@rules1[[4]] /. Dispatch@rules2 /. 
       Dispatch@rules3[[1]] /. Dispatch@rules3[[2]] /. 
     Dispatch@rules3[[3]] /. Dispatch@rules3[[4]]
  ]
SetAttributes[SeriesPower0, Listable]