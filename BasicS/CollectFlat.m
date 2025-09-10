ClearAll[CollectFlat];
CollectFlat[expr_, patt_, func1_ : (# &), func2_ : (# &)] := Module[{hd},
   Expand[Collect[expr, patt, hd]] /. hd[a_]*b_. :> func1[a] func2[b]]