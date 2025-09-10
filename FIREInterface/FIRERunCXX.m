ClearAll[FIRERunCXX]
FIRERunCXX[loops_List, family_List, process_String : "CurrentProcess"] := 
 FIRERunCXX[loops, family, ToExpression[process]]
FIRERunCXX[loops_List, family_List, process_Association] := 
 FIRERunCXX[loops, family, FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops]]
FIRERunCXX[loops_List, family_List, FIREWorkPath_String, 
  FIREFamilyName_String] := Module[{i},
  
  If[Head[$FIREInstallPath] =!= String, 
   Print["Set $FIREInstallPath firstly."]; Abort[]];
  
  TableS[
   RunProcess[{FileNameJoin[{DirectoryName@$FIREInstallPath, "bin", 
       StringTake[FileNameTake[$FIREInstallPath], {1, -3}]}], "-c", 
     FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]}]
   , {i, Length@family}, "Reducing target integrals..."];
  ]