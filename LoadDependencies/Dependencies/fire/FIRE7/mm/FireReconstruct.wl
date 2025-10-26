(* ::Package:: *)

BeginPackage["FireReconstruct`"];


matrixToFireTable;
vectorToFireTable;
scalarToFireTable;
numericalTableName;
firePrimeList;
calculateAndExportMatrix;
calculateAndExportVector;
calculateAndExportScalar;
listTableFiles;
deleteTableFiles;
tableToArrayRules;
tableToMatrix;
tableToVector;
tableToScalar;
reconstructThiele;
reconstructNumeratorNewton;
reconstructBalancedZippelNewton;
reconstructRational;
$reconstruct;


Begin["`Private`"];


$reconstruct = "bin/reconstruct";


matrixToFireTable[mat_?MatrixQ] := Module[{part1, part2, i, j},
    part1 =
    Table[
        {i,
            Select[
                Table[{j, ToString[mat[[i, j]], InputForm]}, {j, 1, Dimensions[mat][[2]]}],
                #[[2]] =!= "0" &
            ]
        },
        {i, 1, Dimensions[mat][[1]]}
    ];
    part2 = Table[{i, {1, {i}}},
        {i, Dimensions[mat][[2]]}
    ];
    {part1, part2}
];


vectorToFireTable[vec_List] := matrixToFireTable[{vec}];


scalarToFireTable[a_] := matrixToFireTable[{{a}}];


numericalTableName[tableBaseName_String, variableInitialValues_List, variablePowers_List, nthPrime_Integer] := Module[{extraString, i},
    If[!StringContainsQ[tableBaseName, ".tables"],
        Message[numericalTableName::badFileName]; Return[$Failed]];
    If[Length[variableInitialValues]!=Length[variablePowers],
        Message[numericalTableName::lengthMismatch]; Return[$Failed]];
    extraString = Table[
        If[MatchQ[variableInitialValues[[i]], {_Symbol, _Integer}], (* like {y, 41} *)
            "_" <> ToString[variableInitialValues[[i, 1]]], (* like _y *)
            "_" <> ToString[variableInitialValues[[i]]] <> "^" <> ToString[variablePowers[[i]]]
        ],
        {i, Length[variableInitialValues]}];
    StringReplace[tableBaseName,
        ".tables" -> StringJoin[extraString, "_", ToString[nthPrime]] <> ".tables"]
];
numericalTableName::badFileName = "First argument of numericalTableName must be a string ending with .tables";
numericalTableName::lengthMismatch:="Second and third arguments of numericalTableName must be lists of identical length";


$calculateAndExport[userFunction_, variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String, toTableConversion_] :=
Module[{raw, table, outputFile, i},
    outputFile = numericalTableName[tableBaseName, variableInitialValues, variablePowers, nthPrime];
    If[FileExistsQ[outputFile], Print["File already exists, not running again for ", variablePowers]; Return[outputFile]];
    If[Length[variableInitialValues] != Length[variablePowers], 
        Message[$calculateAndExport::lengthMismatch]; Return[$Failed]];
    raw = userFunction[
        Table[
            PowerMod[variableInitialValues[[i]], variablePowers[[i]], firePrimeList[[nthPrime]]],
            {i, Length[variableInitialValues]}],
        firePrimeList[[nthPrime]]];
    table = toTableConversion[raw];
    Put[table, outputFile];
    Return[outputFile];
];

calculateAndExportMatrix[userFunction_, variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String] :=
$calculateAndExport[userFunction, variableInitialValues, variablePowers, nthPrime, tableBaseName, matrixToFireTable];

calculateAndExportVector[userFunction_, variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String] :=
$calculateAndExport[userFunction, variableInitialValues, variablePowers, nthPrime, tableBaseName, vectorToFireTable];

calculateAndExportScalar[userFunction_, variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String] :=
$calculateAndExport[userFunction, variableInitialValues, variablePowers, nthPrime, tableBaseName, scalarToFireTable];


listTableFiles[tableBaseName_String] := FileNames[StringReplace[tableBaseName, ".tables" -> "_*.tables"]];
deleteTableFiles[tableBaseName_String] := DeleteFile[listTableFiles[tableBaseName]];


tableToArrayRules[table_] := Table[
    {table[[1, i]][[1]], table[[1, i]][[2, j, 1]]} -> 
        ToExpression[table[[1, i]][[2, j, 2]]],
    {i, Length[table[[1]]]},
    {j, Length[table[[1, i]][[2]]]}
] // Flatten[#, 1]&;

tableToMatrix[table_] := tableToArrayRules[table] // SparseArray // Normal;
tableToMatrix[table_, {nRows_, nCols_}] := tableToArrayRules[table] // SparseArray[#, {nRows, nCols}]& // Normal;
tableToVector[table_] := tableToMatrix[table][[1]];
tableToVector[table_, len_] := tableToMatrix[table, {1, len}][[1]];
tableToScalar[table_] := tableToMatrix[table][[1,1]];


reconstructUnivariate[variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String, method_String] :=
Module[
    {positionReconstructed, thieleLimit, var, initialVal, outputTableFile, commandAndArgs},
    positionReconstructed = 
        Select[Range[Length[variableInitialValues]], 
            MatchQ[variableInitialValues[[#]], {_Symbol, _Integer}] &];
    If[Length[positionReconstructed] != 1,
        Message[reconstructThiele::wrongNumReconstruct];
        Return[$Failed]
    ];
    {var, initialVal} = variableInitialValues[[positionReconstructed[[1]]]];
    thieleLimit = variablePowers[[positionReconstructed[[1]]]];
    outputTableFile = numericalTableName[tableBaseName, variableInitialValues, variablePowers, nthPrime];
    commandAndArgs = {"../bin/reconstruct",
        "--method", method,
        "--variables", ToString[var],
        "--reconstruction_variable", 
        ToString[var] <> "_" <> ToString[initialVal],
        "--geometric",
        "--prime", ToString[nthPrime],
        outputTableFile,
        ToString[thieleLimit]
    };
    Print["Running command:\n", StringRiffle[commandAndArgs, " "]];
    Echo[RunProcess[commandAndArgs, "StandardOutput"]]
];

reconstructThiele[variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String] :=
reconstructUnivariate[variableInitialValues, variablePowers, nthPrime, tableBaseName, "thiele"];

reconstructNumeratorNewton[variableInitialValues_List, variablePowers_List, nthPrime_Integer, tableBaseName_String] :=
reconstructUnivariate[variableInitialValues, variablePowers, nthPrime, tableBaseName, "numeratorNewton"];


(* Currently only supported for bivariate case*)
reconstructBalancedZippelNewton[{{var1_, initialVal1_}, {var2_, initialVal2_}}, {var1ZippelLimit_Integer, var2NewtonLimit_Integer}, nthPrime_Integer, tableBaseName_String] :=
Module[{outputTableFile, commandAndArgs},
    outputTableFile = numericalTableName[tableBaseName, {{var1, initialVal1}, {var2, initialVal2}},  {var1ZippelLimit, var2NewtonLimit}, nthPrime];
    commandAndArgs = {"../bin/reconstruct",
        "--method", "balancedZippelNewton",
        "--balancing_variables", ToString[var1] <> "_" <> ToString[initialVal1],
        "--reconstruction_variable", ToString[var2] <> "_" <> ToString[initialVal2] <> "_" <> ToString[var2NewtonLimit],
        "--prime", ToString[nthPrime],
        outputTableFile,
        ToString[var1ZippelLimit]
    };
    Print["Running command:\n", StringRiffle[commandAndArgs, " "]];
    Echo[RunProcess[commandAndArgs, "StandardOutput"]]
];


reconstructRational[vars_List, nPrimes_, tableBaseName_String] := Module[{varsString, outputTableFile, commandAndArgs, primeArg},
    If[IntegerQ[nPrimes],
        primeArg = ToString[nPrimes],
        If[MatchQ[nPrimes, {_Integer, _Integer}] && nPrimes[[2]] > nPrimes[[1]],
            primeArg = ToString[nPrimes[[1]]] <> ":" <> ToString[nPrimes[[2]] - nPrimes[[1]] + 1],
            primeArg = "failed"
        ]
    ];
    If[primeArg == "failed",
        Print["Invalid second argument for reconstructRational"];
        Return[$Failed]
    ];
    varsString = StringJoin[{"_", ToString[#]} & /@ vars];
    outputTableFile = StringReplace[tableBaseName, ".tables" -> varsString <> "_0.tables"];
    commandAndArgs = {"../bin/reconstruct",
        "--method", "rational",
        "--variables", varsString,
        outputTableFile,
        primeArg
    };
    Print["Running command:\n", StringRiffle[commandAndArgs, " "]];
    Echo[RunProcess[commandAndArgs, "StandardOutput"]];
];

    
    


firePrimeList = {18446744073709551557, 18446744073709551533,
18446744073709551521, 18446744073709551437, 18446744073709551427,
18446744073709551359, 18446744073709551337, 18446744073709551293,
18446744073709551263, 18446744073709551253, 18446744073709551191,
18446744073709551163, 18446744073709551113, 18446744073709550873,
18446744073709550791, 18446744073709550773, 18446744073709550771,
18446744073709550719, 18446744073709550717, 18446744073709550681,
18446744073709550671, 18446744073709550593, 18446744073709550591,
18446744073709550539, 18446744073709550537, 18446744073709550381,
18446744073709550341, 18446744073709550293, 18446744073709550237,
18446744073709550147, 18446744073709550141, 18446744073709550129,
18446744073709550111, 18446744073709550099, 18446744073709550047,
18446744073709550033, 18446744073709550009, 18446744073709549951,
18446744073709549861, 18446744073709549817, 18446744073709549811,
18446744073709549777, 18446744073709549757, 18446744073709549733,
18446744073709549667, 18446744073709549621, 18446744073709549613,
18446744073709549583, 18446744073709549571, 18446744073709549519,
18446744073709549483, 18446744073709549441, 18446744073709549363,
18446744073709549331, 18446744073709549327, 18446744073709549307,
18446744073709549237, 18446744073709549153, 18446744073709549123,
18446744073709549067, 18446744073709549061, 18446744073709549019,
18446744073709548983, 18446744073709548899, 18446744073709548887,
18446744073709548859, 18446744073709548847, 18446744073709548809,
18446744073709548703, 18446744073709548599, 18446744073709548587,
18446744073709548557, 18446744073709548511, 18446744073709548503,
18446744073709548497, 18446744073709548481, 18446744073709548397,
18446744073709548391, 18446744073709548379, 18446744073709548353,
18446744073709548349, 18446744073709548287, 18446744073709548271,
18446744073709548239, 18446744073709548193, 18446744073709548119,
18446744073709548073, 18446744073709548053, 18446744073709547821,
18446744073709547797, 18446744073709547777, 18446744073709547731,
18446744073709547707, 18446744073709547669, 18446744073709547657,
18446744073709547537, 18446744073709547521, 18446744073709547489,
18446744073709547473, 18446744073709547471, 18446744073709547371,
18446744073709547357, 18446744073709547317, 18446744073709547303,
18446744073709547117, 18446744073709547087, 18446744073709547003,
18446744073709546897, 18446744073709546879, 18446744073709546873,
18446744073709546841, 18446744073709546739, 18446744073709546729,
18446744073709546657, 18446744073709546643, 18446744073709546601,
18446744073709546561, 18446744073709546541, 18446744073709546493,
18446744073709546429, 18446744073709546409, 18446744073709546391,
18446744073709546363, 18446744073709546337, 18446744073709546333,
18446744073709546289, 18446744073709546271,
13043817825332782193, 13043817825332782171, 13043817825332782093, 
 13043817825332782079, 13043817825332782073, 13043817825332782003, 
 13043817825332782001, 13043817825332781913, 13043817825332781847, 
 13043817825332781841, 13043817825332781779, 13043817825332781749, 
 13043817825332781689, 13043817825332781677, 13043817825332781587, 
 13043817825332781563, 13043817825332781419, 13043817825332781413, 
 13043817825332781391, 13043817825332781349, 13043817825332781293, 
 13043817825332781287, 13043817825332781241, 13043817825332781211, 
 13043817825332781173, 13043817825332781131, 13043817825332781107, 
 13043817825332781061, 13043817825332780987, 13043817825332780933, 
 13043817825332780807, 13043817825332780747, 13043817825332780701, 
 13043817825332780693, 13043817825332780683, 13043817825332780659, 
 13043817825332780627, 13043817825332780617, 13043817825332780579, 
 13043817825332780573, 13043817825332780459, 13043817825332780449, 
 13043817825332780429, 13043817825332780399, 13043817825332780329, 
 13043817825332780221, 13043817825332780219, 13043817825332780119, 
 13043817825332780099, 13043817825332780089, 13043817825332780051, 
 13043817825332779997, 13043817825332779981, 13043817825332779957, 
 13043817825332779913, 13043817825332779799, 13043817825332779763, 
 13043817825332779753, 13043817825332779733, 13043817825332779643, 
 13043817825332779627, 13043817825332779543, 13043817825332779489, 
 13043817825332779307, 13043817825332779283, 13043817825332779171, 
 13043817825332779057, 13043817825332778983, 13043817825332778971, 
 13043817825332778943, 13043817825332778941, 13043817825332778893, 
 13043817825332778881, 13043817825332778857, 13043817825332778823, 
 13043817825332778719, 13043817825332778709, 13043817825332778593, 
 13043817825332778581, 13043817825332778493, 13043817825332778461, 
 13043817825332778359, 13043817825332778349, 13043817825332778301, 
 13043817825332778271, 13043817825332778217, 13043817825332778149, 
 13043817825332778109, 13043817825332778103, 13043817825332778073, 
 13043817825332778061, 13043817825332778053, 13043817825332777971, 
 13043817825332777939, 13043817825332777921, 13043817825332777911, 
 13043817825332777839, 13043817825332777761, 13043817825332777753, 
 13043817825332777677, 13043817825332777627, 13043817825332777573, 
 13043817825332777513, 13043817825332777383, 13043817825332777377, 
 13043817825332777321, 13043817825332777299, 13043817825332777291, 
 13043817825332777111, 13043817825332777011, 13043817825332776973, 
 13043817825332776957, 13043817825332776873, 13043817825332776849, 
 13043817825332776847, 13043817825332776841, 13043817825332776813, 
 13043817825332776799, 13043817825332776717, 13043817825332776667, 
 13043817825332776639, 13043817825332776607, 13043817825332776501,     
 13043817825332776477, 13043817825332776463, 13043817825332776441,
 13043817825332776411, 13043817825332776373,
 2147483647, 2147483629, 2147483587, 2147483579, 2147483563, 2147483549, 2147483543, 2147483497, 2147483489, 2147483477, 2147483423, 2147483399, 2147483353, 2147483323, 2147483269, 
 2147483249, 2147483237, 2147483179, 2147483171, 2147483137, 2147483123, 2147483077, 2147483069, 2147483059, 2147483053, 2147483033, 2147483029, 2147482951, 2147482949, 2147482943, 
 2147482937, 2147482921, 2147482877, 2147482873, 2147482867, 2147482859, 2147482819, 2147482817, 2147482811, 2147482801, 2147482763, 2147482739, 2147482697, 2147482693, 2147482681, 
 2147482663, 2147482661, 2147482621, 2147482591, 2147482583, 2147482577, 2147482507, 2147482501, 2147482481, 2147482417, 2147482409, 2147482367, 2147482361, 2147482349, 2147482343, 
 2147482327, 2147482291, 2147482273, 2147482237, 2147482231, 2147482223, 2147482121, 2147482093, 2147482091, 2147482081, 2147482063, 2147482021, 2147481997, 2147481967, 2147481949, 
 2147481937, 2147481907, 2147481901, 2147481899, 2147481893, 2147481883, 2147481863, 2147481827, 2147481811, 2147481797, 2147481793, 2147481673, 2147481629, 2147481571, 2147481563, 
 2147481529, 2147481509, 2147481499, 2147481491, 2147481487, 2147481373, 2147481367, 2147481359, 2147481353, 2147481337, 2147481317, 2147481311, 2147481283, 2147481269, 2147481263, 
 2147481247, 2147481209, 2147481199, 2147481179, 2147481173, 2147481151, 2147481143, 2147481139, 2147481071, 2147481053, 2147481031, 2147481019, 2147480989, 2147480971, 2147480969, 
 2147480957, 2147480941, 2147480927, 2147480921, 2147480899, 2147480897, 2147480893, 2147480849
 };


End[]


EndPackage[]
