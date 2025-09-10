ClearAll[FIRELoadTable]
Options[FIRELoadTable] = {"FIREVerbose" -> False};
FIRELoadTable[loops_List, family_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIRELoadTable[loops, family, ToExpression[process], opt]
FIRELoadTable[loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIRELoadTable[loops, family, FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], opt]
FIRELoadTable[loops_List, family_List, FIREWorkPath_String, 
   FIREFamilyName_String, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i},
  If[
   Union@Table[
      FileExistsQ[
       FileNameJoin[{FIREWorkPath, 
         FIREFamilyName <> ToString[i] <> ".tables"}]], {i, 
       Length@family}] === {True},
   Nothing,
   Print["Tables are abscent."]; Abort[]
   ];
  
  FIREEvaluate[
   BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
    LoadTables[
     Table[FileNameJoin[{FIREWorkPath, 
        FIREFamilyName <> ToString[i] <> ".tables"}], {i, Length@family}]]]
   ];
  
  Print["Tables are loaded."]
  ]