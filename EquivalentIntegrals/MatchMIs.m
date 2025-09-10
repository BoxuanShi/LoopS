ClearAll[MatchMIs];
Options[MatchMIs] := 
  CreateOptions[{"SimplifyMatchMIs" :> (CollectFlat[#, {\[Epsilon]| ToExpression["_G"] | _Log \
| _PolyLog | ToExpression["_HPL"]}, SimplifyS, Simplify] &)}, {matchFI, TableS}];
MatchMIs[MIs_List, MIformlist_List, MIsollist_List, loops_List, family_List, 
  process_String : "CurrentProcess", opt : OptionsPattern[]] := 
 MatchMIs[MIs, MIformlist, MIsollist, loops, family, 
  ToExpression["CurrentProcess"]["kinematics"], opt]
MatchMIs[MIs_List, MIformlist_List, MIsollist_List, loops_List, family_List, 
   kinematics_List, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{i, props, MFs, Msols, opt1, opttable},
  props = GToProps[MIs, family, List];
  
  opt1 = FilterOptions[{opt}, matchFI];
  
  opttable = FilterOptions[{opt}, TableS];
  MFs = TableS[
    matchFI[props[[i]], MIformlist, loops, kinematics, Evaluate@opt1], {i, 
     Length@props}, "MatchFI...", Evaluate@opttable];
  
  If[MIsollist === {}, Return[Thread[MIs -> MFs]]];

  Msols = MFrelease[MFs, MIsollist];
  Msols = 
   TableS[Msols[[i]] // OptionValue["SimplifyMatchMIs"], {i, Length@Msols}, 
    "Simplifying MIs result by option \"SimplifyMatchMIs\".", 
    Evaluate@opttable];
  
  Thread[MIs -> Msols]
  ]