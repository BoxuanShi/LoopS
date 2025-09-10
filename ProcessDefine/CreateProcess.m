ClearAll[CreateProcess]
CreateProcess::kinematics = "kinematics is absent and has been set as {}";
CreateProcess[expr__Association | expr__List | expr__Rule] := 
 Module[{tp1, keys, purePV},
  (*pretransform*)
  tp1 = Association @@ Union@Flatten@Normal[{expr}];
  keys = Keys[tp1];
  If[! SubsetQ[keys, {"ProcessName"}], Print["ProcessName is absent."]; 
   Abort[]];
  If[! SubsetQ[keys, {"loopmoms", "extmomsind"}], 
   Print["loopmoms or extmomsind is absent."]; Abort[]];
  purePV = ToExpression["purePV" <> tp1["ProcessName"]];
  (*complete keys*)
  tp1 = If[FreeQ[Keys[tp1], "kinematics"], 
    Message[CreateProcess::kinematics]; Append[tp1, "kinematics" -> {}], 
    tp1];
  tp1 = If[
            FreeQ[Keys[tp1], "extmoms"],
            
    Append[tp1, 
     "extmoms" -> 
      DeleteCases[
       Union@Flatten@{tp1["extmomsind"], tp1["extramoms"]}, _Missing]],
            
    Append[tp1, "extmoms" -> Union@Flatten@{tp1["extmoms"], tp1["extmomsind"]}]
            ];
  tp1 = Append[tp1, 
    "extramoms" -> Complement[tp1["extmoms"], tp1["extmomsind"]]];
  tp1 = If[FreeQ[Keys[tp1], "indices"], Append[tp1, "indices" -> {}], tp1];
  tp1 = If[FreeQ[Keys[tp1], "moms"], 
    Append[tp1, "moms" -> Join[tp1["loopmoms"], tp1["extmoms"]]], tp1];
  tp1 = If[FreeQ[Keys[tp1], "purePV"], Append[tp1, "purePV" -> purePV], tp1];
  purePV[0] = 1; purePV[{}] = 1;
  tp1 = If[FreeQ[Keys[tp1], "operatorRules"], 
    Append[tp1, "operatorRules" -> {}], tp1];
  (*Sort*)
  tp1 = Normal[tp1] // 
    SortBy[#, 
      Position[Reverse@{"ProcessName", "loopmoms", "extmomsind", 
          "kinematics", "extmoms", "moms", "extramoms", "indices", "purePV", 
          "operatorRules"}, #[[1]]] &] &;
  (*Return*)
  Association @@ Reverse@tp1
      ]