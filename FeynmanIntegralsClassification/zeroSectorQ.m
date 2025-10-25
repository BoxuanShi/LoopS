ClearAll[zeroSectorQ]
zeroSectorQ[pdlist0_, loops_List, process_String : "CurrentProcess"] := zeroSectorQ[pdlist0, loops, ToExpression[process]]
zeroSectorQ[pdlist0_, loops_List, process_Association] := zeroSectorQ[pdlist0, loops, process["kinematics"]]
zeroSectorQ[pdlist0_List, loops_List, SPRep_List] := Module[{pdlist, i, pos, n = Length@pdlist0, G, x, k, xprod, eq, eqlist, mat, redmat},
	(*pdlist=Cases[pdlist0,a_/;FreeQ[Denominator[a],Alternatives@@loops]];*)
	pdlist = Union@Cases[pdlist0, a_ /; FreeQ[Denominator[a], Alternatives @@ loops]];
  	If[Length@loops === 0, Return[False, Module]];
  	If[n === 0, Return[True, Module]];	
  	(*calculate G=U+F*)
  	G = Plus @@ SymanzikPolynomials[x, pdlist, loops, SPRep];
  	(*Eq.(16) of 1310.1145: Criterion is Sum[k[i]x[i]D[G,x[i]],{i,n}] = G with G=F+U*)	
  	eq = Sum[k[i]*x[i]*D[G, x[i]], {i, n}] - G // Expand;
  	If[eq === 0, Return[True]];
  	(*As k's are independent of x's, coefficients of x's must vanish*)
  	eqlist = Separate[eq, _x][[1]];
  	(*change equations to matrix form*)
  	mat = Append[Coefficient[eqlist, #] & /@ Array[k, n], eqlist /. _k -> 0] // Transpose;
  	(*solve equations*)
  	redmat = RowReduce[mat];
  	(*If no solution, there must be a line {0,...,0,1}*)
  	If[Select[redmat, #[[-1]] =!= 0 && Union@#[[1 ;; -2]] === {0} &] === {}, True, False]
  	]
zeroSectorQ[pdlist_FAD | pdlist_SFAD, loops_, kinematics_] := zeroSectorQ[FADToProps[pdlist, List], loops, kinematics]