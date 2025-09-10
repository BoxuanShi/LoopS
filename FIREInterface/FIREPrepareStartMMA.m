ClearAll[FIREPrepareStartMMA]
Options[FIREPrepareStartMMA] := 
  CreateOptions[{"FIREVerbose" -> False}, {PrepareParallel}];
FIREPrepareStartMMA[loops_List, family_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 FIREPrepareStartMMA[loops, family, ToExpression[process], Evaluate@opt]
FIREPrepareStartMMA[loops_List, family_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 FIREPrepareStartMMA[loops, family, process["extmomsind"], 
  process["kinematics"], FIREWorkPath[process["ProcessName"]], 
  FIREFamilyName[loops], Evaluate@opt]
FIREPrepareStartMMA[loops_List, family_List, extmomsind_List, kinematics_List,
    FIREWorkPath_String, FIREFamilyName_String, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := Module[{i, tp1},
  FIREParallel[
   BlockCondition[! OptionValue["FIREVerbose"], {Print = (# &)},
     AppendTo[$ContextPath, "FIRE`"];
     Internal = loops;
     External = extmomsind;
     Propagators = family[[i]];
     Replacements = kinematics;
     PrepareIBP[];
     Prepare[AutoDetectRestrictions -> True, LI -> True];
     SaveStart[FileNameJoin[{FIREWorkPath, FIREFamilyName <> ToString[i]}]]];
   ,
   {i, 1, Length@family}, OptionValue["Kernels"]];
  
  Print["Starts are prepared."]
  ]

ClearAll[FIREParallel]
SetAttributes[FIREParallel, HoldAll]
FIREParallel[body_, {pindex_, ini_, fin_}, paraNum_] := 
 Module[{re, cycf, kernellist, paraRang, ig},
  cycf = (fin - ini + 1)/paraNum;(*number of cycle minus 1*)
  cycf = If[IntegerQ[cycf], cycf - 1, cycf // IntegerPart];
  re = Monitor[
     Table[CloseKernels[];
      LaunchKernels[paraNum];
      kernellist = 
       ParallelEvaluate[$KernelID];(*get kernel ID for given number of \
kernels*)
      Table[
       ParallelEvaluate[pindex = ini + paraNum*cyc + ig - 1, 
        kernellist[[ig]]], {ig, 
        paraNum}];(*define the corresponding pindex in the kernels*)
      paraRang = 
       kernellist[[
        1 ;; Length[
          Intersection[Range[fin - ini + 1], 
           Range[paraNum*cyc + 1, 
            paraNum*(cyc + 1)]]]]];(*decide which kernel to run*)
      ParallelEvaluate[body, paraRang](*evaluate and return the results*)
      , {cyc, 0, cycf}]
     , {cyc*paraNum, fin}] // Flatten[#, 1] &;
  CloseKernels[];
  re
  ]