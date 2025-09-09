
#: IncDir /Users/balth/Downloads/LoopS-Mine/packages/LoopS/LoadDependeces/Dependences/opiter/opiter
#include- opiter.frm
Autodeclare Vector q;
Off statistics;
L F2=ext(q1,q2)*loop(p1)*p1(mu1)*p1(mu2)*p1(mu3);
#call opiter
.sort
#call symmetrise
.sort
#call leavedualtransverse
.sort
B loop,ext,Gsigma,d_,ddts,dual,sym,deno;
#write </Users/balth/Downloads/LoopS-Mine/packages/LoopS/Examples/LoopSFile/tempopiter/pvreduceout13.m> "%e",F2;
.end
