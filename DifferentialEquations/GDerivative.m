ClearAll[GDerivative, GDerivativeG, GDerivative0];
GDerivative[expr_, var_, family_, process_Association : CurrentProcess] := GDerivative[expr, var, family, process["loopmoms"], process["kinematics"], process["moms"]]
GDerivative[expr_, var_, family_, loopmoms_, kinematics_, moms_] := GDerivative0[expr, "var" -> var, "family" -> family,"loopmoms" -> loopmoms, "kinematics" -> kinematics, "moms" -> moms]
SetAttributes[GDerivative0, Listable];
Options[GDerivative0] = {"var" -> "var", "family" -> "family", "loopmoms" -> "loopmoms", "kinematics" -> "kinematics", "moms" -> "moms"};
GDerivative0[expr_, opt : OptionsPattern[]] /; OptRestrict[opt] := 
 Module[{coe, Glist, coeD, GlistD, var, family, loopmoms, kinematics, moms}, 
  {var, family, loopmoms, kinematics, moms} = {OptionValue["var"], OptionValue["family"], OptionValue["loopmoms"], OptionValue["kinematics"], OptionValue["moms"]};
  {coe, Glist} = Separate[expr, _G];
  coeD = D[ExpandDirac @ ExpandMomentum[coe, moms], var];
  GlistD = GDerivativeG[#, var, family, loopmoms, kinematics, moms] & /@ Glist;
  coeD . Glist + coe . GlistD // ReduceSPDToG[#, family, loopmoms, kinematics, moms] & // CollectS[#, _G, Factor] &
  ]
GDerivativeG[expr_G, var_, family_, loopmoms_, kinematics_, moms_] := 
 Module[{familyN, exprSPD, exprD, exprA, rules, coe, deno, Abbr}, 
  {familyN, exprSPD} = {expr[[1]], GToProps[expr, family] // PropsToSPD[#, SPD, moms] & // Times @@ #^-1 &};
  exprD = D[exprSPD, var];
  {exprA, rules} = AbbreviateDeno[exprD, "AbbreviateDenoName" -> Abbr];
  rules = Thread[rules[[All, 1]] -> (rules[[All, 2]] /. SPD -> Times // #^-1 &)];
  {coe, deno} = Separate[exprA, _Abbr, "SeparateOperation" -> List];
  deno = deno /. Dispatch@rules;
  deno = CountPropsInFamily[#, family[[familyN]], kinematics] & /@ deno;
  deno = deno[[All, 2]]*(G[familyN, #] & /@ deno[[All, 1]]);
  coe . deno 
  ]