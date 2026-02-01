ClearAll[DistributeAssociation, DistributeString]
SetAttributes[DistributeAssociation, {Listable, HoldFirst}]
DistributeAssociation[symbol_Symbol]:= (
    ParallelEvaluate[symbol = symbol, DistributedContexts -> All]
  )
DistributeAssociation[symbol_String]:= (
    DistributeString[symbol];
    ParallelEvaluate[ToExpression[symbol, StandardForm, Function[x1, x1 = x1, HoldAll]], DistributedContexts -> None];
  )
DistributeAssociation[symbol___] := DistributeAssociation[{symbol}]


SetAttributes[DistributeString, {Listable}];
DistributeString[str_String]:= (
    ToExpression[str, StandardForm, Function[x1, DistributeDefinitions[x1], HoldAll]];
)