ClearAll[GeneratePVbasis];
GeneratePVbasis[numberOfIndex_Integer, externalMoms_List] := 
 Module[{i, tpIndices, tp1, tp2, tp4, tp6, tpdiracList, tpEq1, tpcoeList, 
   tpEq2, tpcoeSol, tpPV, coe, diracToRules, tpdiracRules},
  tpIndices = Table[PVind[i], {i, numberOfIndex}];
  tp1 = Exp[
    Plus @@ Table[SPD[PVL, externalMoms[[i]]], {i, Length@externalMoms}] + 
     SPD[PVL, PVL]];
  tp2 = Table[FVD[PVL, tpIndices[[i]]], {i, Length@tpIndices}];
  tpdiracList = 
   FourDivergence[tp1, Sequence @@ tp2] /. Momentum[PVL, D] -> 0 // FCES;
  tpdiracList // PolynomialCollect[#, _FVD | _MTD] &
  ]


ClearAll[GeneratePVMMA];
Protect[PVind, PVL];
GeneratePVMMA[nLlist_List, externalMoms_List] /; (OrderedQ@Reverse@nLlist) := 
 Module[{i, ni, loopsPV, tpIndices, tp1, tp2, tp4, tp6, tpdiracList, tpEq1, 
   tpcoeList, tpEq2, tpcoeSol, coe, diracToRules, tpdiracRules},
  loopsPV = 
   Table[ConstantArray[PVL[i], nLlist[[i]]], {i, Length@nLlist}] // Flatten;
  
  ni = Length@loopsPV;
  If[ni === 0, Return[1]];
  
  tpdiracList = GeneratePVbasis[ni, externalMoms];
  If[tpdiracList === {}, Return[0]];
  
  tpIndices = Array[PVind, ni];
  
  diracToRules[
    diracl_] := (ListS[FCI@diracl, {}, Times] /. 
     Pair[a_, b_] /; ! FreeQ[a, PVind] :> (a -> b));
  tpdiracRules = diracToRules /@ tpdiracList;
  
  tp4 = Product[FVD[loopsPV[[i]], tpIndices[[i]]], {i, Length@tpIndices}];
  
  tpEq1 = 
   FCI@tp4 /. Dispatch@tpdiracRules(**tpdiracList*)// FCContract // FCES;
  tpcoeList = Array[coe, Length@tpdiracList];
  tp6 = tpcoeList . tpdiracList;
  tpEq2 = 
   FCI@tp6 /. Dispatch@tpdiracRules(**tpdiracList*)// FCContract // FCES;
  tpEq2 = Coefficient[#, tpcoeList] & /@ tpEq2;
  If[Det[tpEq2] === 0, Print["GeneratePV: PV is singular."]; Abort[]] // Quiet;
  tpcoeSol = LinearSolve[tpEq2, tpEq1] // Factor;
  tpdiracList . tpcoeSol
  ]

GeneratePVMMA[numberOfIndex_Integer, externalMoms_List] := 
 GeneratePVMMA[ConstantArray[1, numberOfIndex], externalMoms]