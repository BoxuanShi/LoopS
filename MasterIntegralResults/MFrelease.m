MFrelease;

ClearAll[MFrelease]
MFrelease[expr_, MIsollist_] := expr /. MF[a_, b_] :> (MIsollist[[a]] /. b)