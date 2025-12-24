ClearAll[propsToLS, propsToLS0, LSToprops]
(*LSToprops would drop -1 power since \"{j,power[[i]]}\"*)
LSToprops[expr_, process_String : "CurrentProcess"] := LSToprops[expr, ToExpression[process]]
LSToprops[expr_, process_Association] := LSToprops[expr, process["kinematics"]]
LSToprops[expr_, kinematics_List] := Module[{power, i},
  power = Table[Which[Length@expr[[i]] == 3, 1, Length@expr[[i]] == 4, expr[[i, 4]], True, Print["wrong form"]; Abort[]], {i, Length@expr}];
  Table[If[expr[[i, 1]] === expr[[i, 2]], (#[[1]]*#[[2]] + #[[3]]) &@expr[[i]], Expand[(#[[1]]*#[[2]] + #[[3]]) &@expr[[i]]] /. kinematics], {i, Length@expr}, {j, power[[i]]}] // Flatten
  ]

propsToLS[expr_, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, propsToLS[expr, p["loopmoms"], p["kinematics"]]]
propsToLS[expr_, loopmoms_List, rules_List] := Module[{i, tp1, tp2},
  tp1 = propsToLS0[expr, "loopmoms" -> loopmoms, "rules" -> rules];
  If[! FreeQ[tp1, Rule], Return[tp1]];
  tp2 = tp1 // DeleteDuplicates[#, UnionS@Factor[#1 - #2] === {0} &] &;
  Table[Append[tp2[[i]], CountS[tp1, tp2[[i]]]], {i, Length@tp2}]
]

SetAttributes[propsToLS0, Listable]
Options[propsToLS0] = {"loopmoms" -> "loopmoms", "rules" -> "rules"};
propsToLS0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := Module[{loopmoms, rules, tpx1, tpx2, tpx3, tpx4, tpx5, tpx6, tpPos, i, j, x, lamb},
  {loopmoms, rules} = {OptionValue["loopmoms"], OptionValue["rules"]};
  tpx1 = expr /. Thread[loopmoms -> lamb*loopmoms];
  Switch[Exponent[tpx1, lamb],
    2,
    tpx2 = Table[
      If[
        i === j,
        Coefficient[tpx1, loopmoms[[i]]*loopmoms[[j]]], 1/2 Coefficient[tpx1, loopmoms[[i]]*loopmoms[[j]]]
        ]
      ,{i, Length@loopmoms}, {j, Length@loopmoms}];
    tpPos = FirstPosition[Diagonal@tpx2, x_ /; ! FreeQ[x, lamb], {1}][[1]];
    tpx3 = (Diagonal[tpx2]*loopmoms) . tpx2[[tpPos]] /. lamb -> 1 // CollectFlat[#, loopmoms, TogetherExpand]& // Expand;
    tpx4 = 1/2 * Coefficient[tpx1, loopmoms[[tpPos]]] /. Thread[loopmoms -> 0] /. lamb -> 1 // CollectFlat[#, loopmoms, TogetherExpand]& // Expand;
    tpx5 = (expr - (tpx3 + tpx4)^2 // TogetherExpand) /. rules // TogetherExpand;
    If[! FreeQ[tpx5 /. Thread[loopmoms -> lamb*loopmoms] // Together, lamb], 
    Return["Wrong propagator" -> expr], 
    Return[{tpx3 + tpx4, tpx3 + tpx4, tpx5}]],
    1,
    tpx2 = Coefficient[expr, loopmoms];
    tpx3 = FirstCase[tpx2, x_ /; x =!= 0] // CollectFlat[#, loopmoms, TogetherExpand]& // Expand;
    tpx4 = tpx2 . loopmoms/tpx3 // TogetherExpand;
    tpx5 = (expr - tpx4*tpx3 // TogetherExpand) /. rules // TogetherExpand;
    tpx6 = {tpx4, tpx3, tpx5},
   
    _,
    Return["Wrong propagator" -> expr];
    ]
  ]