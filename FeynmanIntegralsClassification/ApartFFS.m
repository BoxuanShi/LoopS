ClearAll[ApartFFS]
ApartFFS::UserDefinedApartFFS = "Detected uncorrect UserDefinedApartFFS rule `1`.";
Options[ApartFFS] = {"ApartFFSSimplify" :> SimplifyS, "UserDefinedApartFFS" -> Association[]};
ApartFFS[deno_, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, ApartFFS[deno, loops, p["moms"], p["kinematics"], opt]]
ApartFFS[deno_, loops_List, moms_, SPRep_List, opt : OptionsPattern[]] := Module[{tpuser, x, y, tp1, tp2, tp3},
  If[tpuser = OptionValue["UserDefinedApartFFS"][deno]; !MatchQ[tpuser, _Missing],
    If[MatchQ[tpuser, {x_List, y_List} /; Length@x === Length@y] && (deno - Dot @@ tpuser // FeynAmpDenominatorExplicit // ExpandMomentum // FCES // Together) === 0,
      Nothing,
      Message[ApartFFS::UserDefinedApartFFS, {deno -> tpuser}]
      ];
    Return[tpuser]
   ];
  tp1 = ApartFF[ExpandMomentum[deno, moms], loops, FDS -> False] // FCES;
  tp2 = tp1 /. x_FAD | x_SFAD /; zeroSectorQ[x, loops, SPRep] :> 0;
  tp3 = tp2 // Separate[#, _FAD | _SFAD] &;
  tp3[[1]] = OptionValue["ApartFFSSimplify"] /@ tp3[[1]];
  tp3
]