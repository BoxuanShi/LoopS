SymanzikIndepentVars;

ClearAll[SymanzikIndepentVars]
SymanzikIndepentVars[propslist_List, loops_List, 
  process_String : "CurrentProcess"] := 
 SymanzikIndepentVars[propslist, loops, ToExpression[process]]
SymanzikIndepentVars[propslist_List, loops_List, process_Association] := 
 SymanzikIndepentVars[propslist, loops, process["kinematics"]]
SymanzikIndepentVars[propslist_List, loops_List, kinematics_List] := 
 Module[{x, syman, tp1, tp2},
  syman = SymanzikPolynomials[x, propslist, loops, kinematics][[2]];
  tp1 = CoefficientArrays[syman, getS[syman, _x]][[2 ;; -1]];
  tp1 = ArrayRules /@ tp1 // Flatten;
  tp1 = (FactorTermsList[#][[2]] &) /@ tp1[[All, 2]] // Expand // UnionS;
  tp1 // DeleteCases[#, 0] &]
SymanzikIndepentVars[symanF_, x_Symbol] := Module[{tp1, tp2},
  tp1 = CoefficientArrays[symanF, getS[symanF, _x]][[2 ;; -1]];
  tp1 = ArrayRules /@ tp1 // Flatten;
  tp1 = (FactorTermsList[#][[2]] &) /@ tp1[[All, 2]] // Expand // UnionS;
  tp1 // DeleteCases[#, 0] &]