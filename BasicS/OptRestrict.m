OptRestrict;

ClearAll[OptRestrict]
OptRestrict[opt___] := opt =!= {} || Length@Flatten@{opt} =!= 0