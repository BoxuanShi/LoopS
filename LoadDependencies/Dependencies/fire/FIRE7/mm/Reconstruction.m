(* ::Package:: *)

(*
    Copyright (C) Alexander Smirnov.
    The program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2 as
    published by the Free Software Foundation.

    The program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
*)

If[Not[TrueQ[$VersionNumber>=6.0]],
    Print["Mathematica version 6 or higher expected"];
    Abort[];
];

If[Options[Reconstruction] === {},
    Options[Reconstruction] = {
        "Silent" -> True,
        "Factor" -> 1,
        "Parallel" -> False
    }
];

Reconstruction::usage = "The options of all reconstruction functions are:
Silent: whether to print less, True by default;
Factor: used for NewtonNewton and NewtonThiele reconstruction to multiply functions (getting rid of known denominator);
Parallel: whether to turn on parallel reconstruction.
";

BeginPackage["Reconstruction`"];

DenominatorFactor::usage = "DenominatorFactor[filename, dvar:d] gets out the smallest factor that is needed to make all coefficients polynomial ";

RationalReconstructTables::usage = "RationalReconstructTables[filename, pnum, options] runs rational reconstruction of tables whose name starts with filename; pnum is the number of first largest primes; The files name should have _0.table in the end";

ThieleReconstructTables::usage = "ThieleReconstructTables[filename, dvar->drange, options] runs Thiele reconstruction with the use of dvar. drange is the list of variable values; The files nama should have _dvar_ inside";

NewtonReconstructTables::usage = "NewtonReconstructTables[filename, dvar->drange, options] runs Newton reconstruction with the use of dvar. All coefficients are multiplied by factor. drange is the list of variable values; The files name should have _dvar_ inside";

BalancedNewtonReconstructTables::usage = "BalancedNewtonReconstructTables[filename, dvar->drange, xrules, options] runs balanced Newton reconstruction of a fraction. The original tables depend on xvar. The reconstruction goes over dvar. dd is the list of variable values; xrules might be of form xvar->rrange or a list of rules of this form The balancing value of xvar is xvalue, and the corresponding table should depend on dvar. The files name should have _dvar_ and _xvar_inside for all the xvar variables, might be contatenated as _dvar_xvar_ or other order";

BalancedZippelReconstructTables::usage = "BalancedNewtonReconstructTables[filename, skelvar->{skelvalue, curvalue}, reps, recvar->recvalue, {powerMin, powerMax}, options] runs balanced Zippel reconstruction of a fraction. filename/.skelvalue->curvalue is the target file. filename/.skelvalue->skelvalue is the skeleton file. filename/.skelvalue->curvalue/.recvar->recvalue is the balancing file. filename/.skelvalue->curvalue /. modified reps in powers is main file list";

NewtonNewtonReconstructTables::usage = "NewtonThieleReconstructTables[filename, dvar->drange, xvar->xrange, options] runs double Newton reconstruction with the use of dvar and xvar. All coefficients are multiplied by factor";

NewtonThieleReconstructTables::usage = "NewtonThieleReconstructTables[filename, dvar->drange, xvar->xrange, options] runs Newton by x and Thiele by d reconstruction with the use of d and x. All coefficients are multiplied by factor";

ApplyFunctionToTable::usage = "ApplyFunctionToTable[filename, newfilename, function] loads table from filename, applies function to each coefficient and saved to newfilename";

Begin["`Private`"];

Thiele[keys_, values_, d_, options:OptionsPattern[Global`Reconstruction]] := Module[{n = Length[keys], result, coeffs, i, temp, j, out, steps}, coeffs = Table[0, {n}];
    For[i = 1, i <= n, i++,
        temp = values[[i]];
        For[j = 1, j < i, j++,
            If[temp == coeffs[[j]],
                If[OptionValue["Silent"],
                    steps = i - 1;
                ,
                    Print["Thiele reconstruction stable after " <> ToString[i-1] <> " steps"];
                ];
                Goto[out];
            ];
            temp = (keys[[i]] - keys[[j]])/(temp - coeffs[[j]]);
        ];
        coeffs[[i]] = temp;
    ];
    If[OptionValue["Silent"],
        Return[{1,-1}];
    ,
        Print["Thiele reconstruction unstable"];
        Return[1];
    ];
    Label[out];
    n = i - 1;
    result = coeffs[[n]];
    For[i = n - 1, i >= 1, i--,
        result = coeffs[[i]] + (d - keys[[i]])/result;
    ];
    result = result // Together;
    If[OptionValue["Silent"],
        {result,steps}
    ,
        result
    ]
]

Newton[keys_, values_, d_, options:OptionsPattern[Global`Reconstruction]] := Module[{n = Length[keys], result, coeffs, i, temp, j, out, steps}, coeffs = Table[0, {n}];
    For[i = 1, i <= n, i++,
        temp = Expand[values[[i]] * (OptionValue["Factor"] /. {d->keys[[i]]})];
        For[j = 1, j < i, j++,
            If[temp == coeffs[[j]],
                If[OptionValue["Silent"],
                    steps = i - 1;
                ,
                    Print["Newton reconstruction stable after " <> ToString[i-1] <> " steps"];
                ];
                Goto[out];
            ];
            temp = Expand[(temp - coeffs[[j]])/(keys[[i]] - keys[[j]])];
        ];
        coeffs[[i]] = temp;
    ];
    If[OptionValue["Silent"],
        Return[{1,-1}];
    ,
        Print["Newton reconstruction unstable"];
        Return[1];
    ];
    Label[out];
    n = i - 1;
    result = coeffs[[n]];
    For[i = n - 1, i >= 1, i--,
        result = coeffs[[i]] + (d - keys[[i]]) * result;
    ];
    result = (result/OptionValue["Factor"]) // Together;
    If[OptionValue["Silent"],
        {result,steps}
    ,
        result
    ]
]

(* arguments:
* reconstructed function for another value of last variable (used for skeleton producing and balancing).
* first variable (reconstructed)
* set of new variable base replacements
* range of powers
* values of function to be reconstructed for these replacements
*)
Zippel[skelFunction_, reps_, powers_, values_, options:OptionsPattern[Global`Reconstruction]] := Module[{d, rules, mat, coeff, power, i, j, l, k, bs, res, base, mainPol, curPol},
    coeff = ExpandAll[skelFunction];
    If[Head[coeff] === Plus, coeff = List @@ coeff, coeff = {coeff}];
    l = Length[coeff];
    If[l > Length[values],
        If[OptionValue["Silent"],
            Return[{1,-1}];
        ,
            Print["Zippel reconstruction unstable "];
            Return[1];
        ];
    ];
    base = Table[Times @@ ((##[[2]]^Exponent[coeff[[i]], ##[[1]]]) & /@ reps), {i, l}]; (* we use the skeleton function to produce monomials without coeffs and substiture initial values *)
    mainPol = Times @@ ((d - ##) &/@ base);
    bs = Table[0, {l}];
    For[i = 1, i <= l, ++i,
        curPol = Expand[(1 / base[[i]]) * (Times @@ Table[If[i === j, 1, 1/(base[[i]] - base[[j]])], {j, l}]) * mainPol / (d - base[[i]])];
        curPol = CoefficientList[curPol, d]; (* it's not important that the letter is d, we just want coefficients*)
        bs[[i]] = Inner[Times, curPol, Take[values, Length[curPol]], Plus]; (* that was a row of inverse matrix *)
    ];
    res = Plus @@ Table[bs[[i]]*Times @@ ((##[[1]]^Exponent[coeff[[i]], ##[[1]]]) & /@ reps), {i, l}];
    res = Together[res];
    If[OptionValue["Silent"],
        {res, l}
    ,
        Print["Zippel reconstruction stable after " <> ToString[l] <> " steps"];
        res
    ]
];

(* arguments
 * reconstructed function for another value of last variable d->d0 (used for skeleton producing and balancing)
 * set of new variable base replacements
 * last variable mapped to its first value
 * the goal power for d
 * range of powers
 * values of fractions (by d, first variables are at reps values) to be reconstructed for these replacements
*)
BalancedZippel[skelFunction_, reps_, Rule[d_, {d0_, d1_}], powers_, values_, options:OptionsPattern[Global`Reconstruction]] := Module[{nums, dens, i, powersA},
    powersA = Table[i, {i, powers[[1]], powers[[2]]}];
    nums =
        Table[
                (Numerator[values[[i]]] /. {d -> d1}) /
                (Numerator[values[[i]]] /. {d -> d0}) *
                (Numerator[skelFunction] /. ((##[[1]] -> ##[[2]]^powersA[[i]]) & /@ reps))
            ,
                {i, Length[values]}
        ];
    dens =
        Table[
                (Denominator[values[[i]]] /. {d -> d1}) /
                (Denominator[values[[i]]] /. {d -> d0}) *
                (Denominator[skelFunction] /. ((##[[1]] -> ##[[2]]^powersA[[i]]) & /@ reps))
            ,
                {i, Length[values]}
        ];
    If[OptionValue["Silent"],
        temp = {Zippel[Numerator[skelFunction], reps, powers, nums, options], Zippel[Denominator[skelFunction], reps, powers, dens, options]};
        {temp[[1,1]]/temp[[2,1]], If[Or[temp[[1,2]]==-1,temp[[2,2]]==-1],-1,Max[temp[[1,2]],temp[[2,2]]]]}
    ,
        temp = Zippel[Denominator[skelFunction], reps, powers, dens, options];
        Zippel[Numerator[skelFunction], reps, powers, nums, options] / temp
    ]
]

BalancedNewton[keysIn_, valuesIn_, x0_, valueIn_, d_, x_, options:OptionsPattern[Global`Reconstruction]] := Module[{pos, temp, nums, dems, keys = keysIn, values = Together/@valuesIn, value = Together[valueIn], xRule},
    If[Head[x0] === List,
        xRule = Rule @@@ Transpose[{x, x0}];
        vars = x;
    ,
        xRule = {x -> x0};
        vars = {x};
    ];
    Check[
        temp = Exponent[Numerator[##], vars[[1]]] & /@ values;
        If[(Max @@ temp) =!= (Min @@ temp),
            If[Not[OptionValue["Silent"]],
                Print[temp];
                Print["Different exponents"];
            ];
            pos = Position[temp,Max @@ temp];
            values = Extract[values, pos];
            keys = Extract[keys, pos];
            temp = Exponent[Numerator[##], vars[[1]]] & /@ values;
            If[Not[OptionValue["Silent"]],
                Print[temp];
            ];
        ];
        temp = (Numerator[value] /. d -> ##) & /@ keys;
        pos = Position[temp, 0];
        If[pos =!= {},
            keys = DeleteCases[ReplacePart[keys, Rule[##, $Failed] & /@ pos], $Failed];
            values = DeleteCases[ReplacePart[values, Rule[##, $Failed] & /@ pos], $Failed];
        ];
        nums = Inner[Times, (Numerator[value] /. d -> ##) & /@ keys, (Numerator[##]/(Numerator[##] /. xRule)) & /@ values,  List];
        dems = Inner[Times, (Denominator[value] /. d -> ##) & /@ keys, (Denominator[##]/(Denominator[##] /. xRule)) & /@ values, List];
    ,
        Print[valuesIn]; Print[valueIn]; Abort[]
    ];
    If[OptionValue["Silent"],
        temp = {Newton[keys, Expand[nums], d, options], Newton[keys, Expand[dems], d, options]};
        {temp[[1,1]]/temp[[2,1]], If[Or[temp[[1,2]]==-1,temp[[2,2]]==-1],-1,Max[temp[[1,2]],temp[[2,2]]]]}
    ,
        temp = Newton[keys, Expand[dems], d, options];
        Newton[keys, Expand[nums], d, options] / temp
    ]
]

NewtonThiele[keysX_List, keysY_List, values_, x_, y_, options:OptionsPattern[Global`Reconstruction]] := Module[{n = Length[keysX] - 1, m = Length[keysY] - 1, f, X, Y, a, A, b, B, temp,result,M,newn,restart,i,j,k,newm},
    (*because we count from 0 *)
    X[i_] := keysX[[i + 1]];
    Y[i_] := keysY[[i + 1]];
    f[i_, j_] := values[[i + 1, j + 1]] * (OptionValue["Factor"] /. {x->X[i], y->Y[j]});

    newn = -2;

    (* part 1, building A[i,j] =
    coefficient of Newton d decomposition with x = Y[j]*)

    Label[restart];

    For[j = 0, j != m + 1, ++j, (* separately for each j*)
        For[i = 0, i != n + 1, ++i,
            a[i, 0, j] = f[i, j];
            For[k = 1, k != i + 1, ++k,
                a[i, k, j] = (a[i, k - 1, j] - A[k - 1, j](* = a[k - 1, k - 1, j]*))/(X[i] - X[k - 1]);
                (* we should not break in case of a[i,k,j] = 0; the final A can still be non-zero *)
            ];
            A[i, j] = a[i, i, j];
            If[And[A[i, j] == 0, i - 1 >= newn],
                Break[];
            ];
        ];
        Clear[a];
        If[newn == -2,
            (* first pass *)
            newn = i - 1;
        ];
        If[newn < i - 1,
            newn = i - 1;
            Clear[A];
            (* for some j we need a longer sequence, let's rebuild all *)
            Goto[restart];
        ];
    ];
    If[newn < n,
        n = newn;
        (*Print["Decreasing n to ", newn];*)
    ];

    (* part 2, building B[i,j] = coefficient of Newton-Thiele d-x decomposition*)

    For[i = 0, i != n + 1, ++i, (* separately for each i*)
        For[j = 0, j != m + 1, ++j,
            b[i, j, 0] = A[i, j];
            For[k = 1, k != j + 1, ++k,
                If[b[i, j, k - 1] == B[i, k - 1] (* = b[i, k - 1, k - 1] *),
                    Break[]; (*cannot build deeper*)
                ];
                b[i, j, k] = (Y[j] - Y[k - 1])/(b[i, j, k - 1] - B[i, k - 1] (* = b[i, k - 1, k - 1] *));
            ];
            If[k != j + 1,
                (*cannot build deeper, we need a check *)
                Clear[b];
                temp = B[i, j - 1];
                For[k = j - 2, k != -1, --k,
                    (* to avoid warnings or incorrect checks;  infinities may appear in the middle *)
                    If[temp === 0,
                        temp = Infinity
                    ,
                        If[temp === Infinity,
                            temp = B[i, k];
                        ,
                            temp = B[i, k] + (Y[j] - Y[k])/temp;
                        ]
                    ];
                ];
                If[temp === A[i, j],
                    (* this check is ok *)
                    Break[];
                ,
                    (* we failed to reconstruct. Ideally we should try another j-point, but it's not ready yet*)
                    (* starting j=0 and k = 1, not breaking; j goes to 1, and so M[i]!=-1*)
                    j = 0;
                ];
                Break[];
            ];
            B[i, j] = b[i, j, j];
            Clear[b];
        ];
        M[i] = j - 1; (* if it is m if went through or smaller otherwise *)
    ];
    Clear[A];

    newm = Max@@Array[M,n+1,{0,n}];

    If[Min@@Array[M,n+1,{0,n}] == -1,
        newm = m + 1;
    ];

    (*part 3, building A[i] = coefficient of Newton d decomposition *)

    For[i = 0, i != n + 1, ++i,(* separately for each j*)
        If[M[i] == -1,
            A[i] = 0;
            Continue[];
        ];
        A[i] = B[i, M[i]];
        For[j = M[i] - 1, j != -1, --j, (*recursively*)
            A[i] = B[i, j] + (y - Y[j])/A[i];
        ];
    ];
    Clear[B];

    (* part 4, building result *)

    result = A[n];
    For[i = n - 1, i != -1, --i,
        result = A[i] + (x - X[i])*result;
    ];
    Clear[A];

    n = Length[keysX] - 1;

    If[OptionValue["Silent"],
        {result/OptionValue["Factor"],{If[newn<n,newn,-1],If[newm<m,newm,-1]}}
    ,
        If[newn < n,
            If[newm < m,
                Print["NT reconstruction stable after ",{newn,newm}," steps"]
                ,
                If[newm == m,
                    Print["NT reconstruction is Thiele-unstable after ",{newn,newm}," steps"]
                ,
                    Print["NT reconstruction is Thiele-unstable after ",{newn,newm}," steps, possibly due to a choice of points. Debugging needed!"]
                ];
            ];
        ,
            If[newm < m,
                Print["NT reconstruction is Newton-unstable after ",{newn,newm}," steps"]
                ,
                If[newm == m,
                    Print["NT reconstruction is NT-unstable after ",{newn,newm}," steps"]
                ,
                    Print["NT reconstruction is NT-unstable after ",{newn,newm}," steps, possibly due to a choice of points. Debugging needed!"]
                ];
            ];
        ];
        Together[result/OptionValue["Factor"]]
    ]
]

NewtonNewton[keysX_List, keysY_List, values_, x_, y_, options:OptionsPattern[Global`Reconstruction]] := Module[{n = Length[keysX] - 1, m = Length[keysY] - 1, f, X, Y, a, A, b, B, temp,result,M,newn,restart,restart2,valuesR,i,j,k,newm},
    (*because we count from 0 *)
    X[i_] := keysX[[i + 1]];
    Y[i_] := keysY[[i + 1]];
    f[i_, j_] := values[[i + 1, j + 1]] * (OptionValue["Factor"] /. {x->X[i], y->Y[j]});
    newn = -2;
    (* part 1, building A[i,j] =
    coefficient of Newton x decomposition with y = Y[j]*)
    Label[restart];
    For[j = 0, j != m + 1, ++j, (* separately for each j*)
        For[i = 0, i != n + 1, ++i,
            a[i, 0, j] = f[i, j];
            For[k = 1, k != i + 1, ++k,
                a[i, k, j] = (a[i, k - 1, j] - A[k - 1, j](* = a[k - 1, k - 1, j]*))/(X[i] - X[k - 1]);
                (* we should not break in case of a[i,k,j] = 0; the final A can still be non-zero *)
            ];
            A[i, j] = a[i, i, j];
            If[And[A[i, j] == 0, i - 1 >= newn],
                Break[];
            ];
        ];
        Clear[a];
        If[newn == -2,
            (* first pass *)
            newn = i - 1;
        ];
        If[newn < i - 1,
            newn = i - 1;
            Clear[A];
            (* for some j we need a longer sequence, let's rebuild all *)
            Goto[restart];
        ];
    ];
    If[newn < n,
        n = newn;
    ];

    (* part 2, building B[i,j] = coefficient of Newton-Newton x-y decomposition*)
    newm = -2;
    Label[restart2];

    For[i = 0, i != n + 1, ++i, (* separately for each i*)
        For[j = 0, j != m + 1, ++j,
            b[i, j, 0] = A[i, j];
            For[k = 1, k != j + 1, ++k,
                b[i, j, k] = (b[i, j, k - 1] - B[i, k - 1])/(Y[j] - Y[k - 1]) (* = b[i, k - 1, k - 1] *);
            ];
            B[i, j] = b[i, j, j];
            If[And[B[i, j] == 0, j - 1 >= newm],
                Break[];
            ];
        ];
        Clear[b];
        If[newm == -2,
            (* first pass *)
            newm = j - 1;
        ];
        If[newm < j - 1,
            newm = j - 1;
            Clear[B];
            (* for some j we need a longer sequence, let's rebuild all *)
            Goto[restart2];
        ];
    ];
    Clear[A];

    (*part 3, building A[i] = coefficient of Newton x decomposition *)
    For[i = 0, i != n + 1, ++i,(* separately for each j*)
        A[i] = B[i, newm];
        For[j = newm - 1, j != -1, --j, (*recursively*)
            A[i] = B[i, j] + (y - Y[j])*A[i];
        ];
    ];
    Clear[B];

    (* part 4, building result *)

    result = A[n];
    For[i = n - 1, i != -1, --i,
        result = A[i] + (x - X[i])*result;
    ];
    Clear[A];

    n = Length[keysX] - 1;

    valuesR = Outer[((result/OptionValue["Factor"]) /. {x->#1, y->#2})&,keysX,keysY];
    If[valuesR != values,
        Print["Incorrect resonstruction!"];
        Print[keysX];
        Print[keysY];
        Print[values];
        Print[valuesR];
        Abort[];
    ];

    If[OptionValue["Silent"],
        {result/OptionValue["Factor"],{If[newn<n,newn,-1],If[newm<m,newm,-1]}}
    ,
        If[newn < n,
            If[newm < m,
                Print["NN reconstruction stable after ",{newn,newm}," steps"]
                ,
                If[newm == m,
                    Print["NN reconstruction is 2-unstable after ",{newn,newm}," steps"]
                ,
                    Print["NN reconstruction is 2-unstable after ",{newn,newm}," steps, possibly due to a choice of points. Debugging needed!"]
                ];
            ];
        ,
            If[newm < m,
                Print["NN reconstruction is 1-unstable after ",{newn,newm}," steps"]
                ,
                If[newm == m,
                    Print["NN reconstruction is 1-2-unstable after ",{newn,newm}," steps"]
                ,
                    Print["NN reconstruction is 1-2-unstable after ",{newn,newm}," steps, possibly due to a choice of points. Debugging needed!"]
                ];
            ];
        ];
        Together[result/OptionValue["Factor"]]
    ]
]

RationalReconstruct[a_Integer, p_Integer, options:OptionsPattern[Global`Reconstruction]] := Module[{g = a, s = 1, t = 0, g1 = p, s1 = 0, t1 = 1},
    While[Abs[g]^2 > p,
        {g, s, t, g1, s1, t1} = {g1, s1, t1, g - Quotient[g, g1] g1, s - Quotient[g, g1] s1, t - Quotient[g, g1] t1}
    ];
    g/s
];

RationalMod[a_, p_] := Mod[Numerator[a]*PowerMod[Denominator[a], -1, p], p];

RationalReconstruct[aa_List, pp_List, options:OptionsPattern[Global`Reconstruction]] := Module[{prod = 1, res = 0, resQ = 1, i, temp, steps = 0, resQprev = 0},
    For[i = 1, i <= Length[aa], ++i,
        res = ChineseRemainder[{res, aa[[i]]}, {prod, pp[[i]]}];
        prod = prod*pp[[i]];
        resQ = RationalReconstruct[res, prod, options];
        If[resQ == resQprev,
            If[OptionValue["Silent"],
                Return[{resQ,steps}];
            ,
                Print["Rational reconstruction stable after " <> ToString[steps] <> " steps"];
                Return[resQ];
            ];
        ];
        resQprev = resQ;
        steps++;
    ];
    If[OptionValue["Silent"],
        {resQ,-1}
    ,
        Print["Rational reconstruction unstable"];
        resQ
    ]
];

HardCodedPrimes := {2017, 18446744073709551557, 18446744073709551533, \
18446744073709551521, 18446744073709551437, 18446744073709551427, \
18446744073709551359, 18446744073709551337, 18446744073709551293, \
18446744073709551263, 18446744073709551253, 18446744073709551191, \
18446744073709551163, 18446744073709551113, 18446744073709550873, \
18446744073709550791, 18446744073709550773, 18446744073709550771, \
18446744073709550719, 18446744073709550717, 18446744073709550681, \
18446744073709550671, 18446744073709550593, 18446744073709550591, \
18446744073709550539, 18446744073709550537, 18446744073709550381, \
18446744073709550341, 18446744073709550293, 18446744073709550237, \
18446744073709550147, 18446744073709550141, 18446744073709550129, \
18446744073709550111, 18446744073709550099, 18446744073709550047, \
18446744073709550033, 18446744073709550009, 18446744073709549951, \
18446744073709549861, 18446744073709549817, 18446744073709549811, \
18446744073709549777, 18446744073709549757, 18446744073709549733, \
18446744073709549667, 18446744073709549621, 18446744073709549613, \
18446744073709549583, 18446744073709549571, 18446744073709549519, \
18446744073709549483, 18446744073709549441, 18446744073709549363, \
18446744073709549331, 18446744073709549327, 18446744073709549307, \
18446744073709549237, 18446744073709549153, 18446744073709549123, \
18446744073709549067, 18446744073709549061, 18446744073709549019, \
18446744073709548983, 18446744073709548899, 18446744073709548887, \
18446744073709548859, 18446744073709548847, 18446744073709548809, \
18446744073709548703, 18446744073709548599, 18446744073709548587, \
18446744073709548557, 18446744073709548511, 18446744073709548503, \
18446744073709548497, 18446744073709548481, 18446744073709548397, \
18446744073709548391, 18446744073709548379, 18446744073709548353, \
18446744073709548349, 18446744073709548287, 18446744073709548271, \
18446744073709548239, 18446744073709548193, 18446744073709548119, \
18446744073709548073, 18446744073709548053, 18446744073709547821, \
18446744073709547797, 18446744073709547777, 18446744073709547731, \
18446744073709547707, 18446744073709547669, 18446744073709547657, \
18446744073709547537, 18446744073709547521, 18446744073709547489, \
18446744073709547473, 18446744073709547471, 18446744073709547371, \
18446744073709547357, 18446744073709547317, 18446744073709547303, \
18446744073709547117, 18446744073709547087, 18446744073709547003, \
18446744073709546897, 18446744073709546879, 18446744073709546873, \
18446744073709546841, 18446744073709546739, 18446744073709546729, \
18446744073709546657, 18446744073709546643, 18446744073709546601, \
18446744073709546561, 18446744073709546541, 18446744073709546493, \
18446744073709546429, 18446744073709546409, 18446744073709546391, \
18446744073709546363, 18446744073709546337, 18446744073709546333, \
18446744073709546289, 18446744073709546271, \
13043817825332782193, 13043817825332782171, 13043817825332782093, \
 13043817825332782079, 13043817825332782073, 13043817825332782003, \
 13043817825332782001, 13043817825332781913, 13043817825332781847, \
 13043817825332781841, 13043817825332781779, 13043817825332781749, \
 13043817825332781689, 13043817825332781677, 13043817825332781587, \
 13043817825332781563, 13043817825332781419, 13043817825332781413, \
 13043817825332781391, 13043817825332781349, 13043817825332781293, \
 13043817825332781287, 13043817825332781241, 13043817825332781211, \
 13043817825332781173, 13043817825332781131, 13043817825332781107, \
 13043817825332781061, 13043817825332780987, 13043817825332780933, \
 13043817825332780807, 13043817825332780747, 13043817825332780701, \
 13043817825332780693, 13043817825332780683, 13043817825332780659, \
 13043817825332780627, 13043817825332780617, 13043817825332780579, \
 13043817825332780573, 13043817825332780459, 13043817825332780449, \
 13043817825332780429, 13043817825332780399, 13043817825332780329, \
 13043817825332780221, 13043817825332780219, 13043817825332780119, \
 13043817825332780099, 13043817825332780089, 13043817825332780051, \
 13043817825332779997, 13043817825332779981, 13043817825332779957, \
 13043817825332779913, 13043817825332779799, 13043817825332779763, \
 13043817825332779753, 13043817825332779733, 13043817825332779643, \
 13043817825332779627, 13043817825332779543, 13043817825332779489, \
 13043817825332779307, 13043817825332779283, 13043817825332779171, \
 13043817825332779057, 13043817825332778983, 13043817825332778971, \
 13043817825332778943, 13043817825332778941, 13043817825332778893, \
 13043817825332778881, 13043817825332778857, 13043817825332778823, \
 13043817825332778719, 13043817825332778709, 13043817825332778593, \
 13043817825332778581, 13043817825332778493, 13043817825332778461, \
 13043817825332778359, 13043817825332778349, 13043817825332778301, \
 13043817825332778271, 13043817825332778217, 13043817825332778149, \
 13043817825332778109, 13043817825332778103, 13043817825332778073, \
 13043817825332778061, 13043817825332778053, 13043817825332777971, \
 13043817825332777939, 13043817825332777921, 13043817825332777911, \
 13043817825332777839, 13043817825332777761, 13043817825332777753, \
 13043817825332777677, 13043817825332777627, 13043817825332777573, \
 13043817825332777513, 13043817825332777383, 13043817825332777377, \
 13043817825332777321, 13043817825332777299, 13043817825332777291, \
 13043817825332777111, 13043817825332777011, 13043817825332776973, \
 13043817825332776957, 13043817825332776873, 13043817825332776849, \
 13043817825332776847, 13043817825332776841, 13043817825332776813, \
 13043817825332776799, 13043817825332776717, 13043817825332776667, \
 13043817825332776639, 13043817825332776607, 13043817825332776501, \
 13043817825332776477, 13043817825332776463, 13043817825332776441, \
 13043817825332776411, 13043817825332776373};

CombineCoefficientsInTables[tablesIn_] := Module[{max, min, pos, diff, temp, tables = tablesIn},

    tables = First /@ tables;
    (* took the part with rules *)
    tables = Transpose[tables];
    (* dd first transpose collects rules for particular integrals consequently, each is a pair (integral and right value) *)
    tables = Transpose /@ tables;
    (* second transpose turns it into a pair of lists, first element should be a list of equal integrals, second - a list of values *)
    (* the following complcated construction is needed since some of the coefficients can turn to zero and we need to fill them*)
    tables = {First[##],
        temp = Last[##];
        max = Max @@ Length /@ temp;
        min = Min @@ Length /@ temp;
        If[max != min,
            pos = Position[Length /@ temp, max][[1, 1]];
            (* we take any one of the expressions with maximum length *)
            diff = First /@ temp[[pos]];
            (* we take the list of integrals appearing there *)
            temp = Reap[
                Sow["", ##] & /@ diff; (*sow expressions *)
                Sow[##[[2]], ##[[1]]] & /@ ##;  (*sow the real coeffs *),
                _, {{##}[[1]], If[Length[{##}[[2]]] === 1, "0", {##}[[2, 2]]]}&
            ][[2]] & /@ temp;
        ];
        Transpose /@ Transpose[temp]
    } & /@ tables;
    (*
        as a result the structure should be
        {{{integral,..., same integral}, {{{resulting integral, ... , same resulting integral}, {coeff,... another coeff}}, similar terms on the right side}}, similar rules}
    *)
    If[Max @@ First[##] =!= Min @@ First[##], 
        Print["Different integrals expressed in different tables"];
        Print[First[##]];
    ] & /@ tables;
    (* this checks that the same integrals are represented in different tables *)
    tables = {Max @@ First[##], Last[##]} & /@ tables;
    (* and we get rit if those repeatitions *)
    (If[Max @@ First[##] =!= Min @@ First[##], 
        Print["Repeating right-hand side error"];
        Print[First[##]];
        ] & /@ Last[##]) & /@ tables;
    (* this checks the {resulting integral, ... , same resulting integral statement *)
    tables = {First[##], {Max @@ First[##], Last[##]} & /@ Last[##]} & /@ tables;
    (* and we get rid of those repititions*)
    (*
        as a result the structure should be
        {{integral, {{resulting integral, {coeff,... another coeff}}, similar terms on the right side}}, similar rules}
    *)

    tables
]

RationalReconstructTables[filename_, pnum_Integer, options:OptionsPattern[Global`Reconstruction]] := RationalReconstructTables[filename, HardCodedPrimes[[##]] &/@ Range[2, pnum+1], options];

RationalReconstructTables[filename_, pp_List, options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, primes, convs, pvalues},
    If[StringPosition[filename, "_0."] === {},
        Print["No _0. pattern in filename"];
        Abort[];
    ];

    temp = filename;
    temp = Table[temp, {Length[pp]}];
    temp = Transpose[{temp, Range[1,Length[pp]]}];
    files = StringReplacePart[##[[1]], "_" <> ToString[##[[2]]] <> ".", Last[StringPosition[filename, "_0."]]] & /@ temp;
    tables = Quiet[Get /@ files];


    If[Position[tables,$Failed] =!= {},
        Print["Some of the tables are missing for ",filename];
        pos = Position[tables,$Failed];
        pvalues = Sort[Complement[pp,Extract[pp, pos]],Greater];
        tables = DeleteCases[tables, $Failed];
        Print["Remaning values length:", Length[pvalues]];
    ,
        pvalues = pp;
    ];

    If[Length[pvalues] == 0, Return[]];

    If[Position[tables,Null] =!= {},
        Print["Some of the tables are empty for ",filename];
        Print[Position[tables,Null]];
        pos = Position[tables,Null];
        pvalues = Sort[Complement[pvalues,Extract[pvalues, pos]],Greater];
        tables = DeleteCases[tables, Null];
        Print["Remaning values length:", Length[pvalues]];
    ];

    If[Length[pvalues] == 0, Return[]];

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;
    pos = Position[temp, min];
    temp2 = Transpose[{temp, pvalues}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
    ];
    tables = Extract[tables, pos];
    primes = Extract[pvalues, pos];
    convs = tables[[1]][[2]];  (*second part is equal*)

    tables = CombineCoefficientsInTables[tables];
    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = RationalReconstruct[ToExpression[Last[##]], primes, options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        If[Min@@temp == -1,
            Print["Rational reconstruction of one of the coefficients is unstable"];
            Return[];
        ,
            Print["Rational reconstruction stable after ",Max@@temp," steps"];
        ];
    ,
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##], RationalReconstruct[ToExpression[Last[##]], primes, options]} & /@ Last[##]}&, tables];
    ];
    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, filename];
]

ThieleReconstructTables[filename_, Rule[d_, dd_List], options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, dvalues, convs, max, diff},

    If[StringPosition[filename, "_" <> ToString[d] <> "_"] === {},
        Print["No _" <> ToString[d] <> "_ pattern in filename"];
        Abort[];
    ];

    temp = Table[filename, {Length[dd]}];
    temp = Transpose[{temp, dd}];
    files = StringReplacePart[##[[1]], "_" <> ToString[##[[2]]] <> "_", Last[StringPosition[filename, "_" <> ToString[d] <> "_"]]] & /@ temp;
    tables = Quiet[Get /@ files];

    If[Position[tables,$Failed] =!= {},
        Print["Some of the tables are missing"];
        pos = Position[tables,$Failed];
        dvalues = DeleteCases[ReplacePart[dd, Rule[##, $Failed] & /@ pos], $Failed];
        tables = DeleteCases[tables, $Failed];
        Print["Remaning values length:", Length[dvalues]];
    ,
        dvalues = dd;
    ];

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;
    pos = Position[temp, min];
    temp2 = Transpose[{temp, dvalues}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
    ];
    tables = Extract[tables, pos];
    dvalues = Extract[dvalues, pos];
    convs = tables[[1]][[2]];  (*second part is equal*)

    tables = CombineCoefficientsInTables[tables];
    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = Thiele[dvalues, ToExpression[Last[##]], d, options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        If[Min@@temp == -1,
            Print["Thiele reconstruction of one of the coefficients is unstable"];
        ,
            Print["Thiele reconstruction stable after ",Max@@temp," steps"];
        ];
    ,
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##], Thiele[dvalues, ToExpression[Last[##]], d]} & /@ Last[##]} &, tables];
    ];
    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, filename];
]

NewtonReconstructTables[filename_, Rule[d_, dd_List], options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, dvalues, convs},

    If[StringPosition[filename, "_" <> ToString[d] <> "_"] === {},
        Print["No _" <> ToString[d] <> "_ pattern in filename"];
        Abort[];
    ];

    temp = Table[filename, {Length[dd]}];
    temp = Transpose[{temp, dd}];
    files = StringReplacePart[##[[1]], "_" <> ToString[##[[2]]] <> "_", Last[StringPosition[filename, "_" <> ToString[d] <> "_"]]] & /@ temp;
    tables = Quiet[Get /@ files];

    If[Position[tables,$Failed] =!= {},
        Print["Some of the tables are missing"];
        pos = Position[tables,$Failed];
        dvalues = DeleteCases[ReplacePart[dd, Rule[##, $Failed] & /@ pos], $Failed];
        tables = DeleteCases[tables, $Failed];
        Print["Remaning values length:", Length[dvalues]];
    ,
        dvalues = dd;
    ];

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;
    pos = Position[temp, min];
    temp2 = Transpose[{temp, dvalues}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
    ];
    tables = Extract[tables, pos];
    dvalues = Extract[dvalues, pos];
    convs = tables[[1]][[2]];  (*second part is equal*)

    tables = CombineCoefficientsInTables[tables];
    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = Newton[dvalues, ToExpression[Last[##]], d, options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        If[Min@@temp == -1,
            Print["Newton reconstruction of one of the coefficients is unstable"];
        ,
            Print["Newton reconstruction stable after ",Max@@temp," steps"];
        ];
    ,
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##], Newton[dvalues, ToExpression[Last[##]], d, options]} & /@ Last[##]}&,tables];
    ];
    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, filename];
]

NewtonThieleReconstructTables[filename_, Rule[d_, dd_List], Rule[x_, xx_List], options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, dxvalues, convs},
    (* Newton by x *)
    If[StringPosition[filename, "_" <> ToString[d] <> "_"] === {},
        Print["No _" <> ToString[d] <> "_ pattern in filename"];
        Abort[];
    ];
    If[StringPosition[filename, "_" <> ToString[x] <> "_"] === {},
        Print["No _" <> ToString[x] <> "_ pattern in filename"];
        Abort[];
    ];

    temp = filename;
    temp = Table[temp, {Length[dd]*Length[xx]}];
    temp = Transpose[{temp, Tuples[{dd,xx}]}];
    files = (
        temp2 = StringReplacePart[##[[1]], "_" <> ToString[##[[2, 1]]] <> "_", Last[StringPosition[filename, "_" <> ToString[d] <> "_"]]];
        StringReplacePart[temp2, "_" <> ToString[##[[2, 2]]] <> "_", Last[StringPosition[temp2, "_" <> ToString[x] <> "_"]]]
    ) & /@ temp;

    tables = Get /@ files;
    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;
    pos = Position[temp, min];
    temp2 = Transpose[{temp, Tuples[{dd,xx}]}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
        Return[0];
    ];
    tables = Extract[tables, pos];
    dxvalues = Extract[Tuples[{dd,xx}], pos];

    convs = tables[[1]][[2]];  (*second part is equal*)

    tables = First /@ tables;
    tables = {First[##], Transpose /@ Transpose[Last[##]]} & /@ Transpose /@ Transpose[tables];
    (*in case of same table structure they are combined like standart tables, but on each place there is a list of coefficients; this will fail if something is wrong*)

    If[Max @@ First[##] =!= Min @@ First[##], Print["ERROR"]] & /@ tables;
    tables = {Max @@ First[##], Last[##]} & /@ tables;
    (*in case of same table structure they are combined like standart tables, but on each place there is a list of coefficients; this will fail if something is wrong*)
    (If[Max @@ First[##] =!= Min @@ First[##], Print["ERROR2"]] & /@ Last[##]) & /@ tables;
    tables = {First[##], {Max @@ First[##], Last[##]} & /@ Last[##]} & /@ tables;

    tables = {First[##], {First[##], Transpose[Partition[Last[##],Length[xx]]]} & /@ Last[##]} & /@ tables;
    (* partition into a matrix of values *)
    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = NewtonThiele[xx, dd, ToExpression[Last[##]], x, d, options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        temp = Transpose[temp];

        If[Min@@(temp[[1]])>=0,
            If[Min@@(temp[[2]])>=0,
                Print["NT reconstruction stable after ",{Max@@(temp[[1]]),Max@@(temp[[2]])}," steps"]
                ,
                Print["NT reconstruction of some coefficients is Thiele-unstable after ",{Max@@(temp[[1]]),Length[dd]}," steps"]
            ];
        ,
            If[Min@@(temp[[2]])>=0,
                Print["NT reconstruction of some coefficients is Newton-unstable after ",{Length[xx],Max@@(temp[[2]])}," steps"]
                ,
                Print["NT reconstruction of some coefficients is NT-unstable after ",{Length[dd],Length[xx]}," steps"]
            ];
        ];
    ,
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##], NewtonThiele[xx, dd, ToExpression[Last[##]], x, d, options]} & /@ Last[##]} &,tables];
    ];

    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;

    Put[{tables, convs}, filename];
]

NewtonNewtonReconstructTables[filename_, Rule[d_, dd_List], Rule[x_, xx_List], options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, dxvalues, convs},
    (* Newton by x *)
    If[StringPosition[filename, "_" <> ToString[d] <> "_"] === {},
        Print["No _" <> ToString[d] <> "_ pattern in filename"];
        Abort[];
    ];
    If[StringPosition[filename, "_" <> ToString[x] <> "_"] === {},
        Print["No _" <> ToString[x] <> "_ pattern in filename"];
        Abort[];
    ];

    temp = filename;
    temp = Table[temp, {Length[dd]*Length[xx]}];
    temp = Transpose[{temp, Tuples[{dd,xx}]}];
    files = (
        temp2 = StringReplacePart[##[[1]], "_" <> ToString[##[[2, 1]]] <> "_", Last[StringPosition[filename, "_" <> ToString[d] <> "_"]]];
        StringReplacePart[temp2, "_" <> ToString[##[[2, 2]]] <> "_", Last[StringPosition[temp2, "_" <> ToString[x] <> "_"]]]
    ) & /@ temp;
    tables = Get /@ files;

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;
    pos = Position[temp, min];
    temp2 = Transpose[{temp, Tuples[{dd,xx}]}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
        Return[0];
    ];
    tables = Extract[tables, pos];
    dxvalues = Extract[Tuples[{dd,xx}], pos];

    convs = tables[[1]][[2]];  (*second part is equal*)

    tables = First /@ tables;
    tables = {First[##], Transpose /@ Transpose[Last[##]]} & /@ Transpose /@ Transpose[tables];
    (*in case of same table structure they are combined like standart tables, but on each place there is a list of coefficients; this will fail if something is wrong*)

    If[Max @@ First[##] =!= Min @@ First[##], Print["ERROR"]] & /@ tables;
    tables = {Max @@ First[##], Last[##]} & /@ tables;
    (*in case of same table structure they are combined like standart tables, but on each place there is a list of coefficients; this will fail if something is wrong*)
    (If[Max @@ First[##] =!= Min @@ First[##], Print["ERROR2"]] & /@ Last[##]) & /@ tables;
    tables = {First[##], {Max @@ First[##], Last[##]} & /@ Last[##]} & /@ tables;

    tables = {First[##], {First[##], Transpose[Partition[Last[##],Length[xx]]]} & /@ Last[##]} & /@ tables;
    (* partition into a matrix of values *)
    If[OptionValue["Silent"],
        tables = If[
            TrueQ[OptionValue["Parallel"]],
            ParallelMap,
            Map
        ][
            {
                First[##],
                {First[##],
                    temp = NewtonNewton[xx, dd, ToExpression[Last[##]], x, d, options];
                    {temp[[1]],temp[[2]]}
                } & /@ Last[##]
            } &,
            tables
        ];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        temp = Transpose[temp];

        If[Min@@(temp[[1]])>=0,
            If[Min@@(temp[[2]])>=0,
                Print["NN reconstruction stable after ",{Max@@(temp[[1]]),Max@@(temp[[2]])}," steps"]
                ,
                Print["NN reconstruction of some coefficients is 2-unstable after ",{Max@@(temp[[1]]),Length[dd]}," steps"]
            ];
        ,
            If[Min@@(temp[[2]])>=0,
                Print["NN reconstruction of some coefficients is 1-unstable after ",{Length[xx],Max@@(temp[[2]])}," steps"]
                ,
                Print["NN reconstruction of some coefficients is 1-2-unstable after ",{Length[dd],Length[xx]}," steps"]
            ];
        ];
    ,
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##], NewtonNewton[xx, dd, ToExpression[Last[##]], x, d, options]} & /@ Last[##]} &, tables];
    ];

    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, filename];
]

BalancedZippelReconstructTables[filename_, Rule[recvar_, {skelvalue_, curvalue_}], reps_, powers_, options:OptionsPattern[Global`Reconstruction]] := Module[{temp, powersA, files, tables, tfile, i, pos, dd, dvalues, btableName, btable, skeltableName, skeltable, convs, temp2, min},

    powersA = Table[i, {i, powers[[1]], powers[[2]]}];
    (
        If[StringPosition[filename, "_" <> ToString[##] <> "_"] === {},
            Print["No _" <> ToString[##] <> "_ pattern in filename"];
            Abort[];
        ];
    ) &/@ Join[First/@reps, {recvar}];

    temp = Table[filename, {Length[powersA]}];
    temp = Transpose[{temp, powersA}];
    files = (
        tfile = ##[[1]];
        For[i=1, i<=Length[reps], ++i,
            tfile = StringReplacePart[
                        tfile,
                        "_" <> ToString[reps[[i,2]]] <> "^" <> ToString[##[[2]]] <> "_",
                        Last[StringPosition[tfile, "_" <> ToString[reps[[i,1]]] <> "_"]]
                    ];
        ];
        tfile
    )&/@temp;
    tables = Quiet[Get /@ files];
    If[Position[tables,$Failed] =!= {},
        Print["Some of the tables are missing"];
        pos = Position[tables,$Failed];
        dvalues = DeleteCases[ReplacePart[powersA, Rule[##, $Failed] & /@ pos], $Failed];
        tables = DeleteCases[tables, $Failed];
        Print["Remaning values length:", Length[dvalues]];
    ,
        dvalues = powersA;
    ];

    skeltableName = filename;
    skeltableName = StringReplacePart[skeltableName, "_" <> ToString[skelvalue] <> "_", Last[StringPosition[skeltableName, "_" <> ToString[recvar] <> "_"]]];

    skeltable = Quiet[Get[skeltableName]];
    If[skeltable == $Failed,
        Print["Balancing table does not exist"];
        Print[skeltableName];
        Abort[];
    ];

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;

    If[min =!= Length[skeltable[[2]]],
        Print["Skeleton table has too many master integrals"];
        Abort[];
    ];

    pos = Position[temp, min];
    temp2 = Transpose[{temp, dvalues}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
    ];
    tables = Extract[tables, pos];
    dvalues = Extract[dvalues, pos];
    convs = tables[[1]][[2]];  (*second part is equal*)

    AppendTo[tables,skeltable]; (*adding skeleton table before the transformation*)

    tables = CombineCoefficientsInTables[tables];
    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = BalancedZippel[ToExpression[Last[##][[-1]]], reps, recvar -> {skelvalue, curvalue}, powers, ToExpression[Drop[Last[##], -1]], options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        If[Min@@temp == -1,
            Print["Zippel reconstruction of one of the coefficients is unstable"];
        ,
            Print["Zippel reconstruction stable after ",Max@@temp," steps"];
        ];
    ,
        tables = If[
            TrueQ[OptionValue["Parallel"]],
            ParallelMap,
            Map
        ][
            {
                First[##],
                {First[##], BalancedZippel[ToExpression[Last[##][[-1]]], reps, recvar -> {skelvalue, curvalue}, powers, ToExpression[Drop[Last[##], -1]], options]} & /@ Last[##]
            } &,
            tables
        ];
    ];
    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, StringReplacePart[filename, "_" <> ToString[curvalue] <> "_", Last[StringPosition[filename, "_" <> ToString[recvar] <> "_"]]]];
]

BalancedNewtonReconstructTables[filename_, Rule[d_, dd_List], xRule_, options:OptionsPattern[Global`Reconstruction]] := Module[{temp, temp2, files, tables, min, pos, dvalues, convs, btable, 
            xRuleLocal, btableName, i},
    If[Head[xRule] === List,
        xRuleLocal = xRule;
    ,
        xRuleLocal = {xRule};
    ];

    If[StringPosition[filename, "_" <> ToString[d] <> "_"] === {},
        Print["No _" <> ToString[d] <> "_ pattern in filename"];
        Abort[];
    ];

    temp = Table[filename, {Length[dd]}];
    temp = Transpose[{temp, dd}];
    files = StringReplacePart[##[[1]], "_" <> ToString[##[[2]]] <> "_", Last[StringPosition[filename, "_" <> ToString[d] <> "_"]]] & /@ temp;
    tables = Quiet[Get /@ files];

    If[Position[tables,$Failed] =!= {},
        Print["Some of the tables are missing"];
        pos = Position[tables,$Failed];
        dvalues = DeleteCases[ReplacePart[dd, Rule[##, $Failed] & /@ pos], $Failed];
        tables = DeleteCases[tables, $Failed];
        Print["Remaning values length:", Length[dvalues]];
    ,
        dvalues = dd;
    ];

    btableName = filename;
    For[i = 1, i<= Length[xRuleLocal], ++i,
        btableName = StringReplacePart[btableName, "_" <> ToString[xRuleLocal[[i, 2]]] <> "_", Last[StringPosition[btableName, "_" <> ToString[xRuleLocal[[i, 1]]] <> "_"]]];
    ];

    btable = Quiet[Get[btableName]];
    If[btable == $Failed,
        Print["Balancing table does not exist"];
        Print[btableName];
        Abort[];
    ];

    temp = Length[##[[2]]] & /@ tables; (*searching for longer second parts and removing*)

    min = Min @@ temp;

    If[min =!= Length[btable[[2]]],
        Print["Balancing table has too many master integrals"];
        Abort[];
    ];

    pos = Position[temp, min];
    temp2 = Transpose[{temp, dvalues}];
    temp2 = Delete[temp2, pos];
    If[Length[temp2] > 0,
        Print["Dropping results for " <> ToString[Last /@ temp2]];
    ];
    tables = Extract[tables, pos];
    dvalues = Extract[dvalues, pos];
    convs = tables[[1]][[2]];  (*second part is equal*)

    AppendTo[tables,btable]; (*adding balancing table before the transformation*)

    tables = CombineCoefficientsInTables[tables];

    If[OptionValue["Silent"],
        tables = If[TrueQ[OptionValue["Parallel"]],ParallelMap,Map][{First[##], {First[##],
                temp = BalancedNewton[dvalues, ToExpression[Drop[Last[##],-1]], Last/@xRuleLocal, ToExpression[Last[Last[##]]], d, First/@xRuleLocal, options];
                {temp[[1]],temp[[2]]}
            } & /@ Last[##]} &,tables];
        temp = Reap[
            tables = {First[##], {First[##], Sow[##[[2,2]]]; ##[[2,1]]} &/@ Last[##]} &/@ tables
        ][[2]];
        If[Min@@temp == -1,
            Print["Newton reconstruction of one of the coefficients is unstable"];
        ,
            Print["Newton reconstruction stable after ",Max@@temp," steps"];
        ];
    ,
        tables = If[
            TrueQ[OptionValue["Parallel"]],
            ParallelMap,
            Map
        ][
            {
                First[##],
                {First[##], BalancedNewton[dvalues, ToExpression[Drop[Last[##],-1]], Last/@xRuleLocal, ToExpression[Last[Last[##]]], d, First/@xRuleLocal, options]} & /@ Last[##]
            } &,
            tables
        ];
    ];
    tables = {First[##], {First[##], ToString[Last[##], InputForm]} & /@ Last[##]} & /@ tables;
    Put[{tables, convs}, filename];
]

DenominatorFactor[filename_, options:OptionsPattern[Global`Reconstruction]] := Module[{tables},
    tables = Get[filename];
    tables = First[tables];
    tables = Transpose[tables];
    tables = Last[tables];
    tables = Flatten[tables, 1];
    tables = Transpose[tables];
    tables = Last[tables];
    tables = ToExpression /@ tables;
    tables = Denominator /@ tables;
    tables = Select[FactorList[##], (Length[Variables[##[[1]]]]>0)&]&/@ tables;
    tables = Apply[Power, tables, {2}];
    tables = Apply[Times, tables, {1}];
    PolynomialLCM @@ tables
]

ApplyFunctionToTable[filename_, newfilename_, function_] := Module[{tables},
    tables = Get[filename];
    tables = {{##[[1]], {##[[1]], ToString[function[ToExpression[Last[##]]], InputForm]}&/@Last[##]}&/@First[tables],  tables[[2]]};
    Put[tables, newfilename];
]

End[];
EndPackage[];
