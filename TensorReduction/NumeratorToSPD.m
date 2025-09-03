NumeratorToSPD;

ClearAll[NumeratorToSPD];
Protect[LorInd];
Protect[OPs];
NumeratorToSPD::index = "The complete index should be -> `1`.";
NumeratorToSPD::maxit = 
  "The max iteration `1` reached, the Lorentz indices may be not uniquely \
ordered.";
NumeratorToSPD::spinor = 
  "Spinor still exist, the operatorRules is not complete. The outputs are \
still correct.";

Options[NumeratorToSPD] := 
  CreateOptions[{"OperatorCollect" -> False, "OperatorReplace" -> True, 
    "PVPatt" -> Automatic, "MaxIt" -> 10, 
    "NumeratorToSPDSimplify" :> SimplifyS, 
    "NumeratorToSPDForm" -> "Expression", "NumeratorToSPDDispatch" -> True, 
    "OperatorName" -> OPs, "OperatorHead" -> (# &)}, {CollectS}];

NumeratorToSPD[expr_, process_String : "CurrentProcess", 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 NumeratorToSPD[expr, ToExpression[process], opt]
NumeratorToSPD[expr_, process_Association, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 NumeratorToSPD[expr, process["indices"], process["operatorRules"], 
  process["loopmoms"], process["moms"], process["extmomsind"], 
  process["purePV"], opt]
NumeratorToSPD[expr_, indices_List, 
   operatorRules_List | operatorRules_Dispatch, loopmoms_List, moms_List, 
   extmomsind_List, purePV_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{PVPatt, num, num2, dummyind, indicesfull, indices1x, indices2, di, 
   di0, permu, patt, tp1, tp2, tp3, tp4, tp5, \[Delta]\[Delta], i, x, optloop,
    maxit = OptionValue["MaxIt"], itc = 0, TestFunction, hs, oplist},
  
  PVPatt = If[OptionValue["PVPatt"] == Automatic,
    (GSD[_] | 
      FVD[_, _] | (SPD[_, PVmom_] /; ! 
         MatchQ[PVmom, Alternatives @@ Join[loopmoms, extmomsind]])), 
    OptionValue["PVPatt"]];
  patt = _Dot | _DiracTrace | (x : PVPatt /; ! 
       FreeQ[x, Alternatives @@ loopmoms])(*PVPatt*);
  (*{_Dot|_DiracTrace}~Join~(List@@PVPatt)*)
  (*0. to fix a bug FCI@FAD[l + x p] -> Momentum[x p,D], 
  ExpandMomentum can restore Momentum[x p,D] -> x Momentum[p,D]*)
  Monitor[
   tp1 = FCES@expr /. 
      Dispatch@{SPD[a_, b_] :> ExpandMomentum[SPD[a, b], moms], 
        FVD[a_, b_] :> ExpandMomentum[FVD[a, b], moms]} // FCES;
   tp1 = tp1 // RefineSpinor;
   tp1 = tp1 // 
     CollectS[#, _FAD | _SFAD, # &, 
       FCES@ExpandMomentum@FeynAmpDenominatorExplicit@# &] &;
   
   (*1. first step simplification*)
   tp2 = tp1 // 
      CollectS[#, DiracPattern | _FVD | _MTD, # &, DiracSimplify] & // 
     ExpandDirac(*//TimingS*);
   , "NumeratorToSPD: Preprocessing..."];
  (*have to collect FVD, MTD here, otherwise, 
  many terms with open index appear...*)
  (*tpt2=tp2;*)(*we do not include form _FVD|_MTD in the first time dirac \
simplify, we will include them after pv reduction, Dot[___]*
  FVD[_,_] may cost more time even no index contraction*)
  (*2. expand all the terms like GSD[l1+p] to PVReduce separately*)
  tp2 =(*Monitor[*)tp2 // CollectS[#, patt] & // ListS(*,"tp2 2"]*);
  
  
  (*3. PVReduce*)
  Monitor[
   optloop = FilterOptions[{opt}, loopRulesPV];
   tp3 =(*Monitor[*)
    Table[tp2[[i]] // loopRulesPV[#, loopmoms, extmomsind, optloop] & // 
         DotExpand // # /. DiracTrace -> TR & // 
       PVReduce[#, loopmoms, purePV] &, {i, Length@tp2}] // FCES(*,
   "tp3 1"]*);
   , "NumeratorToSPD: PV reducing..."];
  
  
  (*4. contract the indices from the PV reduction*)
  Monitor[
   tp3 = Total[tp3] // 
       CollectS[#, DiracPattern | _FVD | _MTD, # &, DiracSimplify] & // FCES(*//
    TimingS*);
   , "NumeratorToSPD: Contracting the indices from the PV reduction..."];
  
  
  (*5. canonical index*)
  Monitor[
   dummyind = getdummyindices[tp3];
   indices1x = 
    If[indices === {}, 
     Complement[getfullindices[tp3], dummyind]~Join~{"dummyindices"}, indices];
   indices2 = Module[{},
     tp3 = tp3 /. Thread[dummyind -> Array[LorInd, Length@dummyind]];
     dummyind = Array[LorInd, Length@dummyind];
     indices1x /. "dummyindices" -> Sequence @@ dummyind];
   
   (*may be faster for simple case...*)
   tp3 = tp3 // CollectS[#, OperatorPattern, # &, RenameDummyInd] &;
   
   , "NumeratorToSPD: Canonicalizing indices..."];
  
  (*6. replaced by operators*)
  
  If[
   indices =!= {} && ! 
     SubsetQ[indices, Complement[getfullindices[tp3], dummyind]],
   Message[NumeratorToSPD::index, Complement[getfullindices[tp3], dummyind]]
   ];
  
  
  If[OptionValue["OperatorCollect"] == True,
   tp3 = FixedPoint[
     PolynomialCollect[indicesOrder[#, itc++; indices2, {}], DiracPattern] &,
     tp3,
     maxit];
   Return[tp3]
   ];
  
  Monitor[
   If[OptionValue["OperatorReplace"] === False || operatorRules === {},
     tp3 = FixedPoint[
        (*TimingS[*)(indicesOrder[#, itc++; indices2, {}](*]*)&),
        tp3,
        maxit,
        SameTest -> ((PolynomialCollect[#1, 
              DiracPattern]) === (PolynomialCollect[#2, DiracPattern]) &)];
     (*tp3=tp3//CollectS[#,_Dot|_Spinor|_DiracTrace,#&,RenameDummyInd]&//
     TimingS;*)
     ,
     
     TestFunction = (FreeQ[#, Spinor | DiracTrace] &);
     tp3 = tp3 /. operatorRules;
     For[num = 1,
      num <= maxit && ! 
        TestFunction[
         tp3] && (PolynomialCollect[tp3, 
          DiracPattern]) =!= (PolynomialCollect[tp4, DiracPattern]),
      itc++; num++,
      tp4 = tp3; tp3 = indicesOrder[tp3, indices2, operatorRules]](*//
     TimingS*);
     ];
   , {"NumeratorToSPD: Indices ordering... ", itc}];
  
  (*Print[itc];*)
  
  If[itc >= maxit, 
   Message[NumeratorToSPD::maxit,(*maxit*)
    ToString[itc] <> " of " <> ToString[maxit]]];
  If[! FreeQ[tp3, Spinor] && operatorRules =!= {} && 
    OptionValue["OperatorReplace"] == True, Message[NumeratorToSPD::spinor]];
  
  (*tp3=tp3/.Dispatch[x:_SPD/;FreeQ[x,Alternatives@@loopmoms]:>spd@@
  x];*)(*to fix a bug when SPD[p1,
  p2] are not defined and appear in the denominators*)
  tp3 = tp3 // CollectS[#, _FVD | _MTD, # &, FCES@FCContract@# &] &;
  
  (*Abbreivate Spinors*)
  Monitor[
   {tp3, tp4} = 
     AbbreviatePolynomials[tp3, OperatorPattern, 
      "AbbreviatePolynomialsName" -> OptionValue["OperatorName"], 
      "AbbreviatePolynomialsHead" -> OptionValue["OperatorHead"]];
   , {"NumeratorToSPD: Abbreivating operators..."}];
  
  (*tpx10=tp3;*)
  (*make the further simplification more easier if we add this OperatorHead*)
  tp3 = Monitor[
    CollectS[tp3, x : _SPD /; ! FreeQ[x, Alternatives @@ loopmoms], 
     OptionValue["NumeratorToSPDSimplify"]],
    "NumeratorToSPD: Simplifying with the option \
\"NumeratorToSPDSimplify\"..."](*//TimingS*);
  (*although in the next step, we only concern about the SPD -> 
  deno to obtain scalar integrals, 
  we can still retain these structure for easier simplification...*)
  
  (*tp3=tp3/.Dispatch[spd->SPD];*)
  
  Switch[OptionValue["NumeratorToSPDForm"],
   "ExpressionRules", {tp3, 
    If[OptionValue["NumeratorToSPDDispatch"], Dispatch@tp4, tp4]},
   _, tp3 /. Dispatch@tp4
   ]
  
  ]