(* Patched for use with FeynCalc *)
(*
	SMNLG.mod
		Add-on model file for the SM in Non-Linear Gauge
		needs Lorentzbgf.gen
		based on arXiv:0710.1999
		by Thomas Gajdosik and Jurgis Pasukonis
		last modified 1 Apr 12 by Thomas Hahn
*)


LoadModel["SM"]


ReplaceCouplings[

	(* structural changes re Lorentzbgf.mod *)

  C[ s1 V[j1], s2 V[j2], s3 V[j3] ] == Join[
    C[ s1 V[j1], s2 V[j2], s3 V[j3] ],
    {{0, 0}, {0, 0}, {0, 0}} ],

  C[ s1 S[j1], s2 S[j2], s3 V[j3] ] == Join[
    C[ s1 S[j1], s2 S[j2], s3 V[j3] ],
   -C[ s1 S[j1], s2 S[j2], s3 V[j3] ] ]

]


ReplaceCouplings[

	(* V-V-V-V *)

  C[ -V[3], V[3], V[2], V[2] ] += -I FCGV["EL"]^2 FCGV["CW"]^2/FCGV["SW"]^2 *
    Gbeta^2/FAGaugeXi[W] {{0, 0}, {1, 0}, {1, 0}},

  C[ -V[3], V[3], V[1], V[2] ] += I FCGV["EL"]^2 FCGV["CW"]/FCGV["SW"] *
    Galpha Gbeta/FAGaugeXi[W] {{0, 0}, {1, 0}, {1, 0}},

  C[ -V[3], V[3], V[1], V[1] ] += -I FCGV["EL"]^2 *
    Galpha^2/FAGaugeXi[W] {{0, 0}, {1, 0}, {1, 0}},

	(* V-V-V *)

  C[ V[1], -V[3], V[3] ] += -I FCGV["EL"] *
    Galpha/FAGaugeXi[W] {{0, 0}, {1, 0}, {-1, 0}, {0, 0}},

  C[ V[2], -V[3], V[3] ] += I FCGV["EL"] FCGV["CW"]/FCGV["SW"] *
    Gbeta/FAGaugeXi[W] {{0, 0}, {1, 0}, {-1, 0}, {0, 0}},

	(* S-S-S-S *)

  C[ S[1], S[1], S[2], S[2] ] += -I FCGV["EL"]^2 /(4 FCGV["SW"]^2 FCGV["MW"]^2) *
    2 Gepsilon^2 FCGV["MZ"]^2 FAGaugeXi[Z] {{1, 0}},

  C[ S[1], S[1], S[3], -S[3] ] += -I FCGV["EL"]^2 /(4 FCGV["SW"]^2 FCGV["MW"]^2) *
    2 Gdelta^2 FCGV["MW"]^2 FAGaugeXi[W] {{1, 0}},

  C[ S[2], S[2], S[3], -S[3] ] += -I FCGV["EL"]^2 /(4 FCGV["SW"]^2 FCGV["MW"]^2) *
    2 Gkappa^2 FCGV["MW"]^2 FAGaugeXi[W] {{1, 0}},

	(* S-S-S *)

  C[ S[1], S[2], S[2] ] += -I FCGV["EL"] /(2 FCGV["SW"] FCGV["MW"]) *
    2 Gepsilon FCGV["MZ"]^2 FAGaugeXi[Z] {{1, 0}},

  C[ S[3], S[1], -S[3] ] += -I FCGV["EL"] /(2 FCGV["SW"] FCGV["MW"]) *
    2 Gdelta FCGV["MW"]^2 FAGaugeXi[W] {{1, 0}},

	(* S-S-V-V *)

  C[ S[1], -S[3], V[3], V[2] ] += -I FCGV["EL"]^2/(2 FCGV["CW"]) *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta Gdelta {{1, 0}},

  C[ S[1], S[3], -V[3], V[2] ] += -I FCGV["EL"]^2/(2 FCGV["CW"]) *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta Gdelta {{1, 0}},

  C[ S[1], S[3], -V[3], V[1] ] += -I FCGV["EL"]^2/(2 FCGV["SW"]) *
    (-Galpha Gdelta) {{1, 0}},

  C[ S[1], -S[3], V[3], V[1] ] += -I FCGV["EL"]^2/(2 FCGV["SW"]) *
    (-Galpha Gdelta) {{1, 0}},

  C[ S[3], S[2], V[2], -V[3] ] += FCGV["EL"]^2/(2 FCGV["CW"]) *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta Gkappa {{1, 0}},

  C[ -S[3], S[2], V[2], V[3] ] += -FCGV["EL"]^2/(2 FCGV["CW"]) *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta Gkappa {{1, 0}},

  C[ S[3], S[2], V[1], -V[3] ] += FCGV["EL"]^2/(2 FCGV["SW"]) *
    (-Galpha Gkappa) {{1, 0}},

  C[ -S[3], S[2], V[1], V[3] ] += -FCGV["EL"]^2/(2 FCGV["SW"]) *
    -(Galpha Gkappa) {{1, 0}},

	(* S-S-V *)

  C[ S[2], S[1], V[2] ] += FCGV["EL"]/(2 FCGV["CW"] FCGV["SW"]) *
    Gepsilon {{-1, 0}, {-1, 0}},

  C[ S[3], S[1], -V[3] ] += -I FCGV["EL"]/(2 FCGV["SW"]) *
    Gdelta {{-1, 0}, {-1, 0}},

  C[ -S[3], S[1], V[3] ] += I FCGV["EL"]/(2 FCGV["SW"]) *
    Gdelta {{-1, 0}, {-1, 0}},

  C[ S[3], S[2], -V[3] ] += FCGV["EL"]/(2 FCGV["SW"]) *
    Gkappa {{-1, 0}, {-1, 0}},

  C[ -S[3], S[2], V[3] ] += FCGV["EL"]/(2 FCGV["SW"]) *
    Gkappa {{-1, 0}, {-1, 0}},

	(* S-V-V *)

  C[ -S[3], V[3], V[2] ] += -I FCGV["EL"] FCGV["MW"] FCGV["SW"]/FCGV["CW"] *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta {{1, 0}},

  C[ S[3], -V[3], V[2] ] += -I FCGV["EL"] FCGV["MW"] FCGV["SW"]/FCGV["CW"] *
    FCGV["CW"]^2/FCGV["SW"]^2 Gbeta {{1, 0}},

  C[ -S[3], V[3], V[1] ] += -I FCGV["EL"] FCGV["MW"] * 
    (-Galpha) {{1, 0}},

  C[ S[3], -V[3], V[1] ] += -I FCGV["EL"] FCGV["MW"] * 
    (-Galpha) {{1, 0}},

	(* U-U-V:  G(+) . { p1_mu3, p2_mu3 } *)

  C[ -U[3], U[3], V[1] ] += -I FCGV["EL"] *
    (-Galpha) {{0, 0}, {1, 0}},

  C[ -U[4], U[4], V[1] ] += I FCGV["EL"] *
    (-Galpha) {{0, 0}, {1, 0}},

  C[ -U[3], U[3], V[2] ] += I FCGV["EL"] FCGV["CW"]/FCGV["SW"] *
    (-Gbeta) {{0, 0}, {1, 0}},

  C[ -U[4], U[4], V[2] ] += -I FCGV["EL"] FCGV["CW"]/FCGV["SW"] *
    (-Gbeta) {{0, 0}, {1, 0}},

  C[ -U[3], U[2], V[3] ] += -I FCGV["EL"] FCGV["CW"]/FCGV["SW"] *
    Gbeta {{0, 0}, {1, 0}},

  C[ -U[4], U[2], -V[3] ] += I FCGV["EL"] FCGV["CW"]/FCGV["SW"] *
    Gbeta {{0, 0}, {1, 0}},

  C[ -U[3], U[1], V[3] ] += I FCGV["EL"] *
    Galpha {{0, 0}, {1, 0}},

  C[ -U[4], U[1], -V[3] ] += -I FCGV["EL"] *
    Galpha {{0, 0}, {1, 0}},

	(* S-U-U *)

  C[ S[1], -U[2], U[2] ] += -I FCGV["EL"] FCGV["MZ"] FAGaugeXi[Z]/(2 FCGV["SW"] FCGV["CW"]) *
    Gepsilon {{1, 0}},

  C[ S[1], -U[3], U[3] ] += -I FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["SW"]) *
    Gdelta {{1, 0}},

  C[ S[1], -U[4], U[4] ] += -I FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["SW"]) *
    Gdelta {{1, 0}},

  C[ S[2], -U[4], U[4] ] += FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["SW"]) *
    (-Gkappa) {{1, 0}},

  C[ S[2], -U[3], U[3] ] += -FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["SW"]) *
    (-Gkappa) {{1, 0}},

  C[ -S[3], -U[4], U[2] ] += I FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["CW"] FCGV["SW"]) *
    (-Gkappa) {{1, 0}},

  C[ S[3], -U[3], U[2] ] += I FCGV["EL"] FCGV["MW"] FAGaugeXi[W]/(2 FCGV["CW"] FCGV["SW"]) *
    (-Gkappa) {{1, 0}}

]


M$CouplingMatrices = Join[ M$CouplingMatrices, {

	(* U-U-V-V *)

  C[ -U[4], U[1], V[1], -V[3] ] == -I FCGV["EL"]^2 * 
    {{Galpha}}, 

  C[ -U[3], U[1], V[1], V[3] ] == -I FCGV["EL"]^2 * 
    {{Galpha}}, 

  C[ -U[4], U[1], V[2], -V[3] ] == I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Gbeta}}, 

  C[ -U[3], U[1], V[2], V[3] ] == I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Gbeta}}, 

  C[ -U[4], U[2], V[1], -V[3] ] == I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Galpha}}, 

  C[ -U[3], U[2], V[1], V[3] ] == I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Galpha}}, 

  C[ -U[4], U[2], V[2], -V[3] ] == -I FCGV["EL"]^2 (FCGV["CW"]^2/FCGV["SW"]^2) * 
    {{Gbeta}}, 

  C[ -U[3], U[2], V[2], V[3] ] == -I FCGV["EL"]^2 (FCGV["CW"]^2/FCGV["SW"]^2) * 
    {{Gbeta}}, 

  C[ -U[3], U[3], V[3], -V[3] ] == -I FCGV["EL"]^2 * 
    {{Galpha + FCGV["CW"]^2/FCGV["SW"]^2 Gbeta}},

  C[ -U[4], U[4], V[3], -V[3] ] == -I FCGV["EL"]^2 * 
    {{Galpha + FCGV["CW"]^2/FCGV["SW"]^2*Gbeta}},

  C[ -U[3], U[4], V[3], V[3] ] == 2 I FCGV["EL"]^2 * 
    {{Galpha + FCGV["CW"]^2/FCGV["SW"]^2 Gbeta}},

  C[ -U[4], U[3], -V[3], -V[3] ] == 2 I FCGV["EL"]^2 * 
    {{Galpha + FCGV["CW"]^2/FCGV["SW"]^2 Gbeta}},

  C[ -U[3], U[3], V[1], V[1] ] == 2 I FCGV["EL"]^2 * 
    {{Galpha}},

  C[ -U[4], U[4], V[1], V[1] ] == 2 I FCGV["EL"]^2 * 
    {{Galpha}},

  C[ -U[3], U[3], V[1], V[2] ] == -I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Galpha + Gbeta}},

  C[ -U[4], U[4], V[1], V[2] ] == -I FCGV["EL"]^2 (FCGV["CW"]/FCGV["SW"]) * 
    {{Galpha + Gbeta}},

  C[ -U[3], U[3], V[2], V[2] ] == 2 I FCGV["EL"]^2 (FCGV["CW"]^2/FCGV["SW"]^2) * 
    {{Gbeta}},

  C[ -U[4], U[4], V[2], V[2] ] == 2 I FCGV["EL"]^2 (FCGV["CW"]^2/FCGV["SW"]^2) * 
    {{Gbeta}},

	(* S-S-U-U *)

  C[ S[1], S[1], -U[2], U[2] ] == -I FCGV["EL"]^2 FAGaugeXi[Z]/(2 FCGV["SW"]^2 FCGV["CW"]^2) *
    {{Gepsilon}},

  C[ S[2], S[2], -U[2], U[2] ] == I FCGV["EL"]^2 FAGaugeXi[Z]/(2 FCGV["SW"]^2 FCGV["CW"]^2) *
    {{Gepsilon}},

  C[ S[3], S[1], -U[2], U[4] ] == I FCGV["EL"]^2 FAGaugeXi[Z]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{Gepsilon}},

  C[ -S[3], S[1], -U[2], U[3] ] == I FCGV["EL"]^2 FAGaugeXi[Z]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{Gepsilon}},

  C[ S[3], S[2], -U[2], U[4] ] == FCGV["EL"]^2 FAGaugeXi[Z]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{Gepsilon}},

  C[ -S[3], S[2], -U[2], U[3] ] == - FCGV["EL"]^2 FAGaugeXi[Z]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{Gepsilon}},

  C[ -S[3], S[1], -U[4], U[1] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]) *
    {{Gdelta}},

  C[ S[3], S[1], -U[3], U[1] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]) *
    {{Gdelta}},

  C[ -S[3], S[2], -U[4], U[1] ] == FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]) *
    {{Gkappa}},

  C[ S[3], S[2], -U[3], U[1] ] == -FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]) *
    {{Gkappa}},

  C[ -S[3], S[1], -U[4], U[2] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{ Gkappa + Gdelta (FCGV["CW"]^2 - FCGV["SW"]^2) }},

  C[ S[3], S[1], -U[3], U[2] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{ Gkappa + Gdelta (FCGV["CW"]^2 - FCGV["SW"]^2) }},

  C[ -S[3], S[2], -U[4], U[2] ] == -FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{ Gdelta + Gkappa (FCGV["CW"]^2 - FCGV["SW"]^2) }},

  C[ S[3], S[2], -U[3], U[2] ] == FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2 FCGV["CW"]) *
    {{ Gdelta + Gkappa (FCGV["CW"]^2 - FCGV["SW"]^2) }},

  C[ S[1], S[1], -U[3], U[3] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gdelta }},

  C[ S[1], S[1], -U[4], U[4] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gdelta }},

  C[ S[2], S[2], -U[3], U[3] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gkappa }},

  C[ S[2], S[2], -U[4], U[4] ] == -I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gkappa }},

  C[ S[2], S[1], -U[3], U[3] ] == FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2) *
    {{ Gkappa - Gdelta }},

  C[ S[2], S[1], -U[4], U[4] ] == -FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2) *
    {{ Gkappa - Gdelta }},

  C[ S[3], -S[3], -U[3], U[3] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2) *
    {{ Gkappa + Gdelta }},

  C[ S[3], -S[3], -U[4], U[4] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(4 FCGV["SW"]^2) *
    {{ Gkappa + Gdelta }},

  C[ S[3], S[3], -U[3], U[4] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gkappa - Gdelta }},

  C[ -S[3], -S[3], -U[4], U[3] ] == I FCGV["EL"]^2 FAGaugeXi[W]/(2 FCGV["SW"]^2) *
    {{ Gkappa - Gdelta }}

} ]

