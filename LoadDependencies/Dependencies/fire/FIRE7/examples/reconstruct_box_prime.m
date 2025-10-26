Get["FIRE7.m"];
For[d=100,d<=125,d++,
    RationalReconstructTables["tests/outputs/box_"<>ToString[d]<>"_0.tables", 4];
];
Clear[d];
ThieleReconstructTables["tests/outputs/box_d_0.tables",d->Range[100,125]];
Quiet[
diff = CompareTables["tests/outputs/box_d_0.tables","tests/outputs/box.tables"];
Put[diff, "temp/diff.out"];];
