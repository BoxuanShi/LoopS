ClearAll[CountPropsInFamily];
CountPropsInFamily::props = 
  "Propagators is not in the family, $Failed is returned -> `1`";
CountPropsInFamily[props_List, family_List, 
  process_String : "CurrentProcess", opt: OptionsPattern[]] /; OptRestrict[opt] := 
 CountPropsInFamily[props, family, ToExpression@process, Evaluate @ opt]

CountPropsInFamily[props_List, family_List, 
  process_Association, opt: OptionsPattern[]] /; OptRestrict[opt] := 
 CountPropsInFamily[props, family, process["kinematics"], Evaluate @ opt]

CountPropsInFamily[props_List, family_List, kinematics_, opt: OptionsPattern[]] /; OptRestrict[opt] :=
  Module[{ct, sign},

  ct = Count[props - # // Together // Expand // # /. kinematics &, 0] & /@ family;
  sign = 1;

  If[Total @ ct =!= Length @ props, 
  ct = {ct, Count[props + # // TogetherExpand // # /. kinematics &, 0] & /@ family};
  sign = (-1)^Total @ ct[[2]];
  ct = Total @ ct];
  
  If[Total @ ct =!= Length @ props, 
   Message[CountPropsInFamily::props, {props, family}]; 
   Return[$Failed]];
  
  {ct, sign}


  (* liQ = LinearPropsExistQ[props, loops];
  
  If[liQ || OptionValue["CountPropsInFamilySignPermutation"],
   ct = {Count[props - # // TogetherExpand // # /. kinematics &, 
        0] & /@ family, 
     Count[props + # // TogetherExpand // # /. kinematics &, 0] & /@ 
      family};
   sign = (-1)^Total@ct[[2]];
   ct = Total@ct
   ,
   ct = Count[props - # // Together // Expand // # /. kinematics &, 
       0] & /@ family;
   sign = 1
   ];
  
  If[Total@ct =!= Length @ props, 
   Message[CountPropsInFamily::props, {props, family}]; 
   Return[$Failed]];
  
  {ct, sign} *)
  ]
