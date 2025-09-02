DropZeroByNumerics;

ClearAll[DropZeroByNumerics, DropZeroByNumerics2];
DropZeroByNumerics[expr0_, patt_] := DropZeroByNumerics[expr0, expr0, patt]
DropZeroByNumerics[expr0_, expr_, patt_] := 
 Module[{tp1, tpGs1, tpvars, func1, tpGs2, tpGs3, tpGs4, tpRules2},
  tp1 = expr // Separate[#, patt] &;
  tpGs1 = expr // getS[#, patt] &;
  If[tpGs1 =!= {} && tpGs1 =!= tp1[[2]], 
   Print["DropZeroByNumerics: Wrong input form."]; Abort[]];
  tpvars = tp1[[1]] // Variables;
  
  func1[exprf_, varsf_] :=
   Module[{tpvalues, tpRules, tpf1},
    tpvalues = 
     ConstantArray[Hold[RandomReal[WorkingPrecision -> 50]], Length@varsf] // 
      ReleaseHold;
    tpRules = Dispatch@Thread[varsf -> tpvalues];
    tpf1 = exprf /. tpRules;
    tpf1 // CollectS[#, patt, Chop[Expand[#], 10^-5] &] & // getS[#, patt] &
    ];
  
  tpGs2 = Check[func1[expr, tpvars], $Failed] // Quiet;
  While[tpGs2 === $Failed, tpGs2 = Check[func1[expr, tpvars], $Failed]] // 
   Quiet;
  
  tpGs3 = Complement[tpGs1, tpGs2];
  tpGs4 = Transpose[tp1] // Select[#, MemberQ[tpGs3, #[[2]]] &] &;
  tpGs4 = tpGs4 // TogetherExpand;
  tpGs4 = Select[tpGs4, #[[1]] === 0 &][[All, 2]];
  tpRules2 = Dispatch@Thread[tpGs4 -> 0];
  expr0 /. tpRules2
  ]

DropZeroByNumerics2[expr0_, patt0_] := 
 Module[{expr, tp1, tpGs1, tpvars, func1, tpGs2, tpGs3, tpGs4, tpRules2, hd, 
   patt},
  expr = expr0 // CollectS[#, patt0, # &, hd] &;
  patt = _hd;
  
  tp1 = expr // Separate[#, patt] &;
  tpGs1 = tp1[[2]] // getS[#, patt] &;
  tpvars = tp1[[1]] // Variables;
  
  func1[exprf_, varsf_] :=
   Module[{tpvalues, tpRules, tpf1},
    tpvalues = 
     ConstantArray[Hold[RandomReal[WorkingPrecision -> 50]], Length@varsf] // 
      ReleaseHold;
    tpRules = Dispatch@Thread[varsf -> tpvalues];
    tpf1 = exprf /. tpRules;
    tpf1 // CollectS[#, patt, Chop[Expand[#], 10^-5] &] & // getS[#, patt] &
    ];
  
  tpGs2 = Check[func1[expr, tpvars], $Failed] // Quiet;
  While[tpGs2 === $Failed, tpGs2 = Check[func1[expr, tpvars], $Failed]] // 
   Quiet;
  
  tpGs3 = Complement[tpGs1, tpGs2];
  tpGs4 = Transpose[tp1] // Select[#, MemberQ[tpGs3, #[[2]]] &] &;
  tpGs4 = tpGs4 // TogetherExpand;
  tpGs4 = Select[tpGs4, #[[1]] === 0 &][[All, 2]];
  tpRules2 = Dispatch@Thread[tpGs4 -> 0];
  expr /. tpRules2 /. hd -> (# &)
  ]