(* Patched for use with FeynCalc *)
(*
	THDM.mod
		Classes model file for the Two-Higgs-Doublet Model
		by Abdesslam Arhrib, Oliver Brein, and Thomas Hahn
		last modified 13 Aug 09 by Thomas Hahn

This file contains the definition of the two-Higgs-doublet model
for FeynArts.  It needs the Generic model file Lorentz.gen.

When you change things, remember:

-- All particles are arranged in classes.  For single particle
   model definitions each particle lives in its own class.

-- For each class the common SelfConjugate behaviour and the
   IndexRange MUST be present in the definitions.

-- IMPORTANT: The coupling matrices MUST be declared in the
   SAME order as the Generic coupling.

This file introduces the following symbols:

	coupling constants and masses:
	------------------------------
	FCGV["EL"]:		electron charge (Thomson limit)
	FCGV["CW"], FCGV["SW"]:		cosine and sine of weak mixing angle

	FCGV["MW"], FCGV["MZ"]:		W, and Z masses
	Mh0, MHH, MA0, MHp: the Higgs masses

	MLE:		lepton class mass
	FCGV["ME"], FCGV["MM"], FCGV["ML"]:	lepton masses (e, mu, tau)

	MQU:		u-type quark class mass
	FCGV["MU"], FCGV["MC"], FCGV["MT"]:	u-type quark masses (up, charm, top)

	MQD:		d-type quark class mass
	FCGV["MD"], FCGV["MS"], FCGV["MB"]:	d-type quark masses (down, strange, bottom)

	CKM:		quark mixing matrix
			(set CKM = IndexDelta for no quark-mixing)

	CA, SA:		{Cos, Sin}[alpha]
	CB, SB, TB:	{Cos, Sin, Tan}[beta]
	C2A, S2A:	{Cos, Sin}[2 alpha]
	CAB, SAB:	{Cos, Sin}[alpha + beta]
	CBA, SBA:	{Cos, Sin}[beta - alpha]
			where alpha is the (h0, H0) mixing angle
			and tan[beta] is the ratio of the VEVs of
			the two Higgs doublets
*)


(* $HKSign is the sign in the SU(2) covariant derivative,
   i.e. D_\mu = \partial_\mu + $HKSign I g A^a_\mu \tau^a,
   so 1 = Haber-Kane, -1 = Denner conventions *)

If[ !ValueQ[$HKSign], $HKSign = 1 ]

IndexRange[ Index[Generation] ] = Range[3];
IndexRange[ Index[Colour] ] = NoUnfold[Range[3]];

IndexStyle[ Index[Generation, i_Integer] ] := Alph[i + 8] 

M$ClassesDescription = {

	(* Neutrinos: I_3 = +1/2, Q = 0 *)
  F[1] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation]},
	Mass -> 0,
	PropagatorLabel -> ComposedChar["\\nu", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* massive Leptons: I_3 = -1/2, Q = -1 *)
  F[2] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation]},
	Mass -> MLE,
	PropagatorLabel -> ComposedChar["e", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* Quarks (u): I_3 = +1/2, Q = +2/3 *)
  F[3] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation], Index[Colour]},
	Mass -> MQU,
	PropagatorLabel -> ComposedChar["u", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* Quarks (d): I_3 = -1/2, Q = -1/3 *)
  F[4] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation], Index[Colour]},
	Mass -> MQD,
	PropagatorLabel -> ComposedChar["d", Index[Generation]],
	PropagatorType -> Straight, 
	PropagatorArrow -> Forward },

	(* Gauge bosons: Q = 0 *)
  V[1] == {
	SelfConjugate -> True,
	Indices -> {},
	Mass -> 0,
	PropagatorLabel -> "\\gamma",
	PropagatorType -> Sine,
	PropagatorArrow -> None },

  V[2] == {
	SelfConjugate -> True, 
	Indices -> {},
	Mass -> FCGV["MZ"],
	PropagatorLabel -> "Z",
	PropagatorType -> Sine,
	PropagatorArrow -> None },

	(* Gauge bosons: Q = -1 *)
  V[3] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	PropagatorLabel -> "W",
	PropagatorType -> Sine,
	PropagatorArrow -> Forward },

	(* CP-even Higgs doublet: Q = 0 *)
  S[1] == {
	SelfConjugate -> True,
	Indices -> {},
	Mass -> Mh0,
	PropagatorLabel -> ComposedChar["h", Null, "0"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> None },

  S[2] == {
	SelfConjugate -> True,
	Indices -> {},
	Mass -> MHH,
	PropagatorLabel -> ComposedChar["H", Null, "0"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> None },

	(* CP-odd Higgs doublet: Q = 0 *)
  S[3] == {
	SelfConjugate -> True,
	Indices -> {},
	Mass -> MA0,
	PropagatorLabel -> ComposedChar["A", Null, "0"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> None },

  S[4] == {
	SelfConjugate -> True,
	Indices -> {},
	Mass -> FCGV["MZ"],
	PropagatorLabel -> ComposedChar["G", Null, "0"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> None },

	(* charged Higgs doublet: Q = -1 *)
  S[5] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> MHp,
	PropagatorLabel -> "H",
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

  S[6] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	PropagatorLabel -> "G",
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Ghosts: Q = 0 *)
  U[1] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> 0,
	PropagatorLabel -> ComposedChar["u", "\\gamma"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

  U[2] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MZ"],
	PropagatorLabel -> ComposedChar["u", "Z"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

	(* Ghosts: Q = -1 *)
  U[3] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	PropagatorLabel -> ComposedChar["u", "-"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

  U[4] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	PropagatorLabel -> ComposedChar["u", "+"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward }
}

MLE[1] = FCGV["ME"];
MLE[2] = FCGV["MM"];
MLE[3] = FCGV["ML"];
MQU[1] = FCGV["MU"];
MQU[2] = FCGV["MC"];
MQU[3] = FCGV["MT"];
MQD[1] = FCGV["MD"];
MQD[2] = FCGV["MS"];
MQD[3] = FCGV["MB"];
MQU[gen_, _] = MQU[gen];
MQD[gen_, _] = MQD[gen]

TheLabel[ F[1, {1}] ] = ComposedChar["\\nu", "e"]; 
TheLabel[ F[1, {2}] ] = ComposedChar["\\nu", "\\mu"]; 
TheLabel[ F[1, {3}] ] = ComposedChar["\\nu", "\\tau"]; 
TheLabel[ F[2, {1}] ] = "e"; 
TheLabel[ F[2, {2}] ] = "\\mu"; 
TheLabel[ F[2, {3}] ] = "\\tau";
TheLabel[ F[3, {1, ___}] ] = "u"; 
TheLabel[ F[3, {2, ___}] ] = "c";
TheLabel[ F[3, {3, ___}] ] = "t";
TheLabel[ F[4, {1, ___}] ] = "d"; 
TheLabel[ F[4, {2, ___}] ] = "s";
TheLabel[ F[4, {3, ___}] ] = "b"


M$LastModelRules = {}


(* some short-hands for excluding classes of particles *)

NoGeneration1 = ExcludeParticles -> F[_, {1, ___}]

NoGeneration2 = ExcludeParticles -> F[_, {2, ___}]

NoGeneration3 = ExcludeParticles -> F[_, {3, ___}]

NoElectronHCoupling =
  ExcludeFieldPoints -> {
    FieldPoint[0][-F[2, {1}], F[2, {1}], S],
    FieldPoint[0][-F[2, {1}], F[1, {1}], S] }

NoLightFHCoupling =
  ExcludeFieldPoints -> {
    FieldPoint[_][-F[2], F[2], S],
    FieldPoint[_][-F[2], F[1], S],
    FieldPoint[_][-F[3, {1, ___}], F[3, {1, ___}], S],
    FieldPoint[_][-F[3, {2, ___}], F[3, {2, ___}], S],
    FieldPoint[_][-F[4], F[4], S],
    FieldPoint[_][-F[4], F[3, {1, ___}], S],
    FieldPoint[_][-F[4], F[3, {2, ___}], S] }

M$CouplingMatrices = {C[S[6], -S[6], V[1]] == {{I*FCGV["EL"]}}, C[S[6], -S[6], V[2]] == 
  {{((I/2)*FCGV["EL"]*(FCGV["CW"]^2 - FCGV["SW"]^2))/(FCGV["CW"]*FCGV["SW"])}}, C[S[4], S[6], -V[3]] == 
  {{FCGV["EL"]/(2*FCGV["SW"])}}, C[S[4], -S[6], V[3]] == {{FCGV["EL"]/(2*FCGV["SW"])}}, 
 C[S[6], V[1], -V[3]] == {{I*FCGV["EL"]*FCGV["MW"]}}, C[-S[6], V[1], V[3]] == {{I*FCGV["EL"]*FCGV["MW"]}}, 
 C[S[6], V[2], -V[3]] == {{((-I)*FCGV["EL"]*FCGV["MW"]*FCGV["SW"])/FCGV["CW"]}}, 
 C[-S[6], V[2], V[3]] == {{((-I)*FCGV["EL"]*FCGV["MW"]*FCGV["SW"])/FCGV["CW"]}}, 
 C[V[1], -V[3], V[3]] == {{(-I)*FCGV["EL"]}}, C[V[2], -V[3], V[3]] == 
  {{((-I)*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}}, C[S[4], U[3], -U[3]] == 
  {{-(FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/(2*FCGV["SW"])}}, C[S[4], U[4], -U[4]] == 
  {{(FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/(2*FCGV["SW"])}}, C[S[6], U[1], -U[3]] == 
  {{(-I)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W]}}, C[-S[6], U[1], -U[4]] == 
  {{(-I)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W]}}, C[S[6], U[2], -U[3]] == 
  {{((I/2)*FCGV["EL"]*FCGV["MW"]*(-FCGV["CW"]^2 + FCGV["SW"]^2)*FAGaugeXi[W])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-S[6], U[2], -U[4]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*(-FCGV["CW"]^2 + FCGV["SW"]^2)*FAGaugeXi[W])/
     (FCGV["CW"]*FCGV["SW"])}}, C[S[6], U[4], -U[2]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-S[6], U[3], -U[2]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-U[3], U[3], V[1]] == {{(-I)*FCGV["EL"]}, {0}}, C[-U[4], U[4], V[1]] == 
  {{I*FCGV["EL"]}, {0}}, C[-U[3], U[3], V[2]] == {{((-I)*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, 
 C[-U[4], U[4], V[2]] == {{(I*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, 
 C[-U[3], U[1], V[3]] == {{I*FCGV["EL"]}, {0}}, C[-U[4], U[1], -V[3]] == 
  {{(-I)*FCGV["EL"]}, {0}}, C[-U[1], U[4], V[3]] == {{(-I)*FCGV["EL"]}, {0}}, 
 C[-U[1], U[3], -V[3]] == {{I*FCGV["EL"]}, {0}}, C[-U[3], U[2], V[3]] == 
  {{(I*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, C[-U[4], U[2], -V[3]] == {{((-I)*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, 
 C[-U[2], U[4], V[3]] == {{((-I)*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, 
 C[-U[2], U[3], -V[3]] == {{(I*FCGV["CW"]*FCGV["EL"])/FCGV["SW"]}, {0}}, 
 C[S[1], S[1], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[4], S[4], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[6], -S[6], V[1], V[1]] == {{(2*I)*FCGV["EL"]^2}}, 
 C[S[6], -S[6], V[1], V[2]] == {{(I*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[6], -S[6], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], -S[6], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[V[1], V[1], V[3], -V[3]] == {{(-2*I)*FCGV["EL"]^2}, {I*FCGV["EL"]^2}, {I*FCGV["EL"]^2}}, 
 C[V[1], V[2], V[3], -V[3]] == {{((-2*I)*FCGV["CW"]*FCGV["EL"]^2)/FCGV["SW"]}, {(I*FCGV["CW"]*FCGV["EL"]^2)/FCGV["SW"]}, 
   {(I*FCGV["CW"]*FCGV["EL"]^2)/FCGV["SW"]}}, C[V[2], V[2], V[3], -V[3]] == 
  {{((-2*I)*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}, {(I*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}, {(I*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[V[3], V[3], -V[3], -V[3]] == {{((2*I)*FCGV["EL"]^2)/FCGV["SW"]^2}, {((-I)*FCGV["EL"]^2)/FCGV["SW"]^2}, 
   {((-I)*FCGV["EL"]^2)/FCGV["SW"]^2}}, C[S[1], S[1], S[1]] == 
  {{(((-3*I)/2)*FCGV["EL"]*(Mh0^2*(2*CAB + S2A*SBA) - (4*CAB*CBA^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/
        FCGV["EL"]^2))/(FCGV["MW"]*S2B*FCGV["SW"])}}, C[S[1], S[1], S[2]] == 
  {{((-I/2)*CBA*FCGV["EL"]*((2*Mh0^2 + MHH^2)*S2A - (2*Lambda5*FCGV["MW"]^2*(3*S2A - S2B)*
         FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]*S2B*FCGV["SW"])}}, C[S[1], S[2], S[2]] == 
  {{((I/2)*FCGV["EL"]*SBA*((Mh0^2 + 2*MHH^2)*S2A - (2*Lambda5*FCGV["MW"]^2*(3*S2A + S2B)*
         FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]*S2B*FCGV["SW"])}}, C[S[2], S[2], S[2]] == 
  {{(((-3*I)/2)*FCGV["EL"]*(MHH^2*(-(CBA*S2A) + 2*SAB) - 
       (4*Lambda5*FCGV["MW"]^2*SAB*SBA^2*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]*S2B*FCGV["SW"])}}, 
 C[S[1], S[3], S[3]] == 
  {{((-I/2)*FCGV["EL"]*(-((-2*MA0^2 + Mh0^2)*SBA) + 
       (CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/S2B))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[3], S[4]] == {{((I/2)*CBA*FCGV["EL"]*(MA0^2 - Mh0^2))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[4], S[4]] == {{((-I/2)*FCGV["EL"]*Mh0^2*SBA)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[3], S[3]] == 
  {{((-I/2)*FCGV["EL"]*(-(CBA*(-2*MA0^2 + MHH^2)) + 
       (SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/S2B))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[3], S[4]] == {{((-I/2)*FCGV["EL"]*(MA0^2 - MHH^2)*SBA)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[4], S[4]] == {{((-I/2)*CBA*FCGV["EL"]*MHH^2)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[5], -S[5]] == 
  {{((-I/2)*FCGV["EL"]*(-((Mh0^2 - 2*MHp^2)*SBA) + 
       (CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/S2B))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[5], -S[6]] == {{((-I/2)*CBA*FCGV["EL"]*(Mh0^2 - MHp^2))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[6], -S[5]] == {{((-I/2)*CBA*FCGV["EL"]*(Mh0^2 - MHp^2))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[6], -S[6]] == {{((-I/2)*FCGV["EL"]*Mh0^2*SBA)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[5], -S[5]] == 
  {{((-I/2)*FCGV["EL"]*(-(CBA*(MHH^2 - 2*MHp^2)) + 
       (SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/S2B))/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[5], -S[6]] == {{((I/2)*FCGV["EL"]*(MHH^2 - MHp^2)*SBA)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[6], -S[5]] == {{((I/2)*FCGV["EL"]*(MHH^2 - MHp^2)*SBA)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[6], -S[6]] == {{((-I/2)*CBA*FCGV["EL"]*MHH^2)/(FCGV["MW"]*FCGV["SW"])}}, 
 C[S[3], S[5], -S[6]] == {{-(FCGV["EL"]*(-MA0^2 + MHp^2))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[3], S[6], -S[5]] == {{(FCGV["EL"]*(-MA0^2 + MHp^2))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[3], V[2]] == {{(CBA*FCGV["EL"])/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[1], S[4], V[2]] == {{(FCGV["EL"]*SBA)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[2], S[3], V[2]] == {{-(FCGV["EL"]*SBA)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[2], S[4], V[2]] == {{(CBA*FCGV["EL"])/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[5], -S[5], V[1]] == {{I*FCGV["EL"]}}, C[S[5], -S[5], V[2]] == 
  {{((I/2)*FCGV["EL"]*(FCGV["CW"]^2 - FCGV["SW"]^2))/(FCGV["CW"]*FCGV["SW"])}}, C[S[1], S[5], -V[3]] == 
  {{((-I/2)*CBA*FCGV["EL"])/FCGV["SW"]}}, C[S[1], S[6], -V[3]] == {{((-I/2)*FCGV["EL"]*SBA)/FCGV["SW"]}}, 
 C[S[2], S[5], -V[3]] == {{((I/2)*FCGV["EL"]*SBA)/FCGV["SW"]}}, 
 C[S[2], S[6], -V[3]] == {{((-I/2)*CBA*FCGV["EL"])/FCGV["SW"]}}, 
 C[S[1], -S[5], V[3]] == {{((I/2)*CBA*FCGV["EL"])/FCGV["SW"]}}, 
 C[S[1], -S[6], V[3]] == {{((I/2)*FCGV["EL"]*SBA)/FCGV["SW"]}}, 
 C[S[2], -S[5], V[3]] == {{((-I/2)*FCGV["EL"]*SBA)/FCGV["SW"]}}, 
 C[S[2], -S[6], V[3]] == {{((I/2)*CBA*FCGV["EL"])/FCGV["SW"]}}, 
 C[S[3], S[5], -V[3]] == {{FCGV["EL"]/(2*FCGV["SW"])}}, C[S[3], -S[5], V[3]] == 
  {{FCGV["EL"]/(2*FCGV["SW"])}}, C[S[1], V[2], V[2]] == {{(I*FCGV["EL"]*FCGV["MW"]*SBA)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], V[2], V[2]] == {{(I*CBA*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], V[3], -V[3]] == {{(I*FCGV["EL"]*FCGV["MW"]*SBA)/FCGV["SW"]}}, 
 C[S[2], V[3], -V[3]] == {{(I*CBA*FCGV["EL"]*FCGV["MW"])/FCGV["SW"]}}, 
 C[S[1], U[2], -U[2]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[Z])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], U[2], -U[2]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], U[3], -U[3]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[2], U[3], -U[3]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[1], U[4], -U[4]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[2], U[4], -U[4]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[1], S[1], S[1], S[1]] == 
  {{(((-3*I)/4)*FCGV["EL"]^2*(CBA^2*MHH^2*S2A^2 + Mh0^2*(2*CAB + S2A*SBA)^2 - 
       (2*(C2A + C2B)^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[1], S[2]] == 
  {{(((-3*I)/4)*CBA*FCGV["EL"]^2*S2A*((Mh0^2 - MHH^2)*S2A*SBA + 
       CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[1], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(3*S2A^2*(CBA^2*Mh0^2 + MHH^2*SBA^2 - (2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/
          FCGV["EL"]^2) - S2B*((Mh0^2 - MHH^2)*S2A - (2*Lambda5*FCGV["MW"]^2*S2B*FCGV["SW"]^2)/
          FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[2], S[2], S[2], S[1]] == 
  {{(((3*I)/4)*FCGV["EL"]^2*S2A*SBA*(CBA*(Mh0^2 - MHH^2)*S2A + 
       SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[2], S[2]] == 
  {{(((-3*I)/4)*FCGV["EL"]^2*(MHH^2*(-(CBA*S2A) + 2*SAB)^2 + Mh0^2*S2A^2*SBA^2 - 
       (2*(C2A - C2B)^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA*MHH^2*S2A*(-(CBA*S2B) + 2*SAB) + 2*MA0^2*S2B^2*SBA^2 + 
       Mh0^2*(2*CAB + S2A*SBA)*(2*CAB - S2B*SBA) - 
       (4*(CAB^2 + C2B^2*CBA^2)*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[4], S[3], S[1], S[1]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*((Mh0^2 - MHH^2)*S2A*SBA - 
       S2B*SBA*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) + 
       CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[4], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA^2*(-Mh0^2 + MHH^2)*S2A + Mh0^2*S2B + 
       CBA^2*S2B*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[S[2], S[1], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHH^2*S2A*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*S2A*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*S2A*FCGV["SW"]^2)/FCGV["EL"]^2 + 
       CBA*S2B^2*SBA*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[2], S[1], S[3], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MA0^2*S2B*(CBA^2 - SBA^2)) + 
       S2A*(CBA^2*Mh0^2 + MHH^2*SBA^2) + (4*C2B*CBA*Lambda5*FCGV["MW"]^2*SBA*FCGV["SW"]^2)/
        FCGV["EL"]^2))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[S[2], S[1], S[4], S[4]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*SBA*((Mh0^2 - MHH^2)*S2A - 
       S2B*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(2*CBA^2*MA0^2*S2B^2 + MHH^2*(-(CBA*S2A) + 2*SAB)*
        (-(CBA*S2B) + 2*SAB) - Mh0^2*S2A*SBA*(2*CAB - S2B*SBA) - 
       (4*Lambda5*FCGV["MW"]^2*(SAB^2 + C2B^2*SBA^2)*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[4], S[3], S[2], S[2]] == 
  {{((I/4)*FCGV["EL"]^2*SBA*(CBA*(Mh0^2 - MHH^2)*S2A - 
       CBA*S2B*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) + 
       SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[4], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(MHH^2*S2B + (-Mh0^2 + MHH^2)*S2A*SBA^2 + 
       S2B*SBA^2*(2*MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], S[1], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA*MHH^2*S2A*(-(CBA*S2B) + 2*SAB) + 2*MHp^2*S2B^2*SBA^2 + 
       Mh0^2*(2*CAB + S2A*SBA)*(2*CAB - S2B*SBA) - 
       (4*(CAB^2 + C2B^2*CBA^2)*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[-S[6], S[5], S[1], S[1]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*((Mh0^2 - MHH^2)*S2A*SBA + 
       CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) - 
       S2B*SBA*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[1], S[1]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*((Mh0^2 - MHH^2)*S2A*SBA + 
       CAB*(2*Mh0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) - 
       S2B*SBA*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[6], S[6], S[1], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA^2*(-Mh0^2 + MHH^2)*S2A + Mh0^2*S2B + 
       CBA^2*S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], S[2], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHH^2*S2A*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*S2A*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*S2A*FCGV["SW"]^2)/FCGV["EL"]^2 + 
       CBA*S2B^2*SBA*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[5], -S[6], S[2], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHp^2*S2B*(CBA^2 - SBA^2)) + 
       S2A*(CBA^2*Mh0^2 + MHH^2*SBA^2) + (4*C2B*CBA*Lambda5*FCGV["MW"]^2*SBA*FCGV["SW"]^2)/
        FCGV["EL"]^2))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[S[6], -S[5], S[2], S[1]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHp^2*S2B*(CBA^2 - SBA^2)) + 
       S2A*(CBA^2*Mh0^2 + MHH^2*SBA^2) + (4*C2B*CBA*Lambda5*FCGV["MW"]^2*SBA*FCGV["SW"]^2)/
        FCGV["EL"]^2))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[6], S[6], S[2], S[1]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*SBA*((Mh0^2 - MHH^2)*S2A - 
       S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], S[2], S[2]] == 
  {{((-I/4)*FCGV["EL"]^2*(2*CBA^2*MHp^2*S2B^2 + MHH^2*(-(CBA*S2A) + 2*SAB)*
        (-(CBA*S2B) + 2*SAB) - Mh0^2*S2A*SBA*(2*CAB - S2B*SBA) - 
       (4*Lambda5*FCGV["MW"]^2*(SAB^2 + C2B^2*SBA^2)*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[5], -S[6], S[2], S[2]] == 
  {{((I/4)*FCGV["EL"]^2*SBA*(CBA*(Mh0^2 - MHH^2)*S2A + 
       SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) - 
       CBA*S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[2], S[2]] == 
  {{((I/4)*FCGV["EL"]^2*SBA*(CBA*(Mh0^2 - MHH^2)*S2A + 
       SAB*(2*MHH^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2) - 
       CBA*S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[6], S[6], S[2], S[2]] == 
  {{((-I/4)*FCGV["EL"]^2*(MHH^2*S2B + (-Mh0^2 + MHH^2)*S2A*SBA^2 + 
       S2B*SBA^2*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[6], S[5], S[1], S[3]] == 
  {{-(FCGV["EL"]^2*(-MA0^2 + MHp^2)*SBA)/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[1], S[3]] == {{(FCGV["EL"]^2*(-MA0^2 + MHp^2)*SBA)/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[6], S[5], S[1], S[4]] == {{(CBA*FCGV["EL"]^2*(-MA0^2 + MHp^2))/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[1], S[4]] == 
  {{-(CBA*FCGV["EL"]^2*(-MA0^2 + MHp^2))/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[6], S[5], S[2], S[3]] == 
  {{-(CBA*FCGV["EL"]^2*(-MA0^2 + MHp^2))/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[2], S[3]] == {{(CBA*FCGV["EL"]^2*(-MA0^2 + MHp^2))/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], -S[6], S[2], S[4]] == 
  {{-(FCGV["EL"]^2*(-MA0^2 + MHp^2)*SBA)/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[2], S[4]] == {{(FCGV["EL"]^2*(-MA0^2 + MHp^2)*SBA)/(4*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[3], S[3]] == 
  {{(((-3*I)/4)*FCGV["EL"]^2*(MHH^2*(-(CBA*S2B) + 2*SAB)^2 + 
       Mh0^2*(2*CAB - S2B*SBA)^2 - (8*C2B^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, C[S[3], S[3], S[3], S[4]] == 
  {{(((-3*I)/4)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[S[3], S[3], S[4], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(Mh0^2*(-S2A + 3*CBA^2*S2B) + MHH^2*(S2A + 3*S2B*SBA^2) - 
       (4*Lambda5*FCGV["MW"]^2*S2B*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[4], S[3]] == 
  {{(((-3*I)/4)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[4], S[4]] == 
  {{(((-3*I)/4)*FCGV["EL"]^2*(CBA^2*MHH^2 + Mh0^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(MHH^2*(-(CBA*S2B) + 2*SAB)^2 + Mh0^2*(2*CAB - S2B*SBA)^2 - 
       (8*C2B^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[-S[6], S[5], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[5], S[6], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[6], S[6], S[3], S[3]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA*MHH^2*(-(CBA*S2B) + 2*SAB) + 
       Mh0^2*SBA*(2*CAB - S2B*SBA) + S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/
          FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[5], S[5], S[3], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[S[5], -S[6], S[3], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA^2*Mh0^2 - MHp^2 + MHH^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[3], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA^2*Mh0^2 - MHp^2 + MHH^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], -S[6], S[3], S[4]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], S[4], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA*MHH^2*(-(CBA*S2B) + 2*SAB) + 
       Mh0^2*SBA*(2*CAB - S2B*SBA) + S2B*(2*MHp^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/
          FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[6], S[5], S[4], S[4]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[6], S[4], S[4]] == 
  {{((-I/4)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[6], S[6], S[4], S[4]] == 
  {{((-I/4)*FCGV["EL"]^2*(CBA^2*MHH^2 + Mh0^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], S[5], -S[5], S[5]] == 
  {{((-I/2)*FCGV["EL"]^2*(MHH^2*(-(CBA*S2B) + 2*SAB)^2 + Mh0^2*(2*CAB - S2B*SBA)^2 - 
       (8*C2B^2*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/(FCGV["MW"]^2*S2B^2*FCGV["SW"]^2)}}, 
 C[S[5], S[5], -S[6], -S[5]] == 
  {{((-I/2)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[S[5], S[5], -S[6], -S[6]] == 
  {{((-I/2)*FCGV["EL"]^2*(-MA0^2 + CBA^2*Mh0^2 + MHH^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], -S[5], S[6], -S[5]] == 
  {{((-I/2)*FCGV["EL"]^2*(-(MHH^2*(-(CBA*S2B) + 2*SAB)*SBA) + 
       CBA*Mh0^2*(2*CAB - S2B*SBA) - (4*C2B*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2))/
     (FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, C[-S[5], -S[6], S[6], S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(Mh0^2*(-S2A + 2*CBA^2*S2B) + MHH^2*(S2A + 2*S2B*SBA^2) + 
       S2B*(MA0^2 - (4*Lambda5*FCGV["MW"]^2*FCGV["SW"]^2)/FCGV["EL"]^2)))/(FCGV["MW"]^2*S2B*FCGV["SW"]^2)}}, 
 C[-S[6], -S[6], S[6], S[5]] == 
  {{((-I/2)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[5], -S[5], S[6], S[6]] == 
  {{((-I/2)*FCGV["EL"]^2*(-MA0^2 + CBA^2*Mh0^2 + MHH^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], S[6], -S[6], -S[5]] == 
  {{((-I/2)*CBA*FCGV["EL"]^2*(Mh0^2 - MHH^2)*SBA)/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[-S[6], S[6], -S[6], S[6]] == 
  {{((-I/2)*FCGV["EL"]^2*(CBA^2*MHH^2 + Mh0^2*SBA^2))/(FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[5], V[1], -V[3]] == {{((I/2)*CBA*FCGV["EL"]^2)/FCGV["SW"]}}, 
 C[S[1], S[5], V[2], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[1], S[6], V[1], -V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["SW"]}}, 
 C[S[1], S[6], V[2], -V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[1], -S[5], V[1], V[3]] == {{((I/2)*CBA*FCGV["EL"]^2)/FCGV["SW"]}}, 
 C[S[1], -S[5], V[2], V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[1], -S[6], V[1], V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["SW"]}}, 
 C[S[1], -S[6], V[2], V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], S[2], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[2], S[5], V[1], -V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["SW"]}}, 
 C[S[2], S[5], V[2], -V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], S[6], V[1], -V[3]] == {{((I/2)*CBA*FCGV["EL"]^2)/FCGV["SW"]}}, 
 C[S[2], S[6], V[2], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[2], -S[5], V[1], V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["SW"]}}, 
 C[S[2], -S[5], V[2], V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], -S[6], V[1], V[3]] == {{((I/2)*CBA*FCGV["EL"]^2)/FCGV["SW"]}}, 
 C[S[2], -S[6], V[2], V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[3], S[3], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[3], S[5], V[1], -V[3]] == {{-FCGV["EL"]^2/(2*FCGV["SW"])}}, 
 C[S[3], S[5], V[2], -V[3]] == {{FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[3], -S[5], V[1], V[3]] == {{FCGV["EL"]^2/(2*FCGV["SW"])}}, 
 C[S[3], -S[5], V[2], V[3]] == {{-FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[4], S[6], V[1], -V[3]] == {{-FCGV["EL"]^2/(2*FCGV["SW"])}}, 
 C[S[4], S[6], V[2], -V[3]] == {{FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[4], -S[6], V[1], V[3]] == {{FCGV["EL"]^2/(2*FCGV["SW"])}}, 
 C[S[4], -S[6], V[2], V[3]] == {{-FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[5], -S[5], V[1], V[1]] == {{(2*I)*FCGV["EL"]^2}}, 
 C[S[5], -S[5], V[1], V[2]] == {{(I*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[5], -S[5], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], -S[5], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[F[2, {j1}], -F[2, {j2}], S[1]] == 
  {{((-I/2)*FCGV["EL"]*Yuk1*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(FCGV["MW"]*FCGV["SW"])}, 
   {((-I/2)*FCGV["EL"]*Yuk1*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[1]] == 
  {{((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (FCGV["MW"]*SB*FCGV["SW"])}, {((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[1]] == 
  {{((-I/2)*FCGV["EL"]*Yuk1*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(FCGV["MW"]*FCGV["SW"])}, 
   {((-I/2)*FCGV["EL"]*Yuk1*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(FCGV["MW"]*FCGV["SW"])}}, C[F[2, {j1}], -F[2, {j2}], S[4]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}, 
   {(FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[4]] == 
  {{(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"])}, {-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
       Mass[F[3, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[4]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"])}, {(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, C[-F[2, {j2}], F[2, {j1}], V[1]] == 
  {{I*FCGV["EL"]*IndexDelta[j1, j2]}, {I*FCGV["EL"]*IndexDelta[j1, j2]}}, 
 C[-F[3, {j2, o1}], F[3, {j1, o2}], V[1]] == 
  {{((-2*I)/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]}, 
   {((-2*I)/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]}}, 
 C[-F[4, {j2, o1}], F[4, {j1, o2}], V[1]] == 
  {{(I/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]}, 
   {(I/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]}}, 
 C[-F[1, {j2}], F[1, {j1}], V[2]] == 
  {{((-I/2)*FCGV["EL"]*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}, {0}}, 
 C[-F[2, {j2}], F[2, {j1}], V[2]] == 
  {{((-I)*FCGV["EL"]*(-1/2 + FCGV["SW"]^2)*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}, 
   {((-I)*FCGV["EL"]*FCGV["SW"]*IndexDelta[j1, j2])/FCGV["CW"]}}, 
 C[-F[3, {j2, o1}], F[3, {j1, o2}], V[2]] == 
  {{((I/6)*FCGV["EL"]*(-3 + 4*FCGV["SW"]^2)*IndexDelta[j1, j2]*IndexDelta[o1, o2])/(FCGV["CW"]*FCGV["SW"])}, 
   {(((2*I)/3)*FCGV["EL"]*FCGV["SW"]*IndexDelta[j1, j2]*IndexDelta[o1, o2])/FCGV["CW"]}}, 
 C[-F[4, {j2, o1}], F[4, {j1, o2}], V[2]] == 
  {{((-I/6)*FCGV["EL"]*(-3 + 2*FCGV["SW"]^2)*IndexDelta[j1, j2]*IndexDelta[o1, o2])/(FCGV["CW"]*FCGV["SW"])}, 
   {((-I/3)*FCGV["EL"]*FCGV["SW"]*IndexDelta[j1, j2]*IndexDelta[o1, o2])/FCGV["CW"]}}, 
 C[F[2, {j1}], -F[2, {j2}], S[2]] == 
  {{((-I/2)*FCGV["EL"]*Yuk2*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(FCGV["MW"]*FCGV["SW"])}, 
   {((-I/2)*FCGV["EL"]*Yuk2*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[2]] == 
  {{((-I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (FCGV["MW"]*SB*FCGV["SW"])}, {((-I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[2]] == 
  {{((-I/2)*FCGV["EL"]*Yuk2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(FCGV["MW"]*FCGV["SW"])}, 
   {((-I/2)*FCGV["EL"]*Yuk2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(FCGV["MW"]*FCGV["SW"])}}, C[F[2, {j1}], -F[2, {j2}], S[3]] == 
  {{(FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}, 
   {-(FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[3]] == 
  {{(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"]*TB)}, {-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
       Mass[F[3, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[3]] == 
  {{(FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"])}, {-(FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
       Mass[F[4, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, C[F[1, {j1}], -F[2, {j2}], S[6]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j2}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {0}}, 
 C[F[2, {j1}], -F[1, {j2}], -S[6]] == 
  {{0}, {((-I)*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-F[2, {j2}], F[1, {j1}], V[3]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[-F[1, {j2}], F[2, {j1}], -V[3]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[F[1, {j1}], -F[2, {j2}], S[5]] == 
  {{(I*FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*Mass[F[2, {j2}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {0}}, 
 C[F[2, {j1}], -F[1, {j2}], -S[5]] == 
  {{0}, {(I*FCGV["EL"]*Yuk3*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[4, {j2, o2}], S[6]] == 
  {{((-I)*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*Mass[F[4, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {(I*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[3, {j2, o2}], -S[6]] == 
  {{(I*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*Mass[F[3, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {((-I)*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-F[4, {j2, o1}], F[3, {j1, o2}], V[3]] == 
  {{((-I)*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[-F[3, {j2, o1}], F[4, {j1, o2}], -V[3]] == 
  {{((-I)*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[F[3, {j1, o1}], -F[4, {j2, o2}], S[5]] == 
  {{(I*FCGV["EL"]*Yuk3*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      Mass[F[4, {j2, o2}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, 
   {(I*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, C[F[4, {j1, o1}], -F[3, {j2, o2}], -S[5]] == 
  {{(I*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*Mass[F[3, {j2, o2}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}, {(I*FCGV["EL"]*Yuk3*CKM[j2, j1]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}}

