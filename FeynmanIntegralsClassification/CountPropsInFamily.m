ClearAll[CountPropsInFamily];
CountPropsInFamily::props = "Propagators is not in the family, $Failed is returned -> `1`";
CountPropsInFamily[props_List, family_List, process_String : "CurrentProcess", opt: OptionsPattern[]] /; OptRestrict[opt] := CountPropsInFamily[props, family, ToExpression@process, Evaluate @ opt]
CountPropsInFamily[props_List, family_List, process_Association, opt: OptionsPattern[]] /; OptRestrict[opt] := CountPropsInFamily[props, family, process["kinematics"], process["loopmoms"], Evaluate @ opt]
CountPropsInFamily[props_List, family_List, kinematics_, loopmoms_List, opt: OptionsPattern[]] /; OptRestrict[opt] := Module[{ct, sign, aux},

  ct = Count[props - # // TogetherExpand // # /. kinematics &, 0] & /@ family;
  sign = 1;

  aux = {-1, 2, 1/2, -2, -1/2};
  aux = Join[aux, Coefficient[#, loopmoms^2]& /@ props // Flatten] // DeleteDuplicates // DeleteCases[#, 0|1]&;

  Do[
  If[Total @ ct =!= Length @ props, 
    ct = {ct, Count[props - aux[[i]] * # // TogetherExpand // # /. kinematics &, 0] & /@ family};
    sign = sign * (1 / aux[[i]]) ^ Total @ ct[[2]];
    ct = Total @ ct,
    Break[]
    ];
  , {i, Length @ aux}];
  
  If[Total @ ct =!= Length @ props, 
   Message[CountPropsInFamily::props, {props, family}]; 
   Return[$Failed]];
  
  {ct, sign}

  ]
