ClearAll[CanonicalLoops]
Options[CanonicalLoops] = {"DiscVariables" -> {}};
CanonicalLoops[props0_List, loops_List, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, CanonicalLoops[props0, loops, p["extmomsind"], p["kinematics"], Evaluate@opt]]
CanonicalLoops[props0_List, loops_List, extmomsind_List, kinematics_List, opt : OptionsPattern[]] := Module[{i, x, props, tp1x1, sqpart0, lipart0, sqpart, lipart, lipart2, signs, tp2x1, tp3, tp4, tp5, tp6, tp7, tp7x, tp7x2, tp7x3, tp8, tp9, pow1, pow2, momsind, DV, sortf},
  momsind = Join[loops, extmomsind];
  props = props0(*//TogetherExpand*);
  (*for squared propagator, return loopSymmetryNoPS*)
  If[AllTrue[props, #[[1]] === #[[2]] &], Return[loopSymmetryNoPS[props, loops, momsind]]];
  (*separate linear propagators*)
  {sqpart0, lipart0} = props // GatherBy[#, Length@Union@#[[1 ;; 2]] &] & // SortBy[#, Length@Union@#[[1, 1 ;; 2]] &] &;
  (*square propagator part*)
  sqpart = sqpart0 // loopSymmetryNoPS[#, loops, momsind] &;
  (*linear propagator part*)
  signs = Tuples[{1, -1}, Length@lipart0];(*generate 1 or -1 sign for each linear propagator*)
  lipart2 = LSToprops[lipart0, kinematics];
  lipart = lipart2 // DeleteDuplicates;
  lipart = (lipart*#) & /@ signs;
  tp3 = lipart /. sqpart[[2]] // Expand // # /. kinematics &(*since Togetherexpand is used in PropsToM*);
  tp4 = Map[Sort, PropsToM[tp3, loops, extmomsind, kinematics], {2}];
  tp5 = Table[Flatten@Table[tp4[[i, j, k]][[1 ;; -2]], {k, Length@tp4[[i, j]]}], {i, Length@tp4}, {j, Length@tp4[[i]]}];
  tp6 = Table[Table[tp4[[i, j, k]][[-1]], {k, Length@tp4[[i, j]]}], {i, Length@tp4}, {j, Length@tp4[[i]]}];
  tp7 = Table[{{i, signs[[j]], tp3[[i, j]]}, tp5[[i, j]], tp6[[i, j]]}, {i, Length@tp4}, {j, Length@tp4[[i]]}];
  tp7 = tp7 // Flatten[#, 1] &;
  (*discvariables*)
  DV = OptionValue["DiscVariables"];
  If[DV === {},
    sortf[x_] := {(Length@DeleteCases[x[[2]], 0]), (-Abs[x[[2]]]), (Not /@ Positive /@ (x[[2]])), (Not /@ Negative /@ (x[[2]])), x[[3]], x[[2]]}
    ,
    DV = Flatten@{DV};
    sortf[x_] := {(-Coefficient[#, DV] &) /@ x[[3]] // Expand // Sort, (Length@DeleteCases[x[[2]], 0]), (-Abs[x[[2]]]), (Not /@ Positive /@ (x[[2]])), (Not /@ Negative /@ (x[[2]])), x[[3]], x[[2]]}
    ];
  tp7x = tp7 // SortBy[#, sortf] &;
  tp7x2 = tp7x // SplitBy[#, sortf] &;
  tp7x3 = If[Length@Union@tp7x2[[1, All, 2]] =!= 1, Print["can not find unique linear propagator form."]; Abort[], tp7x2[[1,1 ;; 1, 1]]];
  tp8 = propsToLS[tp7x3[[1, 3]], loops, kinematics] // Sort;
  (*to fix a bug in loopSymmetryNoPS, the current rules for handling squared propagators are only valid in the absence of linear propagators.The current implementation of the unique form does not take into account the power of the propagators. As a result, loop momenta like l1 and l2 may be exchanged under different rules which leads to equivalent expressions only in the case where all propagators are quadratic. However, in the presence of linear propagators, such transformations are not valid, and this causes incorrect symmetry identification.*)
  tp9 = Join[sqpart[[1]], tp8];
  tp2x1 = tp9 // LSToprops[#, kinematics] & // DeleteDuplicates;
  tp1x1 = LSToprops[props /. sqpart[[2, tp7x3[[1, 1]]]], kinematics];
  pow1 = Count[Together[tp1x1 - #], 0] & /@ tp2x1;
  pow2 = Count[Together[tp1x1 + #], 0] & /@ tp2x1;
  signs = If[# === 0, -1, 1] & /@ pow1;
  tp9 = Transpose[Append[Transpose@tp9[[All, 1 ;; 3]], pow1 + pow2]];
  
  {tp9, sqpart[[2, tp7x3[[All, 1]]]], signs}
  ]

