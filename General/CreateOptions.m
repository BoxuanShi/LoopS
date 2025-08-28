CreateOptions;

ClearAll[CreateOptions]
CreateOptions[options_List, names_] := 
 DeleteDuplicates[Flatten@{options, Options /@ names}, #1[[1]] === #2[[1]] &]