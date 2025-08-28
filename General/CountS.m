CountS;

ClearAll[CountS];
CountS[list_List, patt_, level_ : {1}, 
  testfunc_ : (Union@Flatten@{Together[#1 - #2]} === {0} &)] := If[
  StringFreeQ[ToString[patt], {"_", "|"}],
  Count[testfunc[#, patt] & /@ list, True, level],
  Count[list, patt, level]]