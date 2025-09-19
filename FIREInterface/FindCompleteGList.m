ClearAll[SubSectors]
SubSectors[g0_G, loops_List] := Module[{i, vec, pos, subpos, tp1, tp2},
  vec = tosector[g0][[2]];
  pos = Position[vec, 1, {1}];
  subpos = Subsets[pos, {Length@loops, Length@pos}];
  tp1 = ConstantArray[0, Length@vec];
  tp2 = Table[ReplacePart[tp1, subpos[[i]] -> 1], {i, Length@subpos}];
  
  (g0[[0]][g0[[1]], #] &) /@ tp2
  ]


ClearAll[FindTopSectors]
Options[FindTopSectors] = {"FindTopSectorsMaxIt" -> 
   500}; FindTopSectorsMaxIt;
FindTopSectors[Glist_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{num, tp1, tp2, tp3, tp4, maxc},
  maxc = OptionValue["FindTopSectorsMaxIt"];
  Monitor[
   For[
    num = 1; tp4 = {}; tp1 = Glist // tosector // Union,
    tp1 =!= {} && num <= maxc, num++,
    
    tp2 = Total /@ tp1[[All, 2]] // Max;
    tp3 = tp1 // Select[#, propNumG[#] === tp2 &] &;
    tp4 = {tp4, tp3} // Flatten // Union;
    tp1 = 
     tp1 // DeleteCases[#, 
        a_ /; (Or @@ Table[subsectorQ[tp3[[i]], a], {i, Length@tp3}])] &
    ],
   "FindTopSectors: " <> ToString[num] <> " of " <> ToString[maxc]];
  
  If[num >= maxc, Print["FindTopSectors: maximum recursion reached."]; 
   Abort[]];

  tp4
  ]


ClearAll[FindCompleteGList]
FindCompleteGList::usage = 
  "rx: Total of positive index (0 means no constraint), sx: minimum and \
maximum index, dx: minimum and maximum sum of total negative and enhanced \
index.";
Options[FindCompleteGList] := 
 CreateOptions[{"PossibleIntForDEInSector" -> False, "DropZeroSectorQ" -> True, 
   "Parallelization" -> False}, {TableS, FindTopSectors}];
FindCompleteGList[topsec0_List, family_List, loops_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FindCompleteGList[topsec0, family, loops, rx, sx, dx, ToExpression[process], 
  Evaluate@opt]
FindCompleteGList[topsec0_List, family_List, loops_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FindCompleteGList[topsec0, family, loops, rx, sx, dx, process["kinematics"], 
  Evaluate@opt]

FindCompleteGList[topsec0_List, family_List, loops_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, kinematics_List, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, topsec, sectors, tp1, tp2, opttable, optFTS, PIFD},
  
  Print["{rx, sx, dx} -> ", {rx, sx, dx}];
  Print["rx: Total of positive index (0 means no constraint), sx: minimum and \
maximum index, dx: minimum and maximum sum of total negative and enhanced \
index."];
  
  optFTS = FilterOptions[{opt}, FindTopSectors];
  topsec = FindTopSectors[topsec0, Evaluate@optFTS];
  
  opttable = FilterOptions[{opt}, TableS];
  sectors = 
   TableS[SubSectors[topsec[[i]], loops], {i, Length@topsec}, Method -> Automatic, 
     Evaluate@opttable] // Flatten;

  tp1 = TableS[PossibleMIsInSector[sectors[[i]], rx, sx, dx], {i, Length@sectors}, Method -> Automatic, 
     Evaluate@opttable] // Flatten;

  If[
  (PIFD = OptionValue["PossibleIntForDEInSector"]) =!= False, 
  tp1 = Join[
    tp1, 
    TableS[PossibleIntForDEInSector[sectors[[i]], Sequence @@ PIFD], {i, Length@sectors}, Method -> Automatic, 
     Evaluate@opttable] // Flatten
     ] // DeleteDuplicates
    ];
  
  tp2 = If[OptionValue["DropZeroSectorQ"],
    TableS[
     If[zeroSectorQ[tp1[[i]] // GToProps[#, family, List] &, loops, 
       kinematics], Nothing, tp1[[i]]]
     , {i, Length@tp1}, Method -> Automatic, Evaluate@opttable]
    , tp1];
  
  Join[topsec0, tp2] // DeleteDuplicates
  
  ]