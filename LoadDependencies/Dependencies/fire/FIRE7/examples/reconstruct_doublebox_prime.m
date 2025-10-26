Get["FIRE7.m"];
s = 57;
t = 3;
For[d=100,d<=112,d++,
    For[s=57,s<=62,s++,
        RationalReconstructTables["tests/outputs/doublebox_"<>ToString[d]<>"_"<>ToString[s]<>"_"<>ToString[t]<>"_0.tables", 3];
    ];
];
Clear[s];
For[d=100,d<=112,d++,
    ThieleReconstructTables["tests/outputs/doublebox_"<>ToString[d]<>"_s_"<>ToString[t]<>"_0.tables",s->Range[57,62]];
];
Clear[d];
s = 57;
ThieleReconstructTables["tests/outputs/doublebox_d_"<>ToString[s]<>"_"<>ToString[t]<>"_0.tables",d->Range[100,112]];
Clear[s];

Print["Testing balanced Newton reconstruction"];
BalancedNewtonReconstructTables["tests/outputs/doublebox_d_s_"<>ToString[t]<>"_0.tables", d->Range[100,112], s->57];

(*
diff = CompareTables["tests/outputs/doublebox_d_s_3_0.tables","tests/outputs/doublebox.tables"];
Put[diff, "temp/diff.out"];
Print[diff];
*)

dfactor = DenominatorFactor["tests/outputs/doublebox_d_57_3_0.tables"];
Print[InputForm[dfactor]];
sfactor = DenominatorFactor["tests/outputs/doublebox_100_s_3_0.tables", XVar->s];
Print[InputForm[sfactor]];
gfactor = DenominatorFactor["tests/outputs/doublebox_d_s_3_0.tables", XVar->s];
Print[InputForm[gfactor]];



Print["Testing Newton reconstruction after multiplication by a factor"];
s = 57;
NewtonReconstructTables["tests/outputs/doublebox_d_"<>ToString[s]<>"_"<>ToString[t]<>"_0.tables",d->Range[100,112], Factor->dfactor];
Clear[s];
d = 100;
NewtonReconstructTables["tests/outputs/doublebox_"<>ToString[d]<>"_s_"<>ToString[t]<>"_0.tables",s->Range[57,62], Factor->sfactor];
Clear[d];


Print["Testing Newton-Newton reconstruction after multiplication by a factor"];
NewtonNewtonReconstructTables["tests/outputs/doublebox_d_s_"<>ToString[t]<>"_0.tables", d->Range[100,112], s->Range[57,62], Factor->dfactor*sfactor];
diff = CompareTables["tests/outputs/doublebox_d_s_"<>ToString[t]<>"_0.tables","tests/outputs/doublebox.tables"];
Put[diff, "temp/diff.out"];
Print[diff];

Print["Testing Newton-Thiele reconstruction after multiplication by a factor"];
NewtonThieleReconstructTables["tests/outputs/doublebox_d_s_"<>ToString[t]<>"_0.tables", d->Range[100,112], s->Range[57,62], Factor->sfactor];
diff = CompareTables["tests/outputs/doublebox_d_s_"<>ToString[t]<>"_0.tables","tests/outputs/doublebox.tables"];
Put[diff, "temp/diff.out"];
Print[diff];

