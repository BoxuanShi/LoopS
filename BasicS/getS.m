ClearAll[getS];
getS[expr_] := Variables @ Cases[expr, _, {0, Infinity}]
getS[expr_, patt_, opt : OptionsPattern[]] := Cases[expr, patt, {0, Infinity}] // Union

ClearAll[getV]
getV[expr_] := Variables[expr]
getV[expr_, patt_] := Variables[expr] // Select[#, !FreeQ[#, patt] &] &
(*If[
  FreeQ[patt, Blank | BlankSequence | BlankNullSequence | Alternatives]
  ,
  Variables[expr] // Select[#, MemberQ[Flatten@{patt}, Head@#] &] &
  ,
  Variables[expr] // Select[#, !FreeQ[#, patt] &] &
  ]*)


ClearAll[getDo]
getDo[expr_, patt_, func_] := Module[{tp1, tp2, tp3},
  tp1 = getS[expr, patt];
  tp2 = func /@ tp1;
  expr /. Dispatch[Thread[tp1 -> tp2]]]