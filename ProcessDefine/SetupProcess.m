ClearAll[SetupProcess];

SetupProcess::spddefine = "Irreducible scalar product `1` exist.";
Options[SetupProcess] := {"DefineSPD" -> True, "CreateFiles" -> True};

(*clear process*)
SetupProcess[] := ClearProcess[];

(*define process*)
SetupProcess["CurrentProcess", ___] := 
 Print["CurrentProcess has been used by LoopS, please choose another name for \
your process."]
SetupProcess[process_String, b___, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{x, i, j, keys, str, outerSPD, processA},
  (*ClearProcess*)
  Block[{Print = (# &)}, ClearProcess[]];
  
  (*Distribute to CurrentProcess*)
  processA = ToExpression@process;
  If[Head@processA =!= Association, 
   Print["Define the process " <> process <> " firstly."]; Abort[]];
  Quiet[If[ToExpression[process]["ProcessName"] =!= process, 
    Print[process <> "[\"ProcessName\"] should be the same as \"" <> process <>
       "\"."]; Abort[]]];
  CurrentProcess := ToExpression[process];
  Print["CurrentProcess have been set as " <> process, "."];
  
  (*Distribute to DefinedProcess*)
  Unprotect[DefinedProcess];
  If[Head@DefinedProcess === Symbol, DefinedProcess = {}];
  DefinedProcess = Append[DefinedProcess, process] // Union;
  
  (*setshared*)
  If[$KernelID == 0, 
   "SetSharedVariable[" <> processA["ProcessName"] <> "]" // ToExpression];
  
  (*Distribute to some global variables*)
  Unprotect[ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, 
   kinematics, indices, purePV];
  {ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, kinematics, 
    indices, purePV, operatorRules} = 
   CurrentProcess /@ {"ProcessName", "moms", "loopmoms", "extmoms", 
     "extmomsind", "extramoms", "kinematics", "indices", "purePV", 
     "operatorRules"};
  Protect[ProcessName, moms, loopmoms, extmoms, extmomsind, extramoms, 
   kinematics, indices, purePV];
  
  (*Define algebras*)
  If[OptionValue["DefineSPD"],
   Table[SPD[extmomsind[[i]], extmomsind[[j]]] = 
      extmomsind[[i]]*extmomsind[[j]] /. kinematics, {i, 
      Length@extmomsind}, {j, i}];
   ];
  AlgebrasDefinition[process, b];
  
  (*Distribute to CurrentAlgebras*)
  CurrentAlgebras = {process, b};
  Print["CurrentAlgebras have been set as: " <> ToString@CurrentAlgebras, "."];
  
  (*check extramom definitions*)
  outerSPD = 
   Outer[SPD, extramoms, extramoms] // ExpandMomentum // ExpandDirac // 
    getS[#, x : _SPD /; FreeQ[x, Alternatives @@ loopmoms]] &;
  If[outerSPD =!= {}, Message[SetupProcess::spddefine, outerSPD]];
  
  (*CreateFiles*)
  If[OptionValue["CreateFiles"],
   str = StringJoin @@@ Table["N", {i, 0, Length@loopmoms}, {j, i}];
   Do[
    CreateDirectoryS[FileNameJoin[{ProcessPath[process], str[[i]] <> "LO"}]];
    , {i, Length@str}];
   CreateDirectoryS[PVPath[process]];
   CreateDirectoryS[FIREWorkPath[process]]
   ];
  Print["LoopS work directory is LoopSWorkDirectory -> ", LoopSWorkDirectory, 
   "."];
  ]

SetupProcess[CurrentAlgebras_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Block[{Print = (# &)}, SetupProcess[Sequence @@ CurrentAlgebras, opt]]