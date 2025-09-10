ClearAll[GeneratePVOPITeR];
GeneratePVOPITeR[nLlist_List, extmomsind_List] /; (OrderedQ@Reverse@nLlist) :=
  Module[{i, x, loopsPV, loopsOPITeR, loopRules, inds, indsRules, extOPITeR, 
   extRules, abbrL, abbrE, exp, template, tp1, infile, outfile},
  If[! FileExistsQ[$OPITeRInstallPath], Return[$Failed]];
  
  loopsPV = 
   Table[ConstantArray[PVL[i], nLlist[[i]]], {i, Length@nLlist}] // Flatten;
  
  {loopsOPITeR, loopRules} = 
   AbbreviateVariables[loopsPV, "AbbreviateVariablesName" -> abbrL] /. 
    abbrL[x_] :> StringJoin["p", ToString[x]];
  loopRules = 
   Thread[loopRules[[All, 
      1]] -> (ToString /@ loopRules[[All, 2]])];(*convert to string replace*)
  
  inds = Table["mu" <> ToString[i], {i, Length@loopsOPITeR}];
  indsRules = 
   Thread[inds -> (ToString /@ Array[PVind, Length@inds])];(*string replace*)
  
  exp = Table[
    loopsOPITeR[[i]] <> "(" <> inds[[i]] <> ")", {i, Length@loopsOPITeR}];
  
  {extOPITeR, extRules} = 
   AbbreviateVariables[extmomsind, "AbbreviateVariablesName" -> abbrE] /. 
    abbrE[x_] :> StringJoin["q", ToString[x]];
  extRules = 
   Thread[extRules[[All, 
      1]] -> (ToString /@ extRules[[All, 2]])];(*convert to string replace*)
  
  outfile = 
   FileNameJoin[{OPITeRWorkPath, 
     "pvreduceout" <> ToString[$KernelID] <> ".m"}];
  template = OPITeRTemplete[Union@loopsOPITeR, extOPITeR, exp, outfile];
  
  infile = 
   FileNameJoin[{OPITeRWorkPath, 
     "pvreducein" <> ToString[$KernelID] <> ".frm"}];
  Export[infile, template, "Text"];
  Run["form " <> infile];
  
  If[! FileExistsQ[outfile], Return[$Failed]];
  
  tp1 = OPITeRImport[outfile, extRules, loopRules, indsRules];
  DeleteFile[outfile];
  
  tp1 /. Dispatch@Thread[extmomsind -> (FVD /@ extmomsind)] /. 
    FVD[x_][y_] :> FVD[x, y] /. FVD[x_] :> x
  ]

GeneratePVOPITeR[numberOfIndex_Integer, externalMoms_List] := 
 GeneratePVOPITeR[ConstantArray[1, numberOfIndex], externalMoms]


ClearAll[OPITeRTemplete];
OPITeRTemplete[loops_List, extmomsind_List, exp_List, filename_String] := 
 Module[{},
  "
#: IncDir " <> $OPITeRInstallPath <> "
#include- opiter.frm
Autodeclare Vector q;
Off statistics;
L F2=ext(" <> StringRiffle[extmomsind, ","] <> ")*loop(" <> 
   StringRiffle[loops, ","] <> ")" <> "*" <> 
   StringRiffle[If[exp === {}, {1}, exp], "*"] <> ";
#call opiter
.sort
#call symmetrise
.sort
#call leavedualtransverse
.sort
B loop,ext,Gsigma,d_,ddts,dual,sym,deno;
#write <" <> filename <> "> \"%e\",F2;
.end
"]

ClearAll[OPITeRImport]
OPITeRImport[filename_String, extRules_, loopsRules_, indexRules_] := 
 Module[{tp1, tp2, tp3, tp4, ext, rat, deno, loop},
  tp1 = Import[filename, "String"];
  
  tp2 = StringDelete[tp1, {";", " ", "\n", "\\"}];
  tp2 = StringReplace[tp2, {"(" -> "[", ")" -> "]", "d_" -> "MTD"}];
  tp2 = tp2 // 
    StringReplace[#, {"ext" -> ToString@ext, "rat" -> ToString@rat, 
       "deno" -> ToString@deno, "loop" -> ToString@loop}] &;
  tp2 = tp2 // StringReplace[#, Join[extRules, loopsRules, indexRules]] &;
  
  tp3 = ToExpression@tp2;
  tp3 = tp3 /. Dispatch@{_ext -> 1, ext -> 1, _loop -> 1, loop -> 1};
  tp3 = tp3 /. Dispatch@{deno[x_] :> 1/x, rat[x_, y_] :> x/y};
  tp3 = tp3 /. Dot[x_, Power[y_, z_]] :> Dot[x, y]^z /. Dot -> SPD
  ]