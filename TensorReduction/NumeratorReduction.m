ClearAll[NumeratorReduction];
Protect[LorInd];
Protect[OPs];
NumeratorReduction::index = "The complete index should be -> `1`.";
NumeratorReduction::maxit = "The max iteration `1` reached, the Lorentz indices may be not uniquely ordered.";
NumeratorReduction::spinor = "Spinor still exist, the operatorRules is not complete. The outputs are still correct.";

Options[NumeratorReduction] := CreateOptions[{"operatorRules" -> None, "OperatorCollect" -> False, "OperatorReplace" -> True, "PVPatt" -> Automatic, "MaxIt" -> 10, "NumeratorReductionSimplify" :> SimplifyS, "NumeratorReductionForm" -> "Expression", "NumeratorReductionDispatch" -> True, "OperatorName" -> OPs, "OperatorHead" -> (# &)}, {CollectS}];

NumeratorReduction[expr_, process_Association : Hold@CurrentProcess, opt : OptionsPattern[]] := Module[{p=ReleaseHold@process}, NumeratorReduction[expr, p["indices"], p["operatorRules"], p["loopmoms"], p["moms"], p["extmomsind"], p["purePV"], opt]]
NumeratorReduction[expr_List, indices_List, operatorRules0_List | operatorRules0_Dispatch, loopmoms_List, moms_List, extmomsind_List, purePV_String, opt : OptionsPattern[]] := NumeratorReduction[#, indices, operatorRules0, loopmoms, moms, extmomsind, purePV, opt]& /@ expr;
NumeratorReduction[expr : Except[_List], indices_List, operatorRules0_List | operatorRules0_Dispatch, loopmoms_List, moms_List, extmomsind_List, purePV_String, opt : OptionsPattern[]] := Module[{PVPatt, num, dummyind, indices1x, indices2, patt, tp1, tp2, tp3, tp4, i, x, optloop, maxit = OptionValue["MaxIt"], itc = 0, TestFunction, operatorRules},
  
  operatorRules = If[OptionValue["operatorRules"] === None, 
    If[Head[operatorRules0] === Dispatch, operatorRules0, Dispatch@operatorRules0],
    Dispatch@OptionValue["operatorRules"]
  ];

  
  PVPatt = If[OptionValue["PVPatt"] == Automatic, (GSD[_] | FVD[_, _] | (SPD[_, PVmom_] /; ! MatchQ[PVmom, Alternatives @@ Join[loopmoms, extmomsind]])), OptionValue["PVPatt"]];
  patt = _Dot | _DiracTrace | (x : PVPatt /; ! FreeQ[x, Alternatives @@ loopmoms])(*PVPatt*);
  
  (*0. to fix a bug FCI@FAD[l + x p] -> Momentum[x p,D], 
  ExpandMomentum can restore Momentum[x p,D] -> x Momentum[p,D]*)

  Monitor[
    tp1 = FCES @ expr /. Dispatch @ {SPD[a_, b_] :> ExpandMomentum[SPD[a, b], moms], FVD[a_, b_] :> ExpandMomentum[FVD[a, b], moms]} // FCES;
    tp1 = tp1 // RefineSpinor;

    (*1. first step simplification*)
    (* tp1 = tp1 //ExpandDirac // CollectS[#, DiracPattern | _FVD | _MTD, # &, DiracSimplify[# /. DiracTrace -> TR] & ] & // ExpandDirac (*//TimingS*); *)
    tp1 = tp1 // ExpandDirac;
    tp1 = tp1 // Separate[#, DiracPattern | _FVD | _MTD] &;
    tp1[[2]] = TableS[ DiracSimplify[ tp1[[2, i]] /. DiracTrace -> TR ], {i, Length @ tp1[[2]]} ];
    tp1 = Dot @@ tp1 // ExpandDirac (*//TimingS*);

    tp2 = tp1 // CollectS[#, _FAD | _SFAD, # &, FCES@ExpandMomentum@FeynAmpDenominatorExplicit@# &] &; , "NumeratorReduction: Preprocessing..."
  ];

  (*have to collect FVD, MTD here, otherwise, 
  many terms with open index appear...*)
  (*tpt2=tp2;*)(*we do not include form _FVD|_MTD in the first time dirac simplify, we will include them after pv reduction, Dot[___]*
  FVD[_,_] may cost more time even no index contraction*)
  (*2. expand all the terms like GSD[l1+p] to PVReduce separately*)
  tp2 =(*Monitor[*)tp2 // CollectS[#, patt] & // ListS(*,"tp2 2"]*);
  

  (*3. PVReduce*)
  Monitor[
    optloop = FilterOptions[{opt}, loopRulesPV];
    tp3 =(*Monitor[*)Table[tp2[[i]] // loopRulesPV[#, loopmoms, extmomsind, optloop] & // DotSimplify // DiracTraceExpand (*// # /. DiracTrace -> TR &*) // PVReduce[#, loopmoms, purePV, extmomsind] &, {i, Length@tp2}] // FCES(*,
    "tp3 1"]*);
  , "NumeratorReduction: PV reducing..."];
  
  
  (*4. contract the indices from the PV reduction*)
  Monitor[
    tp3 = Total[tp3] // CollectS[#, DiracPattern | _FVD | _MTD, # &, DiracSimplify] & // FCES(*//TimingS*);
  , "NumeratorReduction: Contracting the indices from the PV reduction..."];
  
  
  (*5. canonical index*)
  Monitor[
    dummyind = getdummyindices[tp3];
    indices1x = If[indices === {}, Complement[getfullindices[tp3], dummyind]~Join~{"dummyindices"}, indices];
    indices2 = Module[{},tp3 = tp3 /. Thread[dummyind -> Array[LorInd, Length@dummyind]];
    dummyind = Array[LorInd, Length@dummyind];
    indices1x /. "dummyindices" -> Sequence @@ dummyind];
   
    (*may be faster for simple case...*)
    tp3 = tp3 // CollectS[#, OperatorPattern, # &, RenameDummyInd] &;
   
  , "NumeratorReduction: Canonicalizing indices..."];
  
  (*6. replaced by operators*)
  
  If[indices =!= {} && ! SubsetQ[indices, Complement[getfullindices[tp3], dummyind]],
    Message[NumeratorReduction::index, Complement[getfullindices[tp3], dummyind]]];
  
  
  If[OptionValue["OperatorCollect"] == True,
    tp3 = FixedPoint[PolynomialCollect[indicesOrder[#, itc++; indices2, {}], OperatorPattern] &, tp3, maxit];
    Return[tp3]
  ];
  
  Monitor[
    If[OptionValue["OperatorReplace"] === False || operatorRules === {},
      tp3 = FixedPoint[(*TimingS[*)(indicesOrder[#, itc++; indices2, {}](*]*)&), tp3, maxit, SameTest -> ((PolynomialCollect[#1, DiracPattern]) === (PolynomialCollect[#2, DiracPattern]) &)];
      (*tp3=tp3//CollectS[#,_Dot|_Spinor|_DiracTrace,#&,RenameDummyInd]&//
      TimingS;*)
      ,
     
      TestFunction = (FreeQ[#, Spinor | DiracTrace] &);
      tp3 = tp3 // CollectS[#, OperatorPattern, # &, Replace[#, operatorRules]& ] &;
      For[num = 1, num <= maxit && ! TestFunction[tp3] && (PolynomialCollect[tp3, DiracPattern]) =!= (PolynomialCollect[tp4, DiracPattern]), itc++; num++,
        tp4 = tp3; tp3 = indicesOrder[tp3, indices2, operatorRules]](*//TimingS*);
    ];
  , {"NumeratorReduction: Indices ordering... ", itc}];
  
  (*Print[itc];*)
  
  If[itc >= maxit, Message[NumeratorReduction::maxit,(*maxit*)ToString[itc] <> " of " <> ToString[maxit]]];
  If[! FreeQ[tp3, Spinor] && operatorRules =!= {} && OptionValue["OperatorReplace"] == True, Message[NumeratorReduction::spinor]];
  
  (*tp3=tp3/.Dispatch[x:_SPD/;FreeQ[x,Alternatives@@loopmoms]:>spd@@
  x];*)(*to fix a bug when SPD[p1,
  p2] are not defined and appear in the denominators*)
  tp3 = tp3 // CollectS[#, _FVD | _MTD, # &, FCES@FCContract@# &] &;
  
  (*Abbreivate Spinors*)
  Monitor[
    {tp3, tp4} = AbbreviatePolynomials[tp3, OperatorPattern, "AbbreviatePolynomialsName" -> OptionValue["OperatorName"], "AbbreviatePolynomialsHead" -> OptionValue["OperatorHead"]];
  , {"NumeratorReduction: Abbreivating operators..."}];
  
  (*tpx10=tp3;*)
  (*make the further simplification more easier if we add this OperatorHead*)
  tp3 = Monitor[CollectS[tp3, x : _SPD /; ! FreeQ[x, Alternatives @@ loopmoms], OptionValue["NumeratorReductionSimplify"]], "NumeratorReduction: Simplifying with the option \"NumeratorReductionSimplify\"..."](*//TimingS*);
  (*although in the next step, we only concern about the SPD -> 
  deno to obtain scalar integrals, 
  we can still retain these structure for easier simplification...*)
  
  (*tp3=tp3/.Dispatch[spd->SPD];*)
  
  Switch[OptionValue["NumeratorReductionForm"], "ExpressionRules", {tp3, If[OptionValue["NumeratorReductionDispatch"], Dispatch@tp4, tp4]}, _, tp3 /. Dispatch@tp4]
  
]