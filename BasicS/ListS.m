ListS;

ClearAll[ListS]
ListS[expr_, var0_List : {}, head_Symbol : Plus] := Module[{var, tp1, tp2},
  tp1 = If[Head@expr === head, List @@ expr, {expr}];
  var = Flatten@{var0};
  
  If[
   var === {},
   tp1,
   
   tp2 = Select[tp1, FreeQ[#, Alternatives @@ var] &];
   {head @@ tp2}~Join~Complement[tp1, tp2]
   ]
  ]