BeginPackage["FIRE`"];

ToLeeRule::usage = "ToLeeRule[diag, sector, expr] created a Litered rule solving completely a sector based on expr. expr should be build by Y[i], Ym[i], A[i] operators as provided by the IBP[k,l] functions and means that expr operator is true everywhere in the sector. The diag is just a Litered diagram label and sector is the sector being solved (list of 1 and -1). The result (if available) comes as a pair. The first member of the pair is the relation that should be put in the corresponding jRules file. The second is the ordering. AFTER calling TranformRules and BEFORE calling SaveSBases one should set SBasisO[0, sector] = ordering."

SolveSectors::usage = "SolveSectors[diag, options] goes through all the LiteRed unique sectors of diag and tries each of them searching whether any of the IBPs can produce a solution for the sector.";

Begin["`Private`"];

ToLeeRule[diag_, sector_, expr_, verbose_:True] := Module[{n = Length[sector], temp, result, shifts, matrix, indices, Z, v, coeff},
    temp = Expand[expr*(j @@ Prepend[Table[0, {n}], diag])];
    temp = temp //. {Y[i_]*j[diag, vars__] :> j @@ Prepend[ReplacePart[{vars}, i -> {vars}[[i]] + 1], diag],
                    Ym[i_]*j[diag, vars__] :> j @@ Prepend[ReplacePart[{vars}, i -> {vars}[[i]] - 1], diag], a[i_] :> v[i]};
    coeff = Coefficient[temp, j @@ Prepend[Table[0, {n}], diag]];
    (*Print[temp];
    Print[coeff];*)
    If[coeff == 0,
        If[verbose,Print["Incorrect expression"]];
        Return[Null];
    ];
    result = Collect[(temp/.{(j @@ Prepend[Table[0, {n}], diag])->0})/(-coeff), j[__]];
    (* let us search for the proper ordering *)
    shifts = (If[## === 1, 1, -1] & /@ sector)*(List@@Delete[##,1]) & /@ Cases[result, j[__], {0, Infinity}];
    If[Max @@ Plus @@@ shifts > 0,
        If[verbose,
            Print["Positive shift detected"];
            Print[shifts];
        ];
        Return[Null];
    ];
    shifts = Select[shifts, ((Plus @@ ##) === 0) &];
    shifts = Union[shifts];
    If[verbose,
        Print[shifts];
    ];
    indices = Table[0, n];
    matrix = {Table[1, n]};
    While[And[shifts =!= {}, Max @@ Max @@@ shifts =!= 0],
        temp = If[And[Max @@ ## <= 0, Min @@ ## === -1], True, False] & /@ Transpose[shifts];
        temp = Position[temp, True];
        If[temp === {},
            If[verbose,
                Print["Cannot find decreasing index"];
            ];
            Return[Null];
        ];
        temp = temp[[1, 1]];
        If[verbose,
            Print["Decreasing index is ", temp];
        ];
        AppendTo[matrix, ReplacePart[Table[0, n], temp -> 1]];
        indices[[temp]] = 1;
        shifts = Select[shifts, (##[[temp]] =!= -1) &];
        If[verbose,
            Print[shifts];
        ];
   ];
    For[temp = 1, temp <= n, ++temp,
        If[indices[[temp]] === 0,
            AppendTo[matrix, ReplacePart[Table[0, n], temp -> 1]]
        ]
    ];
    result = result /. {j[diag, vars__] :> j @@ Prepend[{vars} + v /@ Range[n], diag]};
    result = result /. {v[i_] :> ToExpression["n" <> ToString[i]]};
    result = Rule[j @@ Prepend[ToExpression["(n" <> ToString[##[[1]]] <> "_)?" <> If[##[[2]] === 1, "Positive", "NonPositive"]] & /@ Transpose[{Range[n], sector}], diag], Collect[result, j[__], Factor]];
    {Drop[matrix, -1], result}
]

FindLeeRule[internal_, external_, propagators_, replacements_, diag_, sector_, verbose_:True] := Module[{temp, i, j, k, l, us, coeff, rep, rule, lrule},
    For[i=1, i<=Length[internal],++i,
        For[j=1, j<=Length[propagators],++j,
            us = Extract[propagators[[j]], Append[##, 1] & /@ Position[propagators[[j]], Power[_, 2]]]; (* under squares *)
            For[k=1, k<= Length[us], ++k,
                If[MemberQ[Variables[us[[k]]],internal[[i]]],
                    coeff = Coefficient[us[[k]], internal[[i]]];
                    If[coeff == -1,
                        us[[k]] = - us[[k]];
                        coeff = 1;
                    ];
                    If[coeff == 1,
                        rep = {internal[[i]] -> internal[[i]] - (us[[k]] - internal[[i]])};
                        ClearIBP[];
                        Internal = internal;
                        External = external;
                        Propagators = propagators /. rep;
                        Replacements = replacements;
                        If[PrepareIBP[False],
                            For[l=1, l<= Length[internal], ++l,
                                rule = IBP[internal[[l]], internal[[l]]] /. Replacements;
                                lrule = ToLeeRule[diag, sector, rule, False];
                                If[lrule =!= Null,
                                    If[verbose,
                                        Print[{rep, internal[[l]]}];
                                    ,
                                        ClearIBP[];
                                        Return[{rep, internal[[l]], lrule}];
                                    ]
                                ]
                            ];
                        ];
                    ];
                ];
            ]
        ]
    ];
    ClearIBP[];
]

SolveSectors[diag_, options:OptionsPattern[Global`FIRE]] := Module[{dir = LiteRed`BasisDirectory[diag], oldPrepared=False,count=0,sectors,sector, internalTemp, externalTemp, propagatorsTemp, replacementsTemp, res, file, i},
    internalTemp = Internal;
    externalTemp = External;
    propagatorsTemp = Propagators;
    replacementsTemp = Replacements;
    If[PrepareIBPd === True,
        ClearIBP[];
        oldPrepared = True;
    ];
    sectors = LiteRed`UniqueSectors[diag];
    If[OptionValue["Parallel"],
        DistributeDefinitions[internalTemp, externalTemp, propagatorsTemp, replacementsTemp, diag, FindLeeRule, PrepareIBP, ClearIBP, IBP];
        DistributeDefinitions["FIRE`"];
        SetSharedFunction[SBasisO];
        SetSharedVariable[count];
    ];
    If[OptionValue["Parallel"], ParallelMap, Map][(sector = If[##==1, 1, -1] &/@ (List @@ Delete[##, 1]);
        res = FindLeeRule[internalTemp, externalTemp, propagatorsTemp, replacementsTemp, diag, sector, False];
        If[res =!= Null,
            Print["Solved: ", sector];
            Print[Take[res,2]];
            file = dir<>"/"<>"jRules["<>ToString[diag]<>", ";
            For[i = 1, i<= Length[sector], ++i,
                file = file <> If[sector[[i]] == 1, "1", "0"] <> ", ";
            ];
            file = StringDrop[file, -2];
            file = file <> "]";
            Put[res[[3,2]], file];
            SBasisO[0, sector] = res[[3,1]];
            count += 1;
        ];
    )&, sectors, {1}];
    Print["Totally solved ", count, " sectors"];
    file = dir<>"/ExtraOrderings.m";
    If[FileExistsQ[file],
        DeleteFile[file];
    ];
    Save[file, SBasisO];
    ClearIBP[];
    Internal = internalTemp;
    External = externalTemp;
    Propagators = propagatorsTemp;
    Replacements = replacementsTemp;
    If[oldPrepared,
        PrepareIBP[];
    ];
]

End[];
EndPackage[];
