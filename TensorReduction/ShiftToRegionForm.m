ClearAll[RegionBasis]
RegionBasis[loops_, process_String : "CurrentProcess"] := 
 RegionBasis[loops, ToExpression[process]]
RegionBasis[loops_, process_Association] := 
 RegionBasis[loops, process["extmomsind"]]
RegionBasis[loops_, 
  extmomsind_List] := {Momentum[#, D] & /@ loops, 
   Outer[Pair[Momentum[#1, D], Momentum[#2, D]] &, loops, 
    extmomsind]} // Flatten

ClearAll[ShiftToRegionForm]
ShiftToRegionForm[amp_, loopsRegion_List, pow_, 
  process_String : "CurrentProcess"] := 
 ShiftToRegionForm[amp, loopsRegion, pow, ToExpression@process]
ShiftToRegionForm[amp_, loopsRegion_List, pow_, process_Association] :=
  ShiftToRegionForm[amp, loopsRegion, pow, process["loopmoms"], 
  process["extmomsind"], process["moms"], process["kinematics"]]
ShiftToRegionForm[amp_, loopsRegion_List, pow_, loopmoms_, 
  extmomsind_List, moms_List, kinematics_] := 
 Module[{x, vars, shift, tpb1, tpb2, loopRules, tp0, tp1, tp2, tp3, 
   eqns, sol, rules1, rules},
  
  vars = Array[x, {Length@loopsRegion, Length@extmomsind}];
  shift = vars . extmomsind;
  
  tpb1 = 
   RegionBasis[loopsRegion, extmomsind] // ExpandMomentum[#, moms] & //
     ExpandScalarProduct;
  tpb2 = 
   RegionBasis[loopsRegion + shift, extmomsind] // 
     ExpandMomentum[#, moms] & // ExpandScalarProduct;
  loopRules = 
   Thread[tpb1 -> tpb2] // 
    AtomizeRules[#, RegionBasis[loopmoms, extmomsind]] &;
  
  tp0 = amp // ExpandMomentum[#, moms] & // ExpandScalarProduct;
  tp0 = tp0 /. loopRules;
  tp1 = tp0 // FeynAmpDenominatorSplit // FCES // 
    PolynomialCollect[#, 
      x : _FAD | _SFAD /; ! FreeQ[x, Alternatives @@ loopmoms], 
      "PolynomialCollectOperation" -> List] &;
  tp2 = tp1 // FADToProps // Flatten;
  eqns = 
   tp2 /. Thread[loopmoms -> 0] // TogetherExpand // # /. kinematics &;
  eqns = 
   Normal[Series[eqns, 
      Insert[ReplaceAt[pow, x_ :> x - 1, 2], 0, 2]]] // 
    Thread[# == 0] &;
  sol = Solve[eqns, Flatten@vars];
  If[sol === {}, Print["No solution."]; Print[Factor@eqns]; Abort[]];
  
  {tp0 /. sol[[1]] /. Thread[Flatten@vars -> 0] // DiracGammaExpand //
     FCES, Thread[
    loopsRegion -> (loopsRegion + shift /. sol[[1]] /. 
       Thread[Flatten@vars -> 0])]}
  ]