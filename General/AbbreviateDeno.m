AbbreviateDeno;

ClearAll[FactorFlat]
FactorFlat[expr_] := Sort[FactorFlat0[expr]]
FactorFlat0[expr_Times] := Flatten[FactorFlat0 /@ (List @@ expr)];
FactorFlat0[Power[expr_, n_?IntegerQ]] /; n > 0 := 
 ConstantArray[FactorFlat0@expr, n]
FactorFlat0[_?NumberQ] := {};
FactorFlat0[x_] := {x};


ClearAll[FactorFlat2];
FactorFlat2[expr_Times] := Flatten[FactorFlat2 /@ (List @@ expr)];
FactorFlat2[Power[x_, n_?IntegerQ]] := FactorFlat2[x];
FactorFlat2[_?NumericQ] := {};
FactorFlat2[x_] := {x};


ClearAll[FactorListRev]
FactorListRev[factorlist_List] := 
 Times @@ ((Power[#[[1]], #[[2]]] &) /@ factorlist)


ClearAll[AbbreviateDeno];
Protect[AbbrD];
Options[AbbreviateDeno] = {"AbbreviateDenoName" -> AbbrD};
AbbreviateDeno[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, tp2, tp3, abbr},
  tp1 = DistributeToPolyND[expr];
  tp2 = AbbreviateDenominators[tp1, {}, InverseSymbol -> abbr];
  {tp2[[1]], Thread[tp2[[3]] -> 1/tp2[[2]]]} /. 
   Dispatch[Thread[
     tp2[[3]] -> Array[OptionValue["AbbreviateDenoName"], Length@tp2[[3]]]]]
  ]