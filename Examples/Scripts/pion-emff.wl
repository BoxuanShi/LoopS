scriptDir = DirectoryName[ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
]];
projectRoot = ParentDirectory[ParentDirectory[scriptDir]];
Get[FileNameJoin[{projectRoot, "LoopS.m"}]];

ScriptFail[message_String] := (Print[message]; Exit[1]);
AssertTrue[test_, message_String] := If[! TrueQ[test], ScriptFail[message]];

epsorder[_] = 0;

exampleRoot = ParentDirectory[NotebookDirectoryS[]];
inputDir = FileNameJoin[{exampleRoot, "Inputs", "PionEMFF"}];
referenceDir = FileNameJoin[{exampleRoot, "References", "PionEMFF"}];

PionEMFF = CreateProcess[
  "ProcessName" -> "PionEMFF",
  "loopmoms" -> {l1, l2},
  "extmomsind" -> {p, pp},
  "kinematics" -> {p^2 -> 0, pp^2 -> 0, p*pp -> 1/2},
  "extramoms" -> {p1, p2, p3, p4},
  "indices" -> {p, \[Mu], "dummyindices", pp}
];

AlgebrasDefinition["PionEMFF"] := Module[{},
  Momentum[p1, D] = x1 Momentum[p, D];
  Momentum[p2, D] = x2 Momentum[p, D];
  Momentum[p3, D] = y1 Momentum[pp, D];
  Momentum[p4, D] = y2 Momentum[pp, D];
];

ClearProcess["PionEMFF"] := Module[{}, Nothing];

SetupProcess["PionEMFF"];
AssertTrue[CurrentProcess["ProcessName"] === "PionEMFF", "PionEMFF setup failed."];
AssertTrue[DirectoryQ[ProcessPath], "PionEMFF process path was not created."];
AssertTrue[StringStartsQ[ExpandFileName[ProcessPath], ExpandFileName[LoopSWorkDirectory]], "ProcessPath is not inside script LoopSWorkDirectory."];
SetProcessDirectory[];

ampLO = Get[FileNameJoin[{inputDir, "ampLO"}]];
ampLO2 = TableS[ampLO[[i]] // SUNSimplify // FCES // FactorAll, {i, Length@ampLO}];
{ampLO3, colRulesLO} = AbbreviateFactor[ampLO2, ! FreeQ[#, CA | CF] &, "AbbreviateFactorName" -> colLO];
{ampLO4, gatherInfoLO} = GatherAmplitudes[ampLO3];
AssertTrue[TogetherExpand[Total[ampLO4] - Total[ampLO3]] === 0, "PionEMFF LO GatherAmplitudes consistency check failed."];

LOresult = TableS[AmplitudeReduce[ampLO4[[i]]], {i, Length@ampLO4}];
OperatorPattern = _Dot | _DiracTrace | _Spinor | _GAD | _GSD | _DiracGamma;
{LOresultA, OPRulesLO} = AbbreviateOperators[LOresult, "AbbreviateOperatorsName" -> OPs];
AssertTrue[LOresultA == Get[FileNameJoin[{referenceDir, "LOresultA"}]], "PionEMFF LOresultA reference comparison failed."];
AssertTrue[OPRulesLO == Get[FileNameJoin[{referenceDir, "OPRulesLO"}]], "PionEMFF OPRulesLO reference comparison failed."];

ampNLO = Get[FileNameJoin[{inputDir, "ampNLO"}]];
ampNLO2 = TableS[ampNLO[[i]] // SUNSimplify // FCES // FactorAll, {i, Length@ampNLO}];
{ampNLO3, colRulesNLO} = AbbreviateFactor[ampNLO2, ! FreeQ[#, CA | CF] &, "AbbreviateFactorName" -> colNLO];
{ampNLO4, gatherInfoNLO} = GatherAmplitudes[ampNLO3];
AssertTrue[TogetherExpand[Total[ampNLO4] - Total[ampNLO3]] === 0, "PionEMFF NLO GatherAmplitudes consistency check failed."];

symRules = GenerateSymmetryRules[{{{1, 2}}, {{3, 4}}, {{1, 3}, {2, 4}}}, {{x1, p}, {x2, p}, {y1, pp}, {y2, pp}}];
PrepareParallel[];
{familyLSNLO, familyNLO} = FamilyClassify[ampNLO4, {l1}, "Symmetry" -> symRules, Parallelization -> True];
AssertTrue[{familyLSNLO, familyNLO} == Get[FileNameJoin[{referenceDir, "familyNLOSym"}]], "PionEMFF NLO family reference comparison failed."];

FRepresNLO = ParallelTableS[
  AmplitudeReduce[ampNLO4[[i]], {l1}, familyLSNLO, "Symmetry" -> symRules],
  {i, Length@ampNLO4}
];
referenceFRepresNLO = Get[FileNameJoin[{referenceDir, "FRepresNLO"}]];
fRepresDiff = Collect[FRepresNLO - referenceFRepresNLO, _G, TogetherExpand];
AssertTrue[fRepresDiff === ConstantArray[0, Length@fRepresDiff], "PionEMFF FRepresNLO reference comparison failed."];

{FRepresNLOA, OPRulesNLO} = AbbreviateOperators[FRepresNLO, "AbbreviateOperatorsName" -> OPs];
OPRulesNLOM = CanonicalOperatorRules@{
  Spinor[Momentum[p, D], 0, -e2].GAD[\[Alpha]1].Spinor[Momentum[pp, D], 0, -e4] Spinor[Momentum[pp, D], 0, e3].GAD[\[Alpha]1].Spinor[Momentum[p, D], 0, e1] -> OPs[1],
  Spinor[Momentum[p, D], 0, -e2].GAD[\[Alpha]1].GAD[\[Alpha]2].GAD[\[Alpha]3].Spinor[Momentum[pp, D], 0, -e4] Spinor[Momentum[pp, D], 0, e3].GAD[\[Alpha]3].GAD[\[Alpha]2].GAD[\[Alpha]1].Spinor[Momentum[p, D], 0, e1] -> OPs[2]
};
FRepresNLOM = FRepresNLO /. Dispatch@OPRulesNLOM;
AssertTrue[FirstCase[FRepresNLOM, _G, Missing["NotFound"], {0, Infinity}] === G[2, {0, 1, 1}, 7], "PionEMFF NLO integral-tag example changed."];

FlistNLO = Cases[FRepresNLOM, _G, {0, Infinity}] /. G[a_, b_, c___] :> G[a, b] // Union;
AssertTrue[Length[FlistNLO] > 0, "PionEMFF NLO target integral list is empty."];

Print["Starting FIRE IBP reduction for NLO families..."];
PrepareParallel[];
ibpsNLO = TableS[
  FIREIBPReduction[FlistNLO, {familyNLO[[i]], i}, {l1}, "FIREUseMMA" -> True],
  {i, Length@familyNLO}
];
AssertTrue[VectorQ[ibpsNLO, MatchQ[#, {(_Rule | _RuleDelayed) ...}] &], "PionEMFF FIRE IBP reduction test failed."];

GrulesNLO = FamilyMerge[FlistNLO, familyNLO, ibpsNLO, {l1}];
MIsNLO = Union@Cases[FlistNLO /. Dispatch@GrulesNLO, _G, {0, Infinity}];
AssertTrue[Length[MIsNLO] === 8, "PionEMFF master integral count changed."];

Print["Matching master integrals to analytic solutions..."];
MIformlist = Get[FileNameJoin[{inputDir, "MIformlist"}]];
MIsollist = Get[FileNameJoin[{inputDir, "MIsollist"}]];
MIsNLOToSol = MatchMIs[MIsNLO, MIformlist, MIsollist, {l1}, familyNLO];

Print["Computing NLO results with MI substitution..."];
NLOresults = TableS[
  tp1 = FRepresNLOM[[i]] * (1/Nc);
  tp1 = tp1 /. {OPs[1] -> 1/4, OPs[2] -> (1 - \[Epsilon])^2, e -> I, as -> 1};
  tp1 = (tp1 /. colRulesNLO) /. {CA -> 3, CF -> 4/3, Nc -> 3};
  tp1 = tp1 /. G[a_, b_, c_] :> (
    Replace[G[a, b], GrulesNLO] /. symRules["Rules"][[c]] /. G[x_, y_] :> G[x, y, c]
  );
  tp1 = tp1 /. G[a_, b_, c_] :> (
    Replace[G[a, b], MIsNLOToSol] /. symRules["Rules"][[c]]
  );
  tp1 = (tp1 /. {D -> 4 - 2 \[Epsilon], d -> 4 - 2 \[Epsilon], x2 -> 1 - x1, y2 -> 1 - y1} /. {x1 -> x, y1 -> y})
    // CollectS[#, _Log | _PolyLog] &
    // Series[#, {\[Epsilon], 0, 0}] &
    // Normal;
  tp1 = tp1 // PowerExpand[#, Assumptions -> 0 < x < 1 && 0 < y < 1] &
    // Collect[#, {1/\[Epsilon], _Log, _PolyLog}, Factor] &,
  {i, 1, Length@FRepresNLOM}
];

Print["Checking Ward identity..."];
AssertTrue[TogetherExpand[Total[NLOresults] /. FVD[pp, \[Mu]] -> -FVD[p, \[Mu]]] === 0, "PionEMFF Ward identity check failed."];

Print["Comparing NLO result against reference T1Ref..."];
T1New = Total[NLOresults/(16 Pi^2) /. {FVD[p, \[Mu]] -> 1, FVD[pp, \[Mu]] -> 0}];
T1Ref = Get[FileNameJoin[{referenceDir, "T1Ref"}]];

T1RefFull = (T1Ref + 2 (T1Ref /. {x -> 1 - x, y -> 1 - y})) /. {CA -> 3, nf -> 3, CF -> 4/3, Nc -> 3};
tppole1 = Coefficient[T1RefFull, L] // MultivariateApart;
tppole2 = T1New // SeriesCoefficient[#, {\[Epsilon], 0, -1}] & // MultivariateApart;
AssertTrue[TogetherExpand[tppole1 - tppole2] === 0, "PionEMFF NLO 1/\[Epsilon] divergence check against T1Ref failed."];

tp1num = (T1RefFull /. L -> 1/\[Epsilon]) /. {x -> 1/3, y -> 1/4} // N[#, 50] & // Expand // Chop;
tp2num = (T1New /. {x -> 1/3, y -> 1/4}) // N[#, 50] & // Expand // Chop;
AssertTrue[Chop[Expand[tp1num - tp2num]] === 0, "PionEMFF NLO numerical finite-part check against T1Ref failed."];

Print["PionEMFF script example passed."];
Exit[0];
