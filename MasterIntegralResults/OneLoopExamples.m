(*general MI form with redundant parameters, SymanzikIndepentVars can return \
the independent variables*)

MIformlist = {
   {{l1^2 - a1}, {l1}, {n, nb}, {n^2 -> 0, n nb -> 2, nb^2 -> 0}},
   {{l1^2, (l1 + a1 p + a2 pp)^2}, {l1}, {p, pp}, {p^2 -> 0, p pp -> 1/2, 
     pp^2 -> 0}},
   {{l1^2, l1^2 + a1 l1 n + a2 l1 nb + a3}, {l1}, {n, nb}, {n^2 -> 0, 
     n nb -> 2, nb^2 -> 0}},
   {{l1^2, (l1 + a1 p + a2 pp)^2, (l1 + b1 p + b2 pp)^2}, {l1}, {p, 
     pp}, {p^2 -> 0, p pp -> 1/2, pp^2 -> 0}}
   };

MIsollist = {
   a1 (1/\[Epsilon] + 1 + (1 + \[Pi]^2/12) \[Epsilon] + 
       1/12 (12 + \[Pi]^2 - 4 Zeta[3]) \[Epsilon]^2) + 
    Unique[HOrder]*\[Epsilon]^3,
   Module[{s1 = a1 a2}, 
    1/\[Epsilon] + (2 - Log[-s1]) + 
     1/12 \[Epsilon] (6 Log[-s1]^2 - 24 Log[-s1] - \[Pi]^2 + 48) + 
     Unique[HOrder]*\[Epsilon]^2],
   Module[{s1 = (a1 a2)/(a1 a2 - a3), s2 = a1 a2 - a3},
    1/\[Epsilon] + (2 + (-1 + 1/s1) Log[1 - s1]) + 
     1/(12 s1) (s1 (48 + \[Pi]^2) - 24 (-1 + s1) Log[1 - s1] + 
        6 (-1 + s1) Log[1 - s1]^2 - 
        12 (-1 + s1) PolyLog[2, s1/(-1 + s1)]) \[Epsilon] + 
     Unique[HOrder]*\[Epsilon]^2],
   Module[{s3, x, y},
    s3 = (a1 - b1) (a2 - b2);
    {x, y} = {a1/(a1 - b1), a2/(a2 - b2)};
    -(1/(x - y))*(-s3)^-1*(PolyLog[2, x/y] + PolyLog[2, (1 - y)/(1 - x)] + 
        PolyLog[2, ((1 - x) y)/(x (1 - y))] - PolyLog[2, y/x] - 
        PolyLog[2, (1 - x)/(1 - y)] - PolyLog[2, (x (1 - y))/((1 - x) y)]) + 
     Unique[HOrder]*\[Epsilon]]
   };