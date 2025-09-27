ClearAll[PreparePV]
Options[PreparePV] := CreateOptions[{}, {TableS, GeneratePV}]
PreparePV[process_String, nL_Integer : 3, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{i, partition, tp1, processA}, 

  processA = ToExpression[process];
  
  partition = Table[IntegerPartitions[i, Length @ processA["loopmoms"]], {i, nL}] // Flatten[#, 1] &;
  PrependTo[partition, {}];
  partition = Complement[partition, Keys @ ToExpression[processA["purePV"]]];

  tp1 = TableS[
    GeneratePV[partition[[i]], processA["extmomsind"], Evaluate @ FilterOptions[{opt}, GeneratePV]]
    , {i, Length@partition}, Evaluate @ FilterOptions[{opt}, TableS]];

  Table[
    ToExpression[processA["purePV"] <> "[" <> ToStringInput[partition[[i]]] <> "]=" <> ToStringInput[tp1[[i]]]]
  , {i, Length@partition}];

  (*unsetshared*)
  (* "UnsetShared[" <> processA["purePV"] <> "]" // ToExpression; *)
  ToExpression[processA["purePV"], StandardForm, Function[x1, UnsetShared[x1], HoldAll]];
  Print[processA["purePV"] <> " is unshared for subkernels."];

  (*distribute*)
  (* "DistributeDefinitions[" <> processA["purePV"] <> "]" // ToExpression; *)
  DistributeAssociation[Evaluate[processA["purePV"]]];
  Print[processA["purePV"] <> " is distributed for subkernels."];

  ]

PreparePV[nL_Integer : 3, opt : OptionsPattern[]] /; OptRestrict[opt] := PreparePV[CurrentAlgebras[[1]], nL, Evaluate @ opt]
