SymanzikOrder;

ClearAll[SymanzikOrder]
SymanzikOrder[polynomial_, vshead_Symbol, n_Integer : -1] := Module[
      {vs, vt, crs, gcd, cmx, cns, cas, cps, cvs, ord, max},
  vs = getS[polynomial, _vshead];
  
      (* check: variables *)
      vt = vs;
      If[vt === {}, vt = Variables[polynomial]];
      (* -- (1) -- *)
      (* polynomial -> coefficient rules *)
      crs = CoefficientRules[polynomial, vt];
      (* possible common factor *)
      gcd = PolynomialGCD @@ (Last /@ crs);
      (* rules -> matrix of exponents, coefficients *)
      cmx = Append[First[#],(* (*Simplify*)Expand[Last[#]/gcd]*)1] & /@ crs;
      (* operate on the transposed *)
      cmx = Transpose[Sort[cmx]];
      (* -- (2) -- *)
      (* initialize list of column numbers, permutations *)
      cns = Range[Length[vt]];
      cas = {{}};
      (* iterate until all variables ordered *)
      While[
           Length[First[cas]] < Length[vt],
           (* -- (3) -- *)
           (* extended permutations *)
           
   cps = Join @@ (Function[ca, Append[ca, #] & /@ Complement[cns, ca]] /@ cas);
           (* -- (4) -- *)
           (* candidate vectors *)
           cvs = (cmx[[Prepend[#, -1]]]  (* coefficients, swap rows *)
                       // Transpose           (* -> columns *)
                      // Sort                (* sort rows *)
                     // Transpose           (* -> columns *)
                    // Last) & /@ cps;     (* extract vector *)
           (* -- (5) -- *)
           (* lexicographical ordering *)
           ord = Ordering[cvs];
           (* maximum vector *)
           max = cvs[[Last[ord]]];
           (* -- (6) -- *)
           (* select (maximum number of) candidate permutations *)
           cas = Part[cps, Select[ord, cvs[[#]] === max & ]];
           cas = If[n >= 0 && n < Length[cas], Take[cas, n], cas]
       ];
      (* -- (7) -- *)
      (* result: canonical orderings *)
      cas
  ]