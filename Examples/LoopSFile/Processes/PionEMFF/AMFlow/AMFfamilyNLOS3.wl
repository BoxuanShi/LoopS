
Get["AMFlow`"];
SetReductionOptions["IBPReducer"->"FIRE+LiteRed"];
AMFlowInfo["Family"]=AMFfamilyNLOS3;
AMFlowInfo["Loop"]={l1};
AMFlowInfo["Leg"]={p, pp};
AMFlowInfo["Conservation"]={};
AMFlowInfo["Replacement"]={p^2 -> 0, pp^2 -> 0, p*pp -> 1/2};
AMFlowInfo["Propagator"]={l1^2, (l1 + p/3)^2, (l1 + (27*pp)/182)^2};
AMFlowInfo["Numeric"]={x1 -> 1/3, x2 -> 1/4, y1 -> 1/13, y2 -> 1/14};
AMFlowInfo["NThread"]=4;
target={j[AMFfamilyNLOS3, 0, 1, 1]};
goal=20;
epsorder=4;
res=SolveIntegrals[target,goal,epsorder];
res>>"/Users/balth/Downloads/LoopS-Mine/packages/LoopS/Examples/LoopSFile/Processes/PionEMFF/AMFlow/AMFfamilyNLOS3";
