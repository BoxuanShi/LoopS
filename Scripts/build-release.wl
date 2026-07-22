scriptPath = ExpandFileName@SelectFirst[
  Join[If[ListQ[$ScriptCommandLine], $ScriptCommandLine, {}], {$InputFileName}],
  StringQ[#] && FileExistsQ[#] &,
  $Failed
];
projectRoot = ParentDirectory[DirectoryName[scriptPath]];
outputDirectory = FileNameJoin[{projectRoot, "dist"}];

FailBuild[message_String] := (Print["Release build failed: ", message]; Exit[1]);
BuildFailure[message_String] := Throw[message, "ReleaseBuildFailure"];

pacletInfo = Quiet@Check[Get[FileNameJoin[{projectRoot, "PacletInfo.wl"}]], $Failed];
If[Head[pacletInfo] =!= PacletObject, FailBuild["PacletInfo.wl is not a valid PacletObject."]];

version = pacletInfo["Version"];
packageVersion = StringCases[
  Import[FileNameJoin[{projectRoot, "LoopS.m"}], "Text"],
  RegularExpression["\\$LoopSVersion\\s*=\\s*\"([^\"]+)\""] -> "$1"
];
If[packageVersion =!= {version},
  FailBuild["LoopS.m and PacletInfo.wl do not contain the same version."]
];

fireEntryPoint = FileNameJoin[{projectRoot, "LoadDependencies", "Dependencies", "fire", "FIRE7", "FIRE7.m"}];
If[! FileExistsQ[fireEntryPoint],
  FailBuild["The FIRE submodule is not initialized. Run: git submodule update --init --recursive"]
];
If[StringFreeQ[Import[fireEntryPoint, "Text"], "FIRE, version 7.1"],
  FailBuild["The release requires the tested FIRE 7.1 Mathematica entry point."]
];

releasePaths = {
  "BasicFunctions",
  "DifferentialEquations",
  "EquivalentIntegrals",
  "Extra",
  "FeynmanIntegralsClassification",
  "IBPReduction",
  "Interfaces",
  "LoadDependencies/LoadDependencies.m",
  "LoadDependencies/ParallelNeedS.m",
  "LoadDependencies/Dependencies/FeynCalc",
  "LoadDependencies/Dependencies/multivariateapart/MultivariateApart.wl",
  "LoadDependencies/Dependencies/opiter",
  "LoadDependencies/Dependencies/fire/FIRE7/FIRE7.m",
  "LoadDependencies/Dependencies/fire/FIRE7/README",
  "LoadDependencies/Dependencies/fire/FIRE7/mm/LeeRule.m",
  "LoadDependencies/Dependencies/fire/FIRE7/mm/Reconstruction.m",
  "ProcessDefine",
  "TensorReduction",
  "Examples/Inputs",
  "Examples/References/PionEMFF/FRepresNLO",
  "Examples/References/PionEMFF/LOresultA",
  "Examples/References/PionEMFF/OPRulesLO",
  "Examples/References/PionEMFF/T1Ref",
  "Examples/References/PionEMFF/familyNLO",
  "Examples/References/PionEMFF/familyNLOSym",
  "Examples/Notebook/examples.nb",
  "Examples/Scripts/load-smoke.wl",
  "Examples/Scripts/pion-emff.wl",
  "Examples/Scripts/run-all.wl",
  "Examples/Scripts/zhr.wl",
  "Tests/Smoke.wlt",
  "Tests/kira-integration.wl",
  "Tests/run-tests.wl",
  "CHANGELOG.md",
  "Config.m",
  "LICENSE",
  "LoopS.m",
  "LoopSCore.m",
  "LoopSNeat.m",
  "LoopSNeatCore.m",
  "PacletInfo.wl",
  "README.md",
  "THIRD_PARTY_NOTICES.md",
  "Usage.m"
};

excludedVersionControlDirectories = {
  "LoadDependencies/Dependencies/opiter/.git"
};

missingPaths = Select[releasePaths, ! FileExistsQ[FileNameJoin[{projectRoot, #}]] &];
If[missingPaths =!= {},
  FailBuild["Required release paths are missing: " <> StringRiffle[missingPaths, ", "]]
];

If[! FileExistsQ[FileNameJoin[{projectRoot, "LoadDependencies", "Dependencies", "opiter", "opiter", "opiter.frm"}]],
  FailBuild["The OPITeR submodule is not initialized. Run: git submodule update --init --recursive"]
];

If[! DirectoryQ[outputDirectory],
  CreateDirectory[outputDirectory, CreateIntermediateDirectories -> True]
];
stageParent = CreateDirectory[FileNameJoin[{$TemporaryDirectory, "LoopS-release-" <> CreateUUID[]}]];
stageRoot = FileNameJoin[{stageParent, "LoopS"}];
CreateDirectory[stageRoot];

MaterializeFileLinks[root_String] := Module[
  {findResult, links, targetResult, target, resolvedTarget, targetIsFile, unlinkResult},
  findResult = RunProcess[{"find", root, "-type", "l", "-print"}];
  If[findResult["ExitCode"] =!= 0,
    BuildFailure["Could not inspect dependency symbolic links: " <> findResult["StandardError"]]
  ];
  links = DeleteCases[StringSplit[findResult["StandardOutput"], "\n"], ""];
  Scan[
    Function[link,
      targetResult = RunProcess[{"readlink", link}];
      If[targetResult["ExitCode"] =!= 0,
        BuildFailure["Could not read symbolic link: " <> link]
      ];
      target = StringTrim[targetResult["StandardOutput"]];
      resolvedTarget = ExpandFileName[FileNameJoin[{DirectoryName[link], target}]];
      targetIsFile = FileExistsQ[resolvedTarget] && FileType[resolvedTarget] === File;
      unlinkResult = RunProcess[{"unlink", link}];
      If[unlinkResult["ExitCode"] =!= 0,
        BuildFailure["Could not remove symbolic link from staging: " <> link]
      ];
      If[targetIsFile,
        CopyFile[resolvedTarget, link]
      ];
    ],
    links
  ];
];

CopyReleasePath[relativePath_String] := Module[{source, target},
  source = FileNameJoin[{projectRoot, relativePath}];
  target = FileNameJoin[{stageRoot, relativePath}];
  If[! DirectoryQ[DirectoryName[target]],
    CreateDirectory[DirectoryName[target], CreateIntermediateDirectories -> True]
  ];
  If[DirectoryQ[source], CopyDirectory[source, target], CopyFile[source, target]]
];

buildResult = Catch[Check[
  Scan[CopyReleasePath, releasePaths];
  MaterializeFileLinks[FileNameJoin[{stageRoot, "LoadDependencies"}]];
  Scan[
    DeleteFile,
    Flatten@Map[
      FileNames[#, stageRoot, Infinity] &,
      {".DS_Store", "._*", ".gitignore", ".gitattributes", ".gitmodules"}
    ]
  ];
  Scan[
    DeleteFile,
    FileNames[
      "FeynCalcExternal_*.m",
      FileNameJoin[{stageRoot, "LoadDependencies", "Dependencies", "FeynCalc", "Shared"}]
    ]
  ];
  Scan[
    DeleteFile,
    Flatten@Map[
      FileNames[#, FileNameJoin[{stageRoot, "LoadDependencies", "Dependencies"}], Infinity] &,
      {"PacletInfo.m", "PacletInfo.wl"}
    ]
  ];
  Scan[
    Function[relativePath,
      path = FileNameJoin[{stageRoot, relativePath}];
      If[DirectoryQ[path], DeleteDirectory[path, DeleteContents -> True]]
    ],
    excludedVersionControlDirectories
  ];

  archivePath = FileNameJoin[{outputDirectory, "LoopS-" <> version <> ".paclet"}];
  checksumPath = archivePath <> ".sha256";
  manifestPath = FileNameJoin[{outputDirectory, "LoopS-" <> version <> ".manifest.txt"}];
  Scan[If[FileExistsQ[#], DeleteFile[#]] &, {archivePath, checksumPath, manifestPath}];

  createdArchive = CreatePacletArchive[stageRoot, outputDirectory];
  If[createdArchive === $Failed || ! FileExistsQ[createdArchive],
    BuildFailure["CreatePacletArchive did not create an archive."]
  ];
  If[ExpandFileName[createdArchive] =!= ExpandFileName[archivePath],
    BuildFailure["Unexpected archive name: " <> ToString[createdArchive]]
  ];

  checksum = IntegerString[FileHash[archivePath, "SHA256"], 16, 64];
  Export[checksumPath, checksum <> "  " <> FileNameTake[archivePath] <> "\n", "Text"];

  manifest = Sort@Map[
    FileNameDrop[#, FileNameDepth[stageRoot]] &,
    Select[FileNames["*", stageRoot, Infinity], FileType[#] === File &]
  ];
  Export[manifestPath, StringRiffle[manifest, "\n"] <> "\n", "Text"];

  {archivePath, checksumPath, manifestPath, Length[manifest], FileByteCount[archivePath]},
  BuildFailure["An unexpected error interrupted the build."]
], "ReleaseBuildFailure"];

Quiet@DeleteDirectory[stageParent, DeleteContents -> True];

If[StringQ[buildResult], FailBuild[buildResult]];

Print["Release archive: ", buildResult[[1]]];
Print["SHA-256 file:   ", buildResult[[2]]];
Print["Manifest:      ", buildResult[[3]]];
Print["Files:         ", buildResult[[4]]];
Print["Archive bytes: ", buildResult[[5]]];
Exit[0];
