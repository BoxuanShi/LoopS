scriptPath = ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
];
testsDirectory = DirectoryName[scriptPath];
projectRoot = ParentDirectory[testsDirectory];

Get[FileNameJoin[{projectRoot, "LoopS.m"}]];

FailKiraTest[message_] := (Print["Kira integration test failed: ", message]; Exit[1]);
AssertKiraTest[condition_, message_] := If[! TrueQ[condition], FailKiraTest[message]];

kiraExecutable = Environment["LOOPS_KIRA_EXECUTABLE"];
If[! StringQ[kiraExecutable] || StringTrim[kiraExecutable] === "",
  kiraExecutable = $KiraExecutable
];

testRoot = FileNameJoin[{testsDirectory, "LoopSFile", "KiraIntegration"}];
If[! DirectoryQ[testRoot], CreateDirectory[testRoot, CreateIntermediateDirectories -> True]];
versionResult = Quiet@Check[
  RunProcess[{kiraExecutable, "--version"}, ProcessDirectory -> testRoot],
  $Failed
];
AssertKiraTest[versionResult =!= $Failed, "could not start " <> ToString[kiraExecutable]];
AssertKiraTest[versionResult["ExitCode"] === 0, "Kira version command returned a nonzero exit code"];
kiraVersion = StringTrim[versionResult["StandardOutput"] <> versionResult["StandardError"]];
AssertKiraTest[StringContainsQ[kiraVersion, "Kira version"], "unexpected version output: " <> kiraVersion];

fireRoot = FileNameJoin[{testRoot, "FIRE"}];
kiraRoot = FileNameJoin[{testRoot, "Kira"}];
familyName = "bubble";

family = {l^2, (l + p)^2};
kinematics = {p^2 -> s};
targets = {G[1, {1, 1}], G[1, {2, 1}], G[1, {1, 2}], G[1, {2, 2}]};

Print["Running FIRE reference reduction for the one-loop bubble..."];
fireRules = FIREIBPReduction[
  targets, {family, 1}, {l}, {p}, kinematics,
  {fireRoot, familyName}, "FIREUseMMA" -> True
];
AssertKiraTest[MatchQ[fireRules, {(_Rule | _RuleDelayed) ...}], "FIRE did not return rules"];
fireRunDirectory = FIRERunDirectory[fireRoot, familyName, 1];
AssertKiraTest[
  And @@ (FileExistsQ /@ {
    FileNameJoin[{fireRunDirectory, familyName <> "1.start"}],
    FileNameJoin[{fireRunDirectory, familyName <> "1.m"}],
    FileNameJoin[{fireRunDirectory, familyName <> "1.config"}],
    FileNameJoin[{fireRunDirectory, familyName <> "1save.m"}],
    FileNameJoin[{fireRunDirectory, "temp", familyName <> "1save.wl"}]
  }),
  "FIRE family files were not isolated in " <> fireRunDirectory
];

Print["Running Kira with integral_ordering=2 and one worker..."];
kiraRules = KiraIBPReduction[
  targets, {family, 1}, {l}, {p}, kinematics,
  {kiraRoot, familyName},
  "KiraExecutable" -> kiraExecutable,
  "KiraParallel" -> 1,
  "KiraKinematicDimensions" -> {s -> 2}
];
AssertKiraTest[MatchQ[kiraRules, {(_Rule | _RuleDelayed) ...}], "Kira did not return rules"];

fireReduced = targets /. Dispatch[fireRules];
kiraReduced = targets /. Dispatch[kiraRules];
fireMasters = Union@Cases[fireReduced, _G, Infinity];
kiraMasters = Union@Cases[kiraReduced, _G, Infinity];

AssertKiraTest[fireMasters === kiraMasters,
  "FIRE and Kira selected different master bases: " <>
    ToString[{fireMasters, kiraMasters}, InputForm]];
AssertKiraTest[
  And @@ Flatten[(Map[# >= 0 &, #[[2]]] &) /@ kiraMasters],
  "Kira's default master basis contains a negative propagator power"
];
AssertKiraTest[
  And @@ (TogetherExpand[#] === 0 & /@ (fireReduced - kiraReduced)),
  "FIRE and Kira reductions are not symbolically equivalent"
];

mastersFile = FileNameJoin[{
  KiraRunDirectory[kiraRoot, familyName, 1], "results", familyName <> "1", "masters.final"
}];
AssertKiraTest[FileExistsQ[mastersFile], "Kira masters.final file is missing"];
masterLines = Select[
  StringTrim[First[StringSplit[#, "#"]]] & /@ Import[mastersFile, "Lines"],
  # =!= "" &
];

Print["Kira executable: ", kiraExecutable];
Print["Kira version: ", kiraVersion];
Print["FIRE working directory: ", fireRunDirectory];
Print["Kira working directory: ", KiraRunDirectory[kiraRoot, familyName, 1]];
Print["Kira command: ", kiraExecutable, " job.yaml --parallel=1"];
Print["Kira masters reported: ", Length[masterLines], "; LoopS target masters: ", Length[kiraMasters]];
Print["FIRE/Kira master basis: ", InputForm[kiraMasters]];
Print["Kira interface integration test passed."];
Exit[0];
