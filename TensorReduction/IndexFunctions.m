ClearAll[getfullindices, getdummyindices, getdummyindicesList]
getfullindices[amp_, patt_ : _GAD | _GSD | _GA | _GS | _FV | _FVD] := 
 Variables@(List @@@ Union[Cases[FCES@{amp}, patt, Infinity]])

(*DotExpand is to avoid bugs in some computer in the case of self-defined EOM \
exist.*)
getdummyindices[amp_, head_ : LorentzIndex] := 
 FCGetDummyIndices[DotExpand@FCI@amp, Flatten@{head}]

(*get dummy index for every spinor..., input should be one operator*)
getdummyindicesList[expr_] := Module[{tp1, tp2, tp3},
  tp1 = getdummyindices@expr;
  tp2 = getV[expr, DiracPattern] // SortBy[#, getS[#, _Spinor] &] &;
  tp3 = (Intersection[tp1, #] &) /@ getfullindices /@ tp2]


(*input should be one operator*)
RenameDummyInd[expr_] := Module[{tp1, tp2, tp3, tp4, i},
  tp1 = getdummyindicesList[expr];
  tp2 = tp1 // Flatten // DeleteDuplicates;
  tp2 = tp2 // SortBy[#, Position[tp1, #][[All, 1]] &] &;
  expr /. Dispatch@Thread[tp2 -> Array[LorInd, Length@tp2]]]
SetAttributes[RenameDummyInd, Listable]


ClearAll[indicesOrder, indicesOrder0]
indicesOrder[expr_, process_String : "CurrentProcess"] := 
 indicesOrder[expr, ToExpression[process]]
indicesOrder[expr_, process_Association] := 
 indicesOrder[expr, process["indices"], process["operatorRules"]]
indicesOrder[expr_, indices_List, 
  operatorRules_List | operatorRules_Dispatch] := 
 indicesOrder0[expr, "indices" -> indices, "operatorRules" -> operatorRules]
SetAttributes[indicesOrder0, Listable]
Options[indicesOrder0] = {"indices" -> "indices", 
   "operatorRules" -> "operatorRules"};
indicesOrder0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{tp1, tp2, tp3, dot, rules, indices, operatorRules},
  {indices, operatorRules} = {OptionValue["indices"], 
    OptionValue["operatorRules"]};
  tp1 = expr // getS[#, _Dot(*DiracPattern*)] &;
  tp2 = DiracOrder[#, indices] & /@ tp1 // FCES;
  
  rules = Thread[tp1 -> tp2];
  tp3 = expr /. x:_Dot :> Replace[x, rules];

  tp3 = tp3 // CollectS[#, DiracPattern | _MTD | _FVD, # &, DiracSimplify] &(*//
    FCES*)// DiracTraceExpand(*//TimingS*);
  tp3 // CollectS[#, OperatorPattern, # &, Replace[RenameDummyInd[#], operatorRules] &] &
  ]