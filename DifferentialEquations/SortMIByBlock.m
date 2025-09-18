ClearAll[SortMIByBlock]
SortMIByBlock[MIs_List] := SortBy[MIs, {propNumG, tosector, #[[1]] &}]