
#: IncDir /home/balth/.Mathematica/Applications/LoopS/LoadDependencies/Dependencies/opiter/opiter
#include- opiter.frm
Autodeclare Vector q;
Off statistics;
L F2=ext(q1,q2)*loop(p1,p2)*p1(mu1)*p1(mu2)*p1(mu3)*p2(mu4)*p2(mu5);
#call opiter
.sort
#call symmetrise
.sort
#call leavedualtransverse
.sort
B loop,ext,Gsigma,d_,ddts,dual,sym,deno;
#write </home/balth/.Mathematica/Applications/LoopS/Examples/LoopSFile/tempopiter/pvreduceout3.m> "%e",F2;
.end
