ClearAll[CreateFeynAmpS];
CreateFeynAmpS[dig_, prefactor_ : 1] := Module[{tp1, tp2},
    tp1 = CreateFeynAmp[dig, PreFactor -> (I/(16*Pi^2))^LoopNumber];
    tp2 = (Head@tp1) /@ tp1;
    List @@ tp2
]


ClearAll[getEcharge];
Clear[getEcharge]
getEcharge::usage = 
  "getEcharge[ampArt_] return the electric charge in fermion lines, only support for one photon case. In the case of one photon interact with in quark states, Echarge[n] is returned, which represent the n-th fermion line when generate amplitudes. In the case of photon interact with quark loops, \"eU, eD or eS...\" is returned, which represents the charge of u, d or s... quark.";
getEcharge[ampArt_] := Module[{tp1, tp2, tp3, tp4, tp5, tp6},
    tp1 = Cases[ampArt, x_ /; ! FreeQ[x, FCGV["EL"]], \[Infinity]];
    tp2 = FirstPosition[tp1, FermionChain[___] | MatrixTrace[___], False, Infinity][[1]];
    tp3 = If[tp2 === False, Print["Not Found."]; Abort[], tp1[[tp2]]];
    tp4 = Which[
        Head@tp3 === FermionChain,
        tp3[[1, 1, 1]],
        Head@tp3 === MatrixTrace,
        tp5 = Union@Cases[tp3, FCGV[a_] /; a =!= "EL", Infinity];
        tp6 = If[Length@tp5 === 1, FCGVToSymbol@tp5[[1]], Print["more than one flavor of quark in the MatrixTrace."]; Abort[]]
    ] /. {FourMomentum[Outgoing,a_] :> Echarge[a], Times[-1, FourMomentum[Incoming, a_]] :> Echarge[a], MU -> eU, MD -> eD, MS -> eS, MC -> eC, MB -> eB, MT -> eT}
]


ClearAll[FCFAConvertS]
FCFAConvertS[ampArt_, inMom_, outMom_, loops_] := FCFAConvert[ampArt,
    ChangeDimension -> D, 
    Contract -> True, 
    IncomingMomenta -> inMom, 
    OutgoingMomenta -> outMom, 
    LoopMomenta -> loops, 
    LorentzIndexNames -> {}, 
    SUNFIndexNames -> {}, 
    FinalSubstitutions -> {FCGV[s_] :> ToExpression[s]}, 
    SUNIndexNames -> {}, 
    UndoChiralSplittings -> True, 
    DropSumOver -> True, 
    SMP -> True] // SMPToSymbol // #[[1]] /. gs -> as^(1/2)*4*Pi &



Off[SetOptions::optnf];

ClearAll[findPaint, findPaint2]
SetOptions[Paint, SheetHeader -> False, AutoEdit -> False];
findPaint[insertedTop_, pos_Integer, shapeQ_ : True] := 
 Module[{num, tp1, tp2, tp3, tp4, tpPos},
  For[num = 0; tp2 = 0, tp2 < pos, num++,
   tp1 = insertedTop[[num + 1]] // ToString // StringCases[#, "Particles == " ~~ _] & // Length;
   tp2 = tp2 + tp1];
  tp3 = tp1 - (tp2 - pos);
  If[shapeQ, Monitor[insertedTop[[num]] // Shape, "Shape is performed in an individual window..."]];
  Head[insertedTop][insertedTop[[num]]] // Paint[#, 
     DisplayFunction -> (Put[Render[##1], "tpFAPrintName"] &)] &;
  tp4 = Flatten@List@(<< "tpFAPrintName")[[Ceiling[tp3/9], 1]];
  tpPos = Mod[tp3, 9];
  tp4[[If[tpPos === 0, 9, tpPos], 1]]]
findPaint[insertedTop_, pos_List, shapeQ_ : True] := 
  Module[{i}, 
   TableS[findPaint[insertedTop, pos[[i]], shapeQ], {i, Length@pos}, 
    "findPaint"]];
Options[findPaint2] := CreateOptions[{}, {Graph}];
findPaint2[insertedTop_, pos_Integer, opt : OptionsPattern[]] := 
 Module[{tp1, tp2},
  tp1 = findPaint[insertedTop, pos, False];
  tp2 = PaintS[tp1, opt];
  Insert[tp2, pos, 1]
  ]
findPaint2[insertedTop_, pos_List, opt : OptionsPattern[]] := 
 Module[{i}, 
  TableS[findPaint2[insertedTop, pos[[i]], opt], {i, Length@pos}, 
   "findPaint2"]]


ClearAll[ArcToLine]
ArcToLine[circle_Circle, n_ : 1] := 
 Module[{center, radius, angleRange, angles, points},
  {center, radius, angleRange} = List @@ circle;
  angles = Subdivide[angleRange[[1]], angleRange[[2]], n];
  points = (center + # &) /@ (radius*
      Transpose@{Cos[angles], Sin[angles]});
  Line[points]]
ArcToLine[expr_] := 
 expr /. Circle[circle___] :> ArcToLine[Circle[circle]]



ClearAll[PaintS]
Options[PaintS] := CreateOptions[{}, {Graph}];
PaintS[graph_Graphics, opt : OptionsPattern[]] := 
 Module[{tprule, coords, tpm1, tp0, tp1, tp2, tp2o2, tp3, tp4, tp5, 
   tp6, tp7},
  tp0 = graph /. Tooltip[a_, b___] :> a;
  tp1 = tp0 /. 
    Graphics[b_, c___] :> 
     DeleteCases[Flatten@b, 
      a_ /; (Head[a] =!= Line && 
         Head[a] =!= Circle)](*drop all information except, 
  fermion lines and the other lines*);
  tp2 = Select[tp1, Head@# =!= Circle &] // 
    Rationalize[#, 10^-5] &(*Rationalize number*);
  tp2o2 = 
   Select[tp1, Head@# === Circle &] // ArcToLine // 
    Rationalize[#, 10^-5] &(*Rationalize number*);
  tp3 = tp2 // GatherBy[#, (Length @@ #) === 2 &] & // 
    SortBy[#, 
      Length@#[[1, 1]] &] &(*gather by whether fermion lines*);
  tp4 = {UndirectedEdge @@@ 
     Flatten[List @@@ tp3[[1]], 1](*fermion lines*),
    UndirectedEdge @@@ Flatten[List @@@ tp2o2, 1](*fermion loops*),
    UndirectedEdge @@@ 
     Flatten[List @@@ (tp3[[2]] /. 
         Line[a_] :> Line[{a[[1]], a[[-1]]}]), 1](*the others*)};
  tprule = 
   Thread[UnionS@Flatten[List @@@ (Flatten@tp4), 1] -> 
     Range@Length@
       Union@Flatten[List @@@ (Flatten@tp4), 
         1]];(*map positions to vertex indices*)
  tp5 = tp4 /. tprule(*vertex form*);
  tp6 = tp5[[1]] // 
    Graph[List @@ #, 
      GraphLayout -> "SpringElectricalEmbedding"] &(*graphs*);
  tp7 = List @@@ tp5[[1]] // Flatten // 
    DeleteDuplicates;(*fermion line vertices*)
  coords = GraphEmbedding[tp6];
  {graph, 
   Graph[Flatten@{tp5[[1]], tp5[[2]], 
      Style[#, Darker@Blue, Thickness[0.008]] & /@ tp5[[3]]}, opt, 
    VertexCoordinates -> Thread[tp7 -> coords], 
    EdgeShapeFunction -> {a_ /; MemberQ[tp5[[3]], a] -> 
       springEdge(*({Thick,Darker@Blue,Line[#]}&)*)}, 
    VertexStyle -> Red]}
  ]
  
PaintS[graph_List, opt : OptionsPattern[]] := 
 Module[{i}, 
  TableS[PaintS[graph[[i]], opt], {i, Length@graph}, "PaintS"]]
springEdge[pts_List, _] := 
 Module[{input1, input2, p1, p2, dir, norm, L, turns = 2, amp = 0.05, 
   spiralPts, t},
  If[Length@pts > 2,
   input1 = {pts[[1]], pts[[Floor[Length@pts/2]]]};
   input2 = {pts[[Floor[Length@pts/2]]], pts[[-1]]};
   Return[{Thick, Darker@Blue, 
     Line@Join[(springEdge[input1, _][[3, 1]]), 
       List @@ (springEdge[input2, _][[3, 1]])]}]
   ];(*for Line with arguments more than 2, 
  plot a simplest curve constituted by two lines*)
  {p1, p2} = {pts[[1]], pts[[-1]]};
  L = Norm[p2 - p1];
  dir = Normalize[p2 - p1];
  norm = RotationTransform[\[Pi]/2][dir];
  spiralPts = 
   Table[p1 + dir*L*t + amp*Sin[2 \[Pi] turns t]*norm, {t, 0, 1, 
     0.01}];
  {Thick, Darker@Blue, Line[spiralPts]}]

On[SetOptions::optnf];