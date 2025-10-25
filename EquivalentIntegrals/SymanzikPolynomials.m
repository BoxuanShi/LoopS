ClearAll[SymanzikPolynomials]
SymanzikPolynomials[x_, gpds_List, loops_List, process_Association : Hold@CurrentProcess] := Module[{p=ReleaseHold@process}, SymanzikPolynomials[x, gpds, loops, p["kinematics"]]]
SymanzikPolynomials[x_, gpds_List, loops_List, SPRep_List] := Module[{denominator, n, l, \[Lambda], A, B, C, U, F},
   denominator = gpds // Expand;
   {n = Length@gpds, l = Length@loops};
   denominator = Array[x, n] . denominator /. Thread[loops -> \[Lambda]*loops];
   (* no quadratic propagator*)
   If[Exponent[denominator, \[Lambda]] < 2, Return@{0, 0}];
   (*unknown structure*)
   If[Exponent[denominator, \[Lambda]] > 2, Print["Incorrect input for SymanzikPolynomials: {loops,gpds}=", {loops, gpds}]; Abort[];];
   {C, B, A} = CoefficientList[denominator, \[Lambda]];
   B = -1/2 Coefficient[B, #] & /@ loops;
   A = Table[If[i == j, Coefficient[A, loops[[i]]^2], 1/2 Coefficient[A, loops[[i]] loops[[j]]]], {i, l}, {j, l}];
   U = Det[A] // Expand;
   If[U === 0, Return@{0, 0}];(*singular case*)
   F = Expand[B . Cancel[U*Inverse[A]] . B - U* C] /. Thread[(SPRep[[All, 1]] /. SP -> Times) -> SPRep[[All, 2]]];
   {U, F} // Expand
   ];