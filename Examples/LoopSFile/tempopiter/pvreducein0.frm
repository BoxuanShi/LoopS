
#: IncDir /media/balth/DATA1/work/LoopSWork/packages/LoopS/LoadDependencies/Dependencies/opiter/opiter
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
#write </media/balth/DATA1/work/LoopSWork/packages/LoopS/Examples/LoopSFile/tempopiter/pvreduceout0.m> "%e",F2;
.end
