ClearAll[BlockCondition]
BlockCondition[condi_, a_, b_] := Module[{tp1, block},
  block = If[condi, Block, (#2 &)];
  Off[General::wrsym];
  tp1 = block[a, b];
  On[General::wrsym];
  tp1
  ]
SetAttributes[BlockCondition, HoldAll]