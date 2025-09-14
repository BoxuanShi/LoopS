ClearAll[AtomizeRules, inverseRule]
AtomizeRules[rules0_, vars0_ : Automatic] := 
 Module[{rules, vars, eqns, sol, tp1, v, dot}, 

  rules = Flatten @ {rules0};
  vars = 
   If[vars0 === Automatic, Variables[rules[[All, 1]]], 
    Flatten@{vars0}];
  If[vars === {}, Return[{}]];

  (* If[Length@vars =!= Length@rules, 
   Print["AtomizeRules: Wrong input, the length of rules and vars is \
unequal."]; Abort[]]; *)

  eqns = 
   rules[[All, 1]] /. Dot -> dot /. 
    Thread[(vars /. Dot -> dot) -> Array[v, Length[vars]]];
  eqns = Equal @@@ Thread[eqns -> rules[[All, 2]]];
  sol = Solve[eqns, Array[v, Length[vars]]];

  If[sol === {}, 
   Print["AtomizeRules: solution is NONE, check whether all changed \
variables are included in \"vars\"."]; Abort[]];
  sol = sol[[1]] /. Dispatch @ Thread[Array[v, Length[vars]] -> vars];
  tp1 = Union[Factor[(rules[[All, 1]] /. sol) - rules[[All, 2]]]];

  If[tp1 =!= {0}, 
   Print["AtomizeRules: solution is WRONG, check whether all changed \
variables are included in \"vars\"."]; Abort[]];

  sol]

inverseRule[rules_, vars_] := AtomizeRules[Reverse /@ rules, vars]


ClearAll[recurRules]
recurRules[expr_, rules_, condi_ : (True &)] := Module[{tp1, tp2, num},
  tp1 = expr /. rules;
  For[num = 1; tp2 = tp1, (num <= Length@rules) && (! condi[tp2]), num++,
   tp2 = expr /. rules[[num]] ];
  If[condi[tp2] =!= True, Print["no rules make condition satisfied."]; tp1, 
   tp2]
  ]