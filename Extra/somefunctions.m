ClearAll[refinecolors];
refinecolors[expr_, pow_] := Module[{tp1, tp2, tp3}, 
    tp1 = expr // TogetherExpand // ListS;
    tp2 = Total /@ Outer[Exponent[#1, #2] &, tp1, {CA, CF, nf}];
    tp3 = (pow - tp2)/2;
    tp3 = (CA  (CA - 2  CF))^tp3;
    tp1 . tp3 // Factor
]