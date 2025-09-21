ClearAll[PreparePV]
Options[PreparePV] := CreateOptions[{}, {TableS, GeneratePV}]
PreparePV[process_String, nL_Integer : 3, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{i, partition, tp1, tp2, processA}, 
  processA = ToExpression[process];
  partition = 
   Table[IntegerPartitions[i, Length@processA["loopmoms"]], {i, nL}] //
     Flatten[#, 1] &;
  PrependTo[partition, {}];
  partition = 
   Complement[partition, Keys@ToExpression[processA["purePV"]]];
  tp1 = TableS[
    GeneratePV[partition[[i]], processA["extmomsind"], 
     Evaluate@FilterOptions[{opt}, GeneratePV]], {i, 
     Length@partition}, Evaluate@FilterOptions[{opt}, TableS]];
  Table[ToExpression[
    processA["purePV"] <> "[" <> ToStringInput[partition[[i]]] <> 
     "]=" <> ToStringInput[tp1[[i]]]], {i, Length@partition}];]

PreparePV[nL_Integer : 3, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := PreparePV[CurrentAlgebras[[1]], nL, Evaluate@opt]
