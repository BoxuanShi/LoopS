ClearAll[DropZeroByNumerics];
DropZeroByNumerics::usage = 
  "1. DropZeroByNumerics[expr0, expr, patt] drops the patt with zero \
coefficient in expr0 according to expr by numerics.
2. DropZeroByNumerics does not change the original structure of \
expr0, so that the expr should be linear dependent with patt.";
DropZeroByNumerics[expr0_, patt_] := 
 DropZeroByNumerics[expr0, expr0, patt]
DropZeroByNumerics[expr0_, expr_, patt_] := 
 Module[{x, tp1, poly1, vars, func1, poly2, poly3, polyv, tpRules2},
  poly1 = expr0 // getS[#, patt] &;
  tp1 = expr // SeparatePoly[#, poly1, "SeparateDropOne" -> True] &;
  If[! SubsetQ[poly1, tp1[[2]]], 
   Print["DropZeroByNumerics: expr is not linear dependent with \
patt."]; Abort[]];
  func1[exprf_, varsf_] := 
   Module[{tpvalues, tpRules, tpf1}, 
    tpvalues = 
     ConstantArray[Hold[RandomReal[WorkingPrecision -> 50]], 
       Length@varsf] // ReleaseHold;
    tpRules = Dispatch@Thread[(Verbatim /@ varsf) -> tpvalues];
    tpf1 = exprf /. tpRules;
    tpf1 // CollectS[#, patt, Chop[Expand[#], 10^-5] &] & // 
     getS[#, patt] &];
  vars = tp1[[1]] // Variables;
  poly2 = Check[func1[expr, vars], $Failed] // Quiet;
  While[poly2 === $Failed, 
    poly2 = Check[func1[expr, vars], $Failed]] // Quiet;
  poly3 = Complement[poly1, poly2];
  
  polyv = Transpose@tp1 // Select[#, MemberQ[poly3, #[[2]]] &] &;
  polyv = polyv // TogetherExpand;
  polyv = Select[polyv, #[[1]] === 0 &][[All, 2]];
  polyv = Join[polyv, Complement[poly1, tp1[[2]]]];
  
  tpRules2 = Dispatch@Thread[polyv -> 0];
  expr0  /. x:patt :> Replace[x, tpRules2]]