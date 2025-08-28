ApartFFS;

ClearAll[ApartFFS]
Options[ApartFFS] = {"ApartFFSSimplify" :> SimplifyS};
ApartFFS[deno_, loops_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 ApartFFS[deno, loops, ToExpression[process], opt]
ApartFFS[deno_, loops_List, process_Association, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 ApartFFS[deno, loops, process["moms"], process["kinematics"], opt]
ApartFFS[deno_, loops_List, moms_, SPRep_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{tp1, tp2, tp3},
  tp1 = ApartFF[ExpandMomentum[deno, moms], loops, FDS -> False] // FCES;
  tp2 = tp1 /. x_FAD | x_SFAD /; zeroSectorQ[x, loops, SPRep] :> 0;
  tp3 = tp2 // Separate[#, _FAD | _SFAD] &;
  tp3[[1]] = OptionValue["ApartFFSSimplify"] /@ tp3[[1]];
  tp3]