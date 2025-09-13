ClearAll[CountPropsInFamily];
CountPropsInFamily::props = 
  "Propagators is not in the family, $Failed is returned -> `1`";
CountPropsInFamily[props_List, family_List, loops_List, 
  process_String : "CurrentProcess"] := 
 CountPropsInFamily[props, family, loops, ToExpression@process]
CountPropsInFamily[props_List, family_List, loops_List, 
  process_Association] := 
 CountPropsInFamily[props, family, loops, process["kinematics"]]
CountPropsInFamily[props_List, family_List, loops_List, kinematics_] :=
  Module[{ct, liQ, sign},
  
  liQ = LinearPropsExistQ[props, loops];
  
  If[liQ,
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
  
  If[Total@ct =!= Length@props, 
   Message[CountPropsInFamily::props, {props, family}]; 
   Return[$Failed]];
  
  {ct, sign}
  ]
