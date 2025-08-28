FIREPrepareStart;

ClearAll[FIREPrepareStart];
FIREVerbose;
Options[FIREPrepareStart] := 
 CreateOptions[{"FIREVerbose" -> False}, {TableS}]
FIREPrepareStart[loops_List, family_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareStart[loops, family, ToExpression[process], Evaluate@opt]
FIREPrepareStart[loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareStart[loops, family, process["extmomsind"], process["kinematics"],
   FIREWorkPath[process["ProcessName"]], FIREFamilyName[loops], Evaluate@opt]
FIREPrepareStart[loops_List, family_List, extmomsind_List, kinematics_List, 
   FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] := 
  Module[{i, FIREFile, template, rule, opttable},
   
   (*FIREInstallPath*)
   FIREFile = $FIREInstallPath;
   If[! FileExistsQ[FIREFile], Print["$FIREInstallPath is wrong."]; Abort[]];
   
   (*FileTemplateApply*)
   template = FIRETemplate["Start"];
   Table[
    rule = <|
      "FIRE" -> ToStringInput@FIREFile,
      "Internal" -> ToStringInput@loops,
      "External" -> ToStringInput@extmomsind,
      "Propagators" -> ToStringInput@family[[i]],
      "Replacements" -> ToStringInput@kinematics,
      "family" -> 
       ToStringInput@
        FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]
      |>;
    
    FileTemplateApply[template, rule, 
     FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i] <> ".wl"}]]
    , {i, Length@family}];
   
   (*RunProcess*)
   opttable = FilterOptions[{opt}, TableS];
   TableS[
    RunProcess[{"wolframscript", "-file", 
       FileNameJoin[{FIREWorkPath, 
         FIREFamilyName <> ToString[i] <> ".wl"}]}];
    , {i, Length@family}, Method -> "ItemsPerEvaluation" -> 1, 
    Evaluate@opttable];
   
   Print["Starts are prepared."]
   ];