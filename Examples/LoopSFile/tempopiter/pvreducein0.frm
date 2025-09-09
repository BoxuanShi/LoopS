
#: IncDir /Users/balth/Downloads/LoopS-Mine/packages/LoopS/LoadDependeces/Dependences/opiter/opiter
#include- opiter.frm
Autodeclare Vector q;
Off statistics;
L F2=ext()*loop()*1;
#call opiter
.sort
#call symmetrise
.sort
#call leavedualtransverse
.sort
B loop,ext,Gsigma,d_,ddts,dual,sym,deno;
#write </Users/balth/Downloads/LoopS-Mine/packages/LoopS/Examples/LoopSFile/tempopiter/pvreduceout0.m> "%e",F2;
.end
