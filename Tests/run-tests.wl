scriptPath = ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
];
testsDirectory = DirectoryName[scriptPath];
projectRoot = ParentDirectory[testsDirectory];

Get[FileNameJoin[{projectRoot, "LoopS.m"}]];

report = TestReport[FileNameJoin[{testsDirectory, "Smoke.wlt"}]];
results = report["Results"];
outcomes = (#1["Outcome"] &) /@ results;
failedTests = Select[results, #1["Outcome"] =!= "Success" &];

Print[
  "LoopS fast tests: ", Count[outcomes, "Success"], " passed, ",
  Length[failedTests], " failed."
];

Scan[
  Function[test,
    Print["FAILED: ", test["TestID"], " (", test["Outcome"], ")"];
    Print["  Expected: ", ToString[test["ExpectedOutput"], InputForm]];
    Print["  Actual:   ", ToString[test["ActualOutput"], InputForm]];
    If[test["ActualMessages"] =!= {},
      Print["  Messages: ", ToString[test["ActualMessages"], InputForm]]
    ]
  ],
  failedTests
];

Exit[If[TrueQ[report["ReportSucceeded"]], 0, 1]];
