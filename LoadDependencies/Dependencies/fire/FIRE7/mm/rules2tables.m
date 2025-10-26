(*Example usage under FIRE7/mm:
Get["rules2tables.m"];
rules2tables["example.rules", "example.tables"];
*)

rules2tables[rules_String, tables_String] := Put[rules2tables[Get[rules]], tables];

rules2tables[rules:{_Rule ..}] := Module[{integrals, integralHashCodes},
    integrals = Cases[rules, G[__], Infinity] // DeleteDuplicates;
    integralHashCodes = Range[Length[integrals]];
    {
        rules2tablesPart1[rules, integrals, integralHashCodes],
        rules2tablesPart2[integrals, integralHashCodes]
    }
]

rules2tablesPart2[integrals_List, integralHashCodes:{_Integer ..}] := Thread[{integralHashCodes, List@@@integrals}];

rules2tablesPart1[rules:{_Rule ..}, integrals_List, integralHashCodes:{_Integer ..}] := Module[{integral2hash, lhsList, rhsList},
    integral2hash = Dispatch[Thread[integrals -> integralHashCodes]];
    lhsList = rules[[All, 1]] /. integral2hash;
    rhsList = sum2list[rules[[All, 2]], integrals, integralHashCodes];
    Thread[{lhsList, rhsList}]
];

sum2list[reduced_List, integrals_, integralHashCodes_] := Module[{s}, Table[sum2list[s, integrals, integralHashCodes], {s, reduced}]];

sum2list[0, integrals_, integralHashCodes_] := {};

sum2list[s_, integrals_, integralHashCodes_] := Module[{entries, i},
    entries = ArrayRules[CoefficientArrays[s, integrals][[2]]][[1;;-2]];
    Table[
        {
            integralHashCodes[[entries[[i]][[1, 1]]]],
            entries[[i]][[2]]
        },
        {i, Length[entries]}
    ]
];
