GetFeynInt;

ClearAll[GetFeynInt]
Options[GetFeynInt] := CreateOptions[{"Parallelization" -> False}, {TableS}];
GetFeynInt[amp_, loops_List, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 GetFeynInt[amp, loops, ToExpression[process], opt]
GetFeynInt[amp_, loops_List, process_Association, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 GetFeynInt[amp, loops, process["moms"], process["kinematics"], opt]

GetFeynInt[amp_List, loops_List, moms_List, kinematics_List, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{amp2, opttable, i, tp1, tp2},
  amp2 = Union@Flatten@amp;
  opttable = FilterOptions[{opt}, TableS];
  TableS[GetFeynInt[amp2[[i]], loops, moms, kinematics], {i, Length@amp2}, 
     Evaluate@opttable] // Flatten // Union]

GetFeynInt[amp_, loops_List, moms_List, kinematics_List] := 
 Module[{i, patt, tp0, tp1},
  If[
   MatchQ[amp, _FAD | _SFAD | _FeynAmpDenominator] && 
    AllTrue[amp, ! FreeQ[#, Alternatives @@ loops] &], 
   Return[ApartFFS[amp, loops, moms, kinematics, 
       "ApartFFSSimplify" -> (# &)][[2]] // getS[#, _FAD | _SFAD] &]
   ];
  
  patt = x_FAD | x_SFAD | x_FeynAmpDenominator /; 
    Or @@ Table[! FreeQ[x, loops[[i]]], {i, Length@loops}];
  
  tp0 = amp // PolynomialCollect[#, patt] & // FeynAmpDenominatorSplit // FCES // PolynomialCollect[#, patt] &;
  tp0 = If[! FreeQ[tp0, SFAD], tp0 // ToSFAD, tp0];
  tp0 = tp0 // FeynAmpDenominatorCombine // FCES // Flatten // Union;
  
  tp1 = (ApartFFS[#, loops, moms, kinematics, "ApartFFSSimplify" -> (# &)][[
        2]] &) /@ tp0 // getS[#, _FAD | _SFAD] &
  
  ]