(*ClearAll[IG]
IG[x_,props_List,loops_List,process_String:"CurrentProcess"]:=IG[x,props,\
loops,ToExpression[process]]
IG[x_,props_List,loops_List,process_Association]:=IG[x,props,loops,process[\
"kinematics"]]
IG[x_,props_List,loops_List,kinematicRules_List]:=Module[{props2,\[Nu]list,\
\[Nu],n,i,j,l,nloop,U,F},
props2=props//DeleteDuplicates[#,Factor[#1-#2]===0&]&;
\[Nu]list=Count[props-#//Factor,0]&/@props2;
{U,F}=SymanzikPolynomials[x,props2,loops,kinematicRules];
{\[Nu]=Total@\[Nu]list;n=Length@\[Nu]list,l=Length@loops};
Gamma[\[Nu]-l \
D/2]/Product[Gamma[\[Nu]list[[j]]],{j,n}]*Product[x[i]^(\[Nu]list[[i]]-1),{i,\
Length@\[Nu]list}]*U^(\[Nu]-(l+1)D/2)/F^(\[Nu]-l D/2)]*)

ClearAll[SymanzikPolynomials]
SymanzikPolynomials[x_, gpds_List, loops_List, 
  process_String : "CurrentProcess"] := 
 SymanzikPolynomials[x, gpds, loops, ToExpression[process]]
SymanzikPolynomials[x_, gpds_List, loops_List, process_Association] := 
 SymanzikPolynomials[x, gpds, loops, process["kinematics"]]
SymanzikPolynomials[x_, gpds_List, loops_List, SPRep_List] := 
  Module[{denominator, n, l, \[Lambda], A, B, C, U, F},
   denominator = gpds // Expand;
   {n = Length@gpds, l = Length@loops};
   denominator = Array[x, n] . denominator /. Thread[loops -> \[Lambda]*loops];
   (* no quadratic propagator*)
   If[Exponent[denominator, \[Lambda]] < 2, Return@{0, 0}];
   (*unknown structure*)
   If[Exponent[denominator, \[Lambda]] > 2, 
    Print["Incorrect input for SymanzikPolynomials: {loops,gpds}=", {loops, 
      gpds}]; Abort[];];
   {C, B, A} = CoefficientList[denominator, \[Lambda]];
   B = -1/2 Coefficient[B, #] & /@ loops;
   A = Table[
     If[i == j, Coefficient[A, loops[[i]]^2], 
      1/2 Coefficient[A, loops[[i]] loops[[j]]]], {i, l}, {j, l}];
   U = Det[A] // Expand;
   If[U === 0, Return@{0, 0}];(*singular case*)
   F = Expand[B . Cancel[U*Inverse[A]] . B - U* C] /. 
     Thread[(SPRep[[All, 1]] /. SP -> Times) -> SPRep[[All, 2]]];
   {U, F} // Expand];