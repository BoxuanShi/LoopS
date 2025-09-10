If[Length[ReadList["!git log --oneline -1 2>/dev/null", String]] == 1,
    Print["Current commit: ", ReadList["!git log --oneline -1 2>/dev/null", String][[1]]];
]

IntegralLevel[G[_,indices_List]] := (Plus @@ (If[## > 0, 1, 0] & /@ indices));
IntegralSector[G[_,indices_List]] := (If[## > 0, 1, 0] & /@ indices);
IntegralComplexity[G[_,indices_List]] := Plus @@ (If[## > 0, ## - 1, -##] & /@ indices);

(*  select integrals of level n *)
SelectNPos[list_, n_] :=  Select[list, (Plus @@ (If[## > 0, 1, 0] & /@ (##[[2]])) == n) &];

(* finds factors either depending on more than variable, or quadratic *)
FindBadFactorsInCoefficient[expr_, badLength_:Infinity] := Module[{temp, vars}, 
    temp = First/@FactorList[expr];
    temp = Select[temp, Or[
                            And[MemberQ[Variables[##], d], 
                                Or[Length[Variables[##]] > 1, And[Length[Variables[##]] == 1, Exponent[##, Variables[##][[1]]]>1]]
                            ],
                            Length[Expand[##]] > badLength
                        ]&];
    temp = If[(First[##] /. (Rule[##, 1] & /@ Variables[First[##]])) < 0, -##, ##] & /@temp; (*make free term positive *)
    temp
];

(*  This function takes only parts of rules that belong to a certain level.
    this is equivalent to setting all masters above and below to zero.
    The new relations are generally incorrect, but search for a good basis can be performed with them*)

LevelPart[rules_, level_] := Rule[First[##], Select[Last[##], (IntegralLevel[First[##]] == level) &]] & /@ Select[rules, (IntegralLevel[First[##]] == level) &];

FindBadFactorsInRules[expr_, level_:0, onlyCurrent_:False, badLength_:Infinity] := Module[{temp = expr},
    If[level > 0,
        temp = Select[temp, (IntegralLevel[##[[1]]] == level) &]; 
        If[onlyCurrent,
            temp = Rule[First[##], Select[Last[##], (IntegralLevel[##[[1]]] == level)&]]&/@temp;        
        ];
    ];
    Union[Flatten[ParallelMap[FindBadFactorsInCoefficient[Denominator[Together[Last[##]]], badLength]&, Flatten[Last /@ temp, 1]]]]
]

SubstituteRuleIntoRules[rules_, rule_] := Module[{temp, pos2},
    Return[Join[Map[CompoundExpression[
                    pos2 = Position[##, rule[[1]]], 
                    If[pos2 === {},                     
                        ##, (* right hand of this rule needs no replacement *)
                        Rule[##[[1]],
                            (* Print[pos2[[1,2]]]; *)
                            coeff = ##[[2, pos2[[1, 2]], 2]];
                            (* Print[coeff]; *)
                            temp = Join[Delete[##[[2]], pos2[[1, 2]]], {##[[1]], coeff*##[[2]]}&/@rule[[2]]]; 
                            (*substitute one rule into another, need to combine repeating terms now *)
                            temp = Reap[Sow[##[[2]], ##[[1]]] & /@ temp, _, {#1, If[Length[#2] === 1, #2[[1]], Together[Plus @@ #2]]} &][[2]];
                            (* collect coefficients with same G, take Together if there is more than one coefficient *)
                            temp = DeleteCases[temp, {_, 0}];
                            (* the coefficient could have cancelled out *)
                            temp
                        ]
                    ]
          ]&, Select[rules, (##[[1]] =!= rule[[1]])&] ,{1}],
        {rule}]];
]

(*  perform a replacement in the set of rules 
    replacement is a direct Mathematica rule without lists or coefficients *)
ReplaceIntegralInRules[rules_, replacement_] := Module[{temp, pos, rule, pos2, coeff},
    pos = Position[First/@rules, replacement[[2]]];
    If[pos === {},
        Print["Error in ReplaceIntegralInRules"];
        Print[replacement];
        Abort[];
    ];
    rule = rules[[pos[[1,1]]]];
    pos2 = Position[rule, replacement[[1]]][[1,2]];
    coeff = rule[[2, pos2, 2]];
    rule = Rule[replacement[[1]], Append[{##[[1]],-##[[2]]/coeff}&/@Delete[rule[[2]], pos2], {replacement[[2]], 1/coeff}]];
    (*Print[rule];*)
    (* inverting the rule according to replacement *)
    Return[Join[SubstituteRuleIntoRules[Delete[rules,pos],rule],{Rule[replacement[[2]], {{replacement[[2]], 1}}]}]];
    (*  we remove the rule for replacement[[2]], which is not a master initially 
        then we substtute the new rule for replacement[[1]] everywhere
        then we add a trivial rule for replacement[[2]], which becomes a master *)
]


(*  the input format should be a list of rules, right-hand sides consisting of lists of pairs - coefficient and integral
    the format for an integral is G[pn, {indices}] *)
ImproveMasters[rules_, level_, badLength_:Infinity] := Module[{expr = rules, newPreferred, allPreferred = {}},
    While[True,
        {expr, newPreferred} = ImproveMastersStep[expr, level, badLength];
        If[newPreferred == {}, Break[]];
        Print["Step finished"];
        allPreferred = Join[allPreferred, newPreferred];
    ];
    {expr, allPreferred}
]

(* keeps only parts of relations if integrals of this level containing bad coefficients *)
(* if last parameter is True, leaves only mappings from this level to this level *)
BadRelationParts[rules_, level_:0, onlyCurrent_:False, badLength_:Infinity] := Module[{temp, levelRules, badRules},
    If[level>0,
        levelRules = Select[rules, (IntegralLevel[##[[1]]] == level) &]; (* rules for integrals for this level *)
        If[onlyCurrent,
            levelRules = Rule[First[##], Select[Last[##], (IntegralLevel[##[[1]]] == level)&]]&/@levelRules; (* and keep them to current level *)
        ];
    ,
        levelRules = rules;
    ];
    badRules = ParallelMap[Rule[First[##], {First[##],FindBadFactorsInCoefficient[Denominator[Together[Last[##]]], badLength]}&/@Last[##]]&, levelRules, {1}];
    badRules = Rule[First[##], DeleteCases[Last[##], {_, {}}]] &/@ badRules;
    badRules = DeleteCases[badRules, Rule[_,{}]];
    badRules
]

(* transform a relation from a sum format to a list format *)
(* the relation should have already collected coeffs *)
RelationSum2List[relation_Rule] := Module[{temp, GGG},
    temp = Collect[Last[relation], G[__], GGG];
    temp = If[Head[temp] === Plus, List@@temp, {temp}];
    temp = List @@@ temp;
    GGG = Identity;
    Rule[First[relation],temp]
]

RelationList2Sum[relation_Rule] := Rule[relation[[1]], Plus @@ Times @@@ relation[[2]]]

ImproveMastersStep[rules_, level_, badLength_:Infinity] := Module[{temp, masters, integrals, levelIntegrals, allRules = rules, levelRules, badRules, badDenominators, badDenominatori, badLevelMastersi, badSector, alternativeMasters, alternativeMaster, i, ruleToBad, ji, sectorRules, newPreferred, smallestAlternative, restartSearch, badSectorMasters, sectorMasters},
    masters = Union @@ Map[First, Last /@ rules, {2}]; (* integrals appearing on the right-hand side *)
    integrals = First /@ rules; (* integrals appearing on the left-hand side *)
    levelIntegrals = SelectNPos[integrals, level]; (* integrals of this level *)
    levelRules = Select[rules, (IntegralLevel[##[[1]]] == level) &]; (* rules for integrals for this level *)
    levelRules = {##[[1]], Select[##[[2]], (IntegralLevel[##[[1]]] == level)&]}&/@levelRules; (* and keep them to current level *)
    badRules = ParallelMap[{First[##],FindBadFactorsInCoefficient[Denominator[Together[Last[##]]], badLength]}&, Last/@levelRules, {2}]; (* replacing coeffs to lists of bad denominators *)
    badDenominators = Union[Flatten[Map[Last, badRules, {2}]]]; (* just a list of denominators *)
    If[badDenominators == {},
        Print["No bad denominators at level ", level];
        Return[{rules,{}}];
    ];
    Print["Bad denominators at level ", level, ": ", badDenominators];
    badDenominator = Last[badDenominators];
    Print["Working with ", badDenominator];
    temp = Position[badRules, badDenominator];
    (* where at the right sides we got that denominator *);
    badLevelMasters = SelectNPos[ Union[Extract[badRules, ReplacePart[Take[##, 3], 3 -> 1] & /@ temp]], level];
    Print["Bad masters resulting in that denominator: ", badLevelMasters];
    (* take the integrals of this level that got that bad coefficient *)
    temp = Union[(If[## >= 1, 1, 0] & /@ ##[[2]]) & /@ badLevelMasters]; (* their sectors *)
    If[Length[temp] > 1, 
        Print["They are in different sectors: "];
        Print[temp];
        badSector = temp[[1]];
        badSectorMasters = Select[badLevelMasters, ((If[## >= 1, 1, 0] & /@ ##[[2]]) == badSector) &];
        badSectorMasters = Reverse[SortBy[badSectorMasters, IntegralComplexity]];
        Print["Working in sector ", badSector];
        Print["Remaining masters: ", badSectorMasters];
    ,
        badSector = temp[[1]];
        badSectorMasters = badLevelMasters;
        badSectorMasters = Reverse[SortBy[badSectorMasters, IntegralComplexity]];
        Print["Working in sector ", badSector];
    ];
    Label[restartSearch];
    sectorMasters = Select[Union[First/@Flatten[Last/@levelRules,1]], (IntegralSector[##]==badSector)&];
    (* selecting all masters in this sector, not only those with a bad denominator *)
    alternativeMasters = SortBy[Complement[Select[levelIntegrals, ((If[## >= 1, 1, 0] & /@ ##[[2]]) == badSector) &], badSectorMasters], 
           {IntegralLevel, Reverse[Last[##]]&}];
    (* take reduces integrals in this sector, sort them by complexity and then by bigger first indices *)

    If[alternativeMasters == {},
        Print["All reduced integrals are masters!"];
        Return[{rules,{}}];
    ];
    smallestAlternative = {Infinity, 0, 0};
    For[i = 1, i <= Length[alternativeMasters], ++i,
        alternativeMaster = alternativeMasters[[i]];
        Print["Trying alternative master ", alternativeMaster];
        ruleToBad = Select[levelRules[[Position[First /@ levelRules, alternativeMaster][[1, 1]]]][[2]], MemberQ[badSectorMasters, ##[[1]]] &];
        ruleToBad = Reverse[SortBy[ruleToBad, IntegralComplexity[First[##]]&]];
        (* rule expressing the alternative master, and we take only the coefficients by bad masters *)
        (* Print[rulesToBad];*)
        For[j = 1, j <= Length[ruleToBad], ++j,
            temp = FindBadFactorsInCoefficient[Numerator[Together[Last[ruleToBad[[j]]]]], badLength];
            If[temp =!= {},
                (* there is another bad coefficient in numerator *)
                If[Length[temp] == 1,
                    If[Length[Expand[temp[[1]]]] < smallestAlternative[[1]],
                        smallestAlternative = {Length[Expand[temp[[1]]]], i, j};
                    ];
                ];
                Continue[];
            ];
            If[Not[MemberQ[FindBadFactorsInCoefficient[Denominator[Together[Last[ruleToBad[[j]]]]], badLength], badDenominator]],
                (* this expression does not have the bad coefficient in the denominator, it won't help *)
                Continue[];
            ];
            Break[];
            (*found*)
        ];
        If[j > Length[ruleToBad],
            (* no way for this alternative *)
            Print["Either does not help, or introduces another bad denominator"];
            Continue[];
        ];
        Print["Trying master replacement: ", Rule[ruleToBad[[j,1]], alternativeMaster]];
        sectorRules = Select[levelRules, ((If[## >= 1, 1, 0] & /@ ##[[1, 2]]) == badSector) &];
        temp = ReplaceIntegralInRules[sectorRules, Rule[ruleToBad[[j,1]], alternativeMaster]];
        (* try to make this replacement *)
        temp = Union[Flatten[ParallelMap[FindBadFactorsInCoefficient[Denominator[Together[Last[##]]], badLength] &, Last /@ temp, {2}]]];
        (* search for bad denominators again *)
        If[temp =!= {},
            Print["Bad denominators remaining in sector: ", temp];
            Continue[];
        ];
        Print["Master integrals in this sector (add to preferred):"];
        newPreferred = sectorMasters /. Rule[ruleToBad[[j,1]], alternativeMaster];
        Print[newPreferred];
        Print["Success, replacing everywhere"];
        Return[{ReplaceIntegralInRules[allRules, Rule[ruleToBad[[j,1]], alternativeMaster]],newPreferred}];
    ];
    Print["None of the alternatives can directly help!"];
    If[smallestAlternative[[1]] < Length[Expand[badDenominator]],
        Print["Trying to decrease denominator size from ", Length[Expand[temp[[1]]]], " to ", smallestAlternative[[1]]];
        i = smallestAlternative[[2]];
        j = smallestAlternative[[3]];
        alternativeMaster = alternativeMasters[[i]];
        ruleToBad = Select[levelRules[[Position[First /@ levelRules, alternativeMaster][[1, 1]]]][[2]], MemberQ[badSectorMasters, ##[[1]]] &];
        Print["Trying master replacement: ", Rule[ruleToBad[[j,1]], alternativeMaster]];
        sectorRules = Select[levelRules, ((If[## >= 1, 1, 0] & /@ ##[[1, 2]]) == badSector) &];
        temp = ReplaceIntegralInRules[sectorRules, Rule[ruleToBad[[j,1]], alternativeMaster]];
        temp = Union[Flatten[ParallelMap[FindBadFactorsInCoefficient[Denominator[Together[Last[##]]], badLength] &, Last /@ temp, {2}]]];
        If[And[Length[temp] === 1, Length[Expand[temp[[1]]]] === smallestAlternative[[1]]],
            Print["New factor is: ", temp[[1]]];
            badDenominator = temp[[1]];
            badSectorMasters = badLevelMasters /. Rule[ruleToBad[[j,1]], alternativeMaster];
            Print["Bad masters list is: ", badLevelMasters];
            Print["Replacing everywhere and trying to continue"];
            allRules = ReplaceIntegralInRules[allRules, Rule[ruleToBad[[j,1]], alternativeMaster]];
            levelRules = Select[allRules, (IntegralLevel[##[[1]]] == level) &]; (* rules for integrals for this level *)
            levelRules = {##[[1]], Select[##[[2]], (IntegralLevel[##[[1]]] == level)&]}&/@levelRules; (* and keep them to current level *)
            Goto[restartSearch];
        ,
            Print["Something went wrong, another bad factor appeared"];
            Print[temp];
        ];
    ];
    {rules, {}}
]

