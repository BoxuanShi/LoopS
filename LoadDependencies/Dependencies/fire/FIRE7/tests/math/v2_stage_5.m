lb = Get["tests/math/temp/v3.lbases"];
lbo = Get["tests/math/etalon/v2.lbases"];
res = Union[(##[[1]] - ##[[2]]) & /@ Map[ToExpression, (List @@@ DeleteCases[Union[Flatten[lb - lbo]], 0]) /. -1 -> 1, {2}]];
Put[res, "tests/math/temp/diff.m"];
