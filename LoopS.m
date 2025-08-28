(*statement*)
$LoopSVersion="2025-08-28";


$LoopSInstallPath=DirectoryName[$InputFileName];


(*load-dependences*)
Print["################## LoopS: Loading Dependences ##################"];
Get[FileNameJoin[{$LoopSInstallPath,"LoadDependeces","LoadDependeces.m"}]];
Print["################### LoopS: Dependences Loaded ##################"];


Print[Style["LoopS",FontFamily->"Arial",FontSize->14,FontColor->Black,Bold],
Style[" - A Mathematica package for Feynman amplitudes reduction. By Bo-Xuan Shi (shibx@mail.nankai.edu.cn). 
Version "<>$LoopSVersion<>".",FontFamily->"Arial",FontSize->14,FontColor->Black]
];
Print[
Style["See ",FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[Hyperlink["https://github.com/BoxuanShi/LoopS","https://github.com/BoxuanShi/LoopS"],FontFamily->"Arial",FontSize->14,FontColor->Black],
Style[" for more information.",FontFamily->"Arial",FontSize->14,FontColor->Black]
]


(*LoopS*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"LoopS"}]},
Get["LoopS.m"];
Get["CreateProcess.m"];
Get["ClearProcess.m"];
Get["SetupProcess.m"];
Get["SetProcessDirectory.m"];
Get["FileStructures.m"];
Get["PrepareParallel.m"];
Get["PreparePV.m"];
]


(*General*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"General"}]},
Get["DownValuesArguments.m"];
Get["ParallelLoad.m"];
Get["MMABugFix.m"];
Get["Mul.m"];
Get["FormDo.m"];
Get["DistributeToPolyND.m"];
Get["ListS.m"];
Get["getS.m"];
Get["TableS.m"];
Get["getImS.m"];
Get["sameSetQ.m"];
Get["AtomizeRules.m"];
Get["TableFormS.m"];
Get["CoefficientS.m"];
Get["CountS.m"];
Get["texRational.m"];
Get["SeriesS.m"];
Get["SeriesPower.m"];
Get["AbbreviateVariables.m"];
Get["AbbreviateDeno.m"];
Get["AbbreviatePolynomials.m"];
Get["Separate.m"];
Get["PolynomialCollect.m"];
Get["CollectS.m"];
Get["CollectFlat.m"];
Get["ParallelTableS.m"];
Get["groupByRationalRatios.m"];
Get["generateSymmetryRules.m"];
Get["ToStringHold.m"];
Get["BlockCondition.m"];
Get["CreateOptions.m"];
Get["NotebookDirectoryS.m"];
Get["OptRestrict.m"];
Get["TogetherExpand.m"];
Get["PathName.m"];
Get["DropZeroByNumerics.m"];
]


(*PVReduction*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"PVReduction"}]},
Get["GeneratePV.m"];
Get["GeneratePVOPITeR.m"];
Get["GeneratePVMMA.m"];
Get["PVRules.m"];
]


(*TensorReduction*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"TensorReduction"}]},
Get["FCContract.m"];
Get["FCES.m"];
Get["ToSFADBugFix.m"];
Get["PVReduction.m"];
Get["SeparateFAD.m"];
Get["ExpandDirac.m"];
Get["IndexFunctions.m"];
Get["OperatorCollect.m"];
Get["AbbreviateOperators.m"];
Get["NumeratorToSPD.m"];
Get["PermutationRulesFromSets.m"];
Get["CanonicalOperatorRules.m"];
]


(*FeynmanIntegralsClassification*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"FeynmanIntegralsClassification"}]},
Get["zeroSectorQ.m"];
Get["ApartFFS.m"];
Get["DenoTransform.m"];
Get["SPDToFAD.m"];
Get["GetFeynInt.m"];
Get["FamilyClassify.m"];
Get["FindfamilyG.m"];
Get["ReplaceSymmetryG.m"];
Get["FindnumRules.m"];
Get["ReduceSPDToG.m"];
Get["DenominatorToG.m"];
Get["AmplitudeReduce.m"];
]


(*EquivalentIntegrals*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"EquivalentIntegrals"}]},
Get["CanonicalLoops.m"];
Get["propsToLS.m"];
Get["LSsubsets.m"];
Get["SymanzikPolynomials.m"];
Get["SymanzikOrder.m"];
Get["SymanzikIndepentVars.m"];
Get["sameFIQ.m"];
Get["matchFI.m"];
Get["MatchMIs.m"];
Get["loopSymmetryNoPS.m"];
]


(*FIREInterface*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"FIREInterface"}]},
Get["FIRETemplate.m"];
Get["FIREEvaluate.m"];
Get["FIREPrepareStart.m"];
Get["FIREPrepareStartMMA.m"];
Get["FIRELoadStart.m"];
Get["FIRELoadTable.m"];
Get["FIREGetGRules.m"];
Get["FIREReductionMMA.m"];
Get["FIREPrepareCXX.m"];
Get["FIRERunCXX.m"];
Get["FIREReductionCXX.m"];
Get["tosectors.m"];
Get["PossibleIntForDEInSector.m"];
Get["FindCompleteGList.m"];
Get["GenerateEiknolFamilies.m"];
Get["FindRulesComplete.m"];
]


(*AMFlowInterface*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"AMFlowInterface"}]},
Get["AMFlowInterface.m"];
]


(*MasterIntegralResults*)
Block[{$Path=FileNameJoin[{$LoopSInstallPath,"MasterIntegralResults"}]},
Get["OneLoopExamples.m"];
]


(*self-consistence check*)
If[$OperatingSystem==="Windows",

    Print[Style["Warning: PV reduction with OPITeR is not supported on Windows in LoopS, which may result in slower performance. Please use Linux or macOS for optimal performance.", FontColor->Red]]
    ,

    If[GeneratePVOPITeR[{},{}]=== $Failed, 
    Print[Style["GeneratePVOPITeR test failed! Please verify that OPITeR and FORM are correctly installed.", FontColor->Red]]];
];