(* Patched for use with FeynCalc *)
(*
	MSSMQCD.mod
		Addendum classes model file for MSSM.mod
		to include the strong interactions
		by Christian Schappacher
		last modified 12 Mar 14 by cs

Note: The four-squark couplings are part of MSSM.mod even though
a part of their coupling is proportional to Alfas.

This file introduces the following symbols in addition to the ones in
MSSM.mod:

	FAGS: the strong coupling constant

	MGl: the gluino mass
	SqrtEGl: sqrt of the gluino phase (phase of M_3)

	FASUNT[a, i, j]: the generators of SU(N)
		(half the Gell-Mann matrices)

	SUNTSum[i, j, k, l] = \sum_g FASUNT[g, i, j] FASUNT[g, k, l]

	FASUNF[a, b, c]: the structure constants of SU(N)

	FASUNF[a, b, c, d]: a short-hand for the sum
		\sum_i FASUNF[a, b, i] FASUNF[i, c, d]

	FAGaugeXi[G]: gluon gauge parameter
*)


LoadModel["MSSM"]

If[ TrueQ[$NoElectroweak], M$CouplingMatrices = {} ]


IndexRange[ Index[Gluon] ] = NoUnfold[Range[8]]

M$ClassesDescription = Join[ M$ClassesDescription, {

(*--- gluons -----------------------------------------------------------*)

  V[5] == {
	SelfConjugate -> True,
	Indices -> {Index[Gluon]},
	Mass -> 0,
	QuantumNumbers -> {Sqrt[3] ColorCharge},
	PropagatorLabel -> "g",
	PropagatorType -> Cycles,
	PropagatorArrow -> None },


(*--- gluon ghosts -----------------------------------------------------*)

  U[5] == {
	SelfConjugate -> False,
	Indices -> {Index[Gluon]},
	Mass -> 0,
	QuantumNumbers -> {Sqrt[3] ColorCharge, GhostNumber},
	PropagatorLabel -> ComposedChar["u", "g"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },


(*--- gluinos ----------------------------------------------------------*)

  F[15] == { 
	SelfConjugate -> True,
	Indices -> {Index[Gluon]},
	Mass -> MGl,
	QuantumNumbers -> {Sqrt[3] ColorCharge},
	PropagatorLabel -> ComposedChar["g", Null, Null, "\\tilde"],
	PropagatorType -> Straight, 
	PropagatorArrow -> None }

} ]


MGl[_] = MGl

FAGaugeXi[ V[5] ] = FAGaugeXi[G];
FAGaugeXi[ U[5] ] = FAGaugeXi[G]


M$CouplingMatrices = Join[ M$CouplingMatrices, {


(*--- gluon-gluon-gluon-gluon ------------------------------------------*)

  C[ V[5, {g1}], V[5, {g2}], V[5, {g3}], V[5, {g4}] ] == -I FAGS^2 * 
    { { FASUNF[g1, g3, g2, g4] - FASUNF[g1, g4, g3, g2]},
      { FASUNF[g1, g2, g3, g4] + FASUNF[g1, g4, g3, g2]},
      {-FASUNF[g1, g2, g3, g4] - FASUNF[g1, g3, g2, g4]} },


(*--- gluon-gluon-gluon ------------------------------------------------*)

  C[ V[5, {g1}], V[5, {g2}], V[5, {g3}] ] == FAGS *
    { {FASUNF[g1, g2, g3]} },


(*--- ghost-ghost-gluon ------------------------------------------------*)

  C[ -U[5, {g1}], U[5, {g2}], V[5, {g3}] ] == FAGS *
    { {FASUNF[g1, g2, g3]},
      {0} },


(*--- quark-quark-gluon ------------------------------------------------*)

  C[ -F[3, {j1, o1}], F[3, {j2, o2}], V[5, {g1}] ] == -I FAGS *
    IndexDelta[j1, j2] FASUNT[g1, o1, o2] * 
    { {1},
      {1} },

  C[ -F[4, {j1, o1}], F[4, {j2, o2}], V[5, {g1}] ] == -I FAGS *
    IndexDelta[j1, j2] FASUNT[g1, o1, o2] *
    { {1},
      {1} },


(*--- gluino-gluino-gluon ----------------------------------------------*)

  C[ F[15, {g1}], F[15, {g2}], V[5, {g3}] ] == -FAGS *
    FASUNF[g1, g2, g3] *
    { {1},
      {1} },


(*--- squark-squark-gluon ----------------------------------------------*)

  C[ S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[5, {g1}] ] == -I FAGS *
    { {IndexDelta[s1, s2] IndexDelta[j1, j2] FASUNT[g1, o2, o1]} },

  C[ S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[5, {g1}] ] == -I FAGS *
    { {IndexDelta[s1, s2] IndexDelta[j1, j2] FASUNT[g1, o2, o1]} },


(*--- gluino-quark-squark ----------------------------------------------*)

  C[ F[15, {g1}], -F[3, {j1, o1}], S[13, {s2, j2, o2}] ] == I FAGS *
    Sqrt[2] FASUNT[g1, o1, o2] IndexDelta[j1, j2] *
    { { Conjugate[USf[3, j1][s2, 2]] Conjugate[SqrtEGl]},
      {-Conjugate[USf[3, j1][s2, 1]] SqrtEGl} },

  C[ F[15, {g1}], -F[4, {j1, o1}], S[14, {s2, j2, o2}] ] == I FAGS *
    Sqrt[2] FASUNT[g1, o1, o2] IndexDelta[j1, j2] *
    { { Conjugate[USf[4, j1][s2, 2]] Conjugate[SqrtEGl]},
      {-Conjugate[USf[4, j1][s2, 1]] SqrtEGl} },

  C[ F[15, {g1}], F[3, {j1, o1}], -S[13, {s2, j2, o2}] ] == I FAGS *
    Sqrt[2] FASUNT[g1, o2, o1] IndexDelta[j1, j2] *
    { {-USf[3, j1][s2, 1] Conjugate[SqrtEGl]},
      { USf[3, j1][s2, 2] SqrtEGl} },

  C[ F[15, {g1}], F[4, {j1, o1}], -S[14, {s2, j2, o2}] ] == I FAGS *
    Sqrt[2] FASUNT[g1, o2, o1] IndexDelta[j1, j2] *
    { {-USf[4, j1][s2, 1] Conjugate[SqrtEGl]},
      { USf[4, j1][s2, 2] SqrtEGl} },


(*--- squark-squark-gluon-gluon ----------------------------------------*)

  C[ S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[5, {g1}], V[5, {g2}] ] ==
    I FAGS^2 IndexDelta[s1, s2] IndexDelta[j1, j2] *
    { {FASUNT[g1, g2, o2, o1] + FASUNT[g2, g1, o2, o1]} },

  C[ S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[5, {g1}], V[5, {g2}] ] ==
    I FAGS^2 IndexDelta[s1, s2] IndexDelta[j1, j2] *
    { {FASUNT[g1, g2, o2, o1] + FASUNT[g2, g1, o2, o1]} },


(*--- squark-squark-gluon-gauge ----------------------------------------*)

  C[ S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[5, {g1}], V[1] ] ==
    2 I FCGV["EL"] FAGS IndexDelta[s1, s2] IndexDelta[j1, j2] FASUNT[g1, o2, o1] *
    { {2/3} }, 

  C[ S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[5, {g1}], V[1] ] ==
    2 I FCGV["EL"] FAGS IndexDelta[s1, s2] IndexDelta[j1, j2] FASUNT[g1, o2, o1] *
    { {-1/3} }, 

  C[ S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[5, {g1}], V[2] ] ==
    2 I FCGV["EL"]/FCGV["SW"]/FCGV["CW"] FAGS IndexDelta[j1, j2] FASUNT[g1, o2, o1] *
    { {1/2 Conjugate[USf[3, j1][s1, 1]] USf[3, j1][s2, 1] -
         2/3 IndexDelta[s1, s2] FCGV["SW"]^2} }, 

  C[ S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[5, {g1}], V[2] ] ==
    2 I FCGV["EL"]/FCGV["SW"]/FCGV["CW"] FAGS IndexDelta[j1, j2] FASUNT[g1, o2, o1] *
    { {-1/2 Conjugate[USf[4, j1][s1, 1]] USf[4, j1][s2, 1] +
         1/3 IndexDelta[s1, s2] FCGV["SW"]^2} }, 

  C[ S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[5, {g1}], V[3] ] ==
    I FCGV["EL"]/FCGV["SW"] FAGS Sqrt[2] Conjugate[CKM[j1, j2]] FASUNT[g1, o2, o1] *
    { {Conjugate[USf[3, j1][s1, 1]] USf[4, j2][s2, 1]} }, 

  C[ S[14, {s2, j2, o2}], -S[13, {s1, j1, o1}], V[5, {g1}], -V[3] ] ==
    I FCGV["EL"]/FCGV["SW"] FAGS Sqrt[2] CKM[j1, j2] FASUNT[g1, o1, o2] *
    { {Conjugate[USf[4, j2][s2, 1]] USf[3, j1][s1, 1]} }
} ]

