ClearAll[GatherGInFamily]
GatherGInFamily[Glist_List, family_List] := Module[{Glist2, Glist3},
  Glist2 = Join[Glist, G[#, "x"] & /@ (Range@Length@family)];
  Glist3 = Glist2 // GatherBy[#, #[[1]] &] & // SortBy[#, #[[1, 1]] &] &;
  DeleteCases[#, G[_, "x"]] & /@ Glist3
  ]


ClearAll[FIREPrepareCXX]
Options[FIREPrepareCXX] := 
 CreateOptions[{"compressor" -> "none", 
   "FIRECXXKernels" :> 
    LoopSParallelKernels}, {FindCompleteGList}]; FIRECXXKernels;
FIREPrepareCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareCXX[Fslist, loops, family, rx, sx, dx, ToExpression[process], 
  Evaluate@opt]
FIREPrepareCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareCXX[Fslist, loops, family, rx, sx, dx, process["extmomsind"], 
  process["kinematics"], FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], Evaluate@opt]

FIREPrepareCXX[Fslist_List, loops_List, family_List, rx_Integer : 0, 
   sx_List : {0, 2}, dx_List : {0, 1}, extmomsind_List, kinematics_List, 
   FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{i, rulesConfig, Fslist2, FlistFamily, tp1, opt1, opt2, opt3, opt4, 
   optFCG},
  
  If[Head[$FIREInstallPath] =!= String, 
   Print["Set $FIREInstallPath firstly."]; Abort[]];
  
  (*separate Fslist by family and export to FIREWorkPath*)
  optFCG = FilterOptions[{opt}, FindCompleteGList];
  Fslist2 = 
   FindCompleteGList[Fslist, family, loops, rx, sx, dx, kinematics, 
    Evaluate@optFCG];
  FlistFamily = GatherGInFamily[Fslist2, family];
  FlistFamily = FlistFamily /. Dispatch[G -> List];
  TableS[Export[
    FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".m"}], 
    FlistFamily[[i]]], {i, Length@family}, "Exporting target integrals..."];
  
  (*generate config file for FIRECXX*)
  Table[
   rulesConfig = <|
     "compressor" -> OptionValue["compressor"],
     "fThreads" -> OptionValue["FIRECXXKernels"],
     "tThreads" -> Ceiling[OptionValue["FIRECXXKernels"]/2],
     "sThreads" -> Ceiling[OptionValue["FIRECXXKernels"]/2],
     "variables" -> (ToString[
         Complement[Variables[family], Join[loops, extmomsind]]] // 
        StringTake[#, {2, -2}] &),
     "folder" -> PathName[FIREWorkPath],
     "familyName" -> (FIREFamilyName <> ToString[i]),
     "problem" -> i,
     "output" -> 
      FileNameJoin[{FIREWorkPath, 
        FIREFamilyName <> ToString[i] <> ".tables"}]
     |>;
   Export[
    FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".config"}], 
    TemplateApply[FIRETemplate["Config"], rulesConfig], "Text"]
   , {i, Length@family}];
  
  (*RunProcess-export*)
  Export[FileNameJoin[{FIREWorkPath, "FIRERun.txt"}],
   StringJoin @@ 
    Table[FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", 
        FileNameTake@$FIREInstallPath}] <> " -c " <> 
      FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}] <> ";", {i, 
      Length@family}]
   , "Text"];
  
  Print["Kernels prepared for FIRE is FIRECXXKernels -> ", 
   OptionValue["FIRECXXKernels"], "."]
  ]