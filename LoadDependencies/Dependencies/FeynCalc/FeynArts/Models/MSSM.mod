(* Patched for use with FeynCalc *)
(*
	MSSM.mod
		Classes model file for the MSSM
		by Thomas Hahn
		based on the Feynman rules of the MSSM by Arnd Kraft
		last modified 30 Apr 14 th

This file contains the definition of the minimal supersymmetric standard
model for FeynArts.  It needs the Generic model file Lorentz.gen.

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

	MSf:		sfermion mass

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

	ZNeu:		neutralino mixing matrix (4x4)
	UCha, VCha:	chargino mixing matrices (2x2)
	USf[t]:		t-type sfermion 1-2 mixing matrices (2x2)

	Af[t, i]:	soft breaking parameters
	MUE:		the H1-H2 mixing parameter
*)


(* $HKSign is the sign in the SU(2) covariant derivative,
   i.e. D_\mu = \partial_\mu + $HKSign I g A^a_\mu \tau^a,
   so 1 = Haber-Kane, -1 = Denner conventions *)

If[ !ValueQ[$HKSign], $HKSign = 1 ]

IndexRange[ Index[Generation] ] = Range[3];
IndexRange[ Index[Colour] ] = NoUnfold[Range[3]];
IndexRange[ Index[Sfermion] ] = Range[2];
IndexRange[ Index[Chargino] ] = Range[2];
IndexRange[ Index[Neutralino] ] = Range[4]

IndexStyle[ Index[Generation | Chargino | Neutralino, i_Integer] ] :=
  Alph[i + 8] 

IndexStyle[ Index[Sfermion, i_Integer] ] := Alph[i + 18]

M$ClassesDescription = {

	(* Neutrinos: I_3 = +1/2, Q = 0 *)
  F[1] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation]},
	Mass -> 0,
	QuantumNumbers -> {0 Charge, LeptonNumber},
	PropagatorLabel -> ComposedChar["\\nu", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* massive Leptons: I_3 = -1/2, Q = -1 *)
  F[2] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation]},
	Mass -> MLE,
	QuantumNumbers -> {-1 Charge, LeptonNumber},
	PropagatorLabel -> ComposedChar["e", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* Quarks (u): I_3 = +1/2, Q = +2/3 *)
  F[3] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation], Index[Colour]},
	Mass -> MQU,
	QuantumNumbers -> {2/3 Charge, Sqrt[4/3] ColorCharge},
	PropagatorLabel -> ComposedChar["u", Index[Generation]],
	PropagatorType -> Straight,
	PropagatorArrow -> Forward },

	(* Quarks (d): I_3 = -1/2, Q = -1/3 *)
  F[4] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation], Index[Colour]},
	Mass -> MQD,
	QuantumNumbers -> {-1/3 Charge, Sqrt[4/3] ColorCharge},
	PropagatorLabel -> ComposedChar["d", Index[Generation]],
	PropagatorType -> Straight, 
	PropagatorArrow -> Forward },

	(* Neutralinos *)
  F[11] == {
	SelfConjugate -> True,
	Indices -> {Index[Neutralino]},
	Mass -> MNeu,
	PropagatorLabel ->
	  ComposedChar["\\chi", Index[Neutralino], "0", "\\tilde"],
	PropagatorType -> Straight,
	PropagatorArrow -> None },

	(* Charginos *)
  F[12] == {
	SelfConjugate -> False,
	Indices -> {Index[Chargino]},
	Mass -> MCha,
	QuantumNumbers -> {-1 Charge},
	PropagatorLabel ->
	  ComposedChar["\\chi", Index[Chargino], Null, "\\tilde"],
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
	QuantumNumbers -> {-1 Charge},
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
	QuantumNumbers -> {-1 Charge},
	PropagatorLabel -> "H",
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

  S[6] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	QuantumNumbers -> {-1 Charge},
	PropagatorLabel -> "G",
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Sneutrinos: Q = 0 *)
  S[11] == {
	SelfConjugate -> False,
	Indices -> {Index[Generation]},
	QuantumNumbers -> {0 Charge, LeptonNumber},
	PropagatorLabel ->
	  ComposedChar["\\nu", Index[Generation], Null, "\\tilde"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Sleptons: Q = -1 *)
  S[12] == {
	SelfConjugate -> False,
	Indices -> {Index[Sfermion], Index[Generation]},
	QuantumNumbers -> {-1 Charge, LeptonNumber},
	PropagatorLabel ->
	  ComposedChar["e", Index[Generation], Index[Sfermion], "\\tilde"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Squarks (u): Q = +2/3 *)
  S[13] == {
	SelfConjugate -> False,
	Indices -> {Index[Sfermion], Index[Generation], Index[Colour]},
	QuantumNumbers -> {2/3 Charge, Sqrt[4/3] ColorCharge},
	PropagatorLabel ->
	  ComposedChar["u", Index[Generation], Index[Sfermion], "\\tilde"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Squarks (d): Q = -1/3 *)
  S[14] == {
	SelfConjugate -> False,
	Indices -> {Index[Sfermion], Index[Generation], Index[Colour]},
	QuantumNumbers -> {-1/3 Charge, Sqrt[4/3] ColorCharge},
	PropagatorLabel ->
	  ComposedChar["d", Index[Generation], Index[Sfermion], "\\tilde"],
	PropagatorType -> ScalarDash,
	PropagatorArrow -> Forward },

	(* Ghosts: Q = 0 *)
  U[1] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> 0,
	QuantumNumbers -> GhostNumber,
	PropagatorLabel -> ComposedChar["u", "\\gamma"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

  U[2] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MZ"],
	QuantumNumbers -> GhostNumber,
	PropagatorLabel -> ComposedChar["u", "Z"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

	(* Ghosts: Q = -1 *)
  U[3] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	QuantumNumbers -> {-1 Charge, GhostNumber},
	PropagatorLabel -> ComposedChar["u", "-"],
	PropagatorType -> GhostDash,
	PropagatorArrow -> Forward },

  U[4] == {
	SelfConjugate -> False,
	Indices -> {},
	Mass -> FCGV["MW"],
	QuantumNumbers -> {1 Charge, GhostNumber},
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

TheMass[ S[11, {gen_, ___}] ] = MSf[1, 1, gen];
TheMass[ S[typ:12 | 13 | 14, {sf_, gen_, ___}] ] := MSf[sf, typ - 10, gen]

TheLabel[ S[11, {1}] ] = ComposedChar["\\nu", "e", Null, "\\tilde"];
TheLabel[ S[11, {2}] ] = ComposedChar["\\nu", "\\mu", Null, "\\tilde"];
TheLabel[ S[11, {3}] ] = ComposedChar["\\nu", "\\tau", Null, "\\tilde"];
TheLabel[ S[12, {sf_, 1}] ] :=
  ComposedChar["e", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[12, {sf_, 2}] ] :=
  ComposedChar["\\mu", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[12, {sf_, 3}] ] :=
  ComposedChar["\\tau", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[13, {sf_, 1, ___}] ] :=
  ComposedChar["u", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[13, {sf_, 2, ___}] ] :=
  ComposedChar["c", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[13, {sf_, 3, ___}] ] :=
  ComposedChar["t", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[14, {sf_, 1, ___}] ] :=
  ComposedChar["d", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[14, {sf_, 2, ___}] ] :=
  ComposedChar["s", Null, IndexStyle[sf], "\\tilde"];
TheLabel[ S[14, {sf_, 3, ___}] ] :=
  ComposedChar["b", Null, IndexStyle[sf], "\\tilde"]

FAGaugeXi[ V[1] ] = FAGaugeXi[A];
FAGaugeXi[ V[2] ] = FAGaugeXi[Z];
FAGaugeXi[ V[3] ] = FAGaugeXi[W];
FAGaugeXi[ U[1] ] = FAGaugeXi[A];
FAGaugeXi[ U[2] ] = FAGaugeXi[Z];
FAGaugeXi[ U[3] ] = FAGaugeXi[W];
FAGaugeXi[ U[4] ] = FAGaugeXi[W];
FAGaugeXi[ S[4] ] = FAGaugeXi[Z];
FAGaugeXi[ S[6] ] = FAGaugeXi[W];
FAGaugeXi[ S[_Integer, ___] ] = 1

M$LastModelRules = {}


(* some short-hands for excluding classes of particles *)

NoGeneration1 = ExcludeParticles ->
  {F[1|2|3|4, {1, ___}], S[11, {1, ___}], S[12|13|14, {_, 1, ___}]}

NoGeneration2 = ExcludeParticles ->
  {F[1|2|3|4, {2, ___}], S[11, {2, ___}], S[12|13|14, {_, 2, ___}]}

NoGeneration3 = ExcludeParticles ->
  {F[1|2|3|4, {3, ___}], S[11, {3, ___}], S[12|13|14, {_, 3, ___}]}

NoSUSYParticles = ExcludeParticles ->
  {S[11], S[12], S[13], S[14], S[2], S[3], S[5], F[11], F[12]}

THDMParticles = ExcludeParticles ->
  {S[11], S[12], S[13], S[14], F[11], F[12]}

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
  {{((I/2)*FCGV["EL"]*(FCGV["CW"]^2 - FCGV["SW"]^2)*$HKSign)/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[4], S[6], -V[3]] == {{(FCGV["EL"]*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[4], -S[6], V[3]] == {{(FCGV["EL"]*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[6], V[1], -V[3]] == {{I*FCGV["EL"]*FCGV["MW"]*$HKSign}}, 
 C[-S[6], V[1], V[3]] == {{I*FCGV["EL"]*FCGV["MW"]*$HKSign}}, 
 C[S[6], V[2], -V[3]] == {{((-I)*FCGV["EL"]*FCGV["MW"]*FCGV["SW"])/FCGV["CW"]}}, 
 C[-S[6], V[2], V[3]] == {{((-I)*FCGV["EL"]*FCGV["MW"]*FCGV["SW"])/FCGV["CW"]}}, 
 C[V[1], -V[3], V[3]] == {{(-I)*FCGV["EL"]}}, C[V[2], -V[3], V[3]] == 
  {{((-I)*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}}, C[S[4], U[3], -U[3]] == 
  {{-(FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/(2*FCGV["SW"])}}, C[S[4], U[4], -U[4]] == 
  {{(FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/(2*FCGV["SW"])}}, C[S[6], U[1], -U[3]] == 
  {{(-I)*FCGV["EL"]*FCGV["MW"]*$HKSign*FAGaugeXi[W]}}, C[-S[6], U[1], -U[4]] == 
  {{(-I)*FCGV["EL"]*FCGV["MW"]*$HKSign*FAGaugeXi[W]}}, C[S[6], U[2], -U[3]] == 
  {{((I/2)*FCGV["EL"]*FCGV["MW"]*(-FCGV["CW"]^2 + FCGV["SW"]^2)*FAGaugeXi[W])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-S[6], U[2], -U[4]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*(-FCGV["CW"]^2 + FCGV["SW"]^2)*FAGaugeXi[W])/
     (FCGV["CW"]*FCGV["SW"])}}, C[S[6], U[4], -U[2]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-S[6], U[3], -U[2]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[-U[3], U[3], V[1]] == {{(-I)*FCGV["EL"]}, {0}}, C[-U[4], U[4], V[1]] == 
  {{I*FCGV["EL"]}, {0}}, C[-U[3], U[3], V[2]] == {{((-I)*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, 
 C[-U[4], U[4], V[2]] == {{(I*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, 
 C[-U[3], U[1], V[3]] == {{I*FCGV["EL"]}, {0}}, C[-U[4], U[1], -V[3]] == 
  {{(-I)*FCGV["EL"]}, {0}}, C[-U[1], U[4], V[3]] == {{(-I)*FCGV["EL"]}, {0}}, 
 C[-U[1], U[3], -V[3]] == {{I*FCGV["EL"]}, {0}}, C[-U[3], U[2], V[3]] == 
  {{(I*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, C[-U[4], U[2], -V[3]] == 
  {{((-I)*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, C[-U[2], U[4], V[3]] == 
  {{((-I)*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, C[-U[2], U[3], -V[3]] == 
  {{(I*FCGV["CW"]*FCGV["EL"]*$HKSign)/FCGV["SW"]}, {0}}, C[S[1], S[1], V[2], V[2]] == 
  {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, C[S[1], S[1], V[3], -V[3]] == 
  {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, C[S[4], S[4], V[2], V[2]] == 
  {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, C[S[4], S[4], V[3], -V[3]] == 
  {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, C[S[6], -S[6], V[1], V[1]] == {{(2*I)*FCGV["EL"]^2}}, 
 C[S[6], -S[6], V[1], V[2]] == {{(I*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)*$HKSign)/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[6], -S[6], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], -S[6], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[V[1], V[1], V[3], -V[3]] == {{(-2*I)*FCGV["EL"]^2}, {I*FCGV["EL"]^2}, {I*FCGV["EL"]^2}}, 
 C[V[1], V[2], V[3], -V[3]] == {{((-2*I)*FCGV["CW"]*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}, 
   {(I*FCGV["CW"]*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}, {(I*FCGV["CW"]*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}}, 
 C[V[2], V[2], V[3], -V[3]] == {{((-2*I)*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}, 
   {(I*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}, {(I*FCGV["CW"]^2*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[V[3], V[3], -V[3], -V[3]] == {{((2*I)*FCGV["EL"]^2)/FCGV["SW"]^2}, {((-I)*FCGV["EL"]^2)/FCGV["SW"]^2}, 
   {((-I)*FCGV["EL"]^2)/FCGV["SW"]^2}}, C[S[1], S[1], S[1]] == 
  {{(((-3*I)/2)*C2A*FCGV["EL"]*FCGV["MW"]*SAB)/(FCGV["CW"]^2*FCGV["SW"])}}, C[S[1], S[1], S[2]] == 
  {{((I/2)*FCGV["EL"]*FCGV["MW"]*(C2A*CAB - 2*S2A*SAB))/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], S[2], S[2]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*(2*CAB*S2A + C2A*SAB))/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], S[2], S[2]] == {{(((-3*I)/2)*C2A*CAB*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], S[3], S[3]] == {{((-I/2)*C2B*FCGV["EL"]*FCGV["MW"]*SAB)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], S[3], S[4]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*S2B*SAB)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], S[4], S[4]] == {{((I/2)*C2B*FCGV["EL"]*FCGV["MW"]*SAB)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], S[3], S[3]] == {{((I/2)*C2B*CAB*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], S[3], S[4]] == {{((I/2)*CAB*FCGV["EL"]*FCGV["MW"]*S2B)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], S[4], S[4]] == {{((-I/2)*C2B*CAB*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], S[5], -S[5]] == {{((-I)*FCGV["EL"]*FCGV["MW"]*((C2B*SAB)/(2*FCGV["CW"]^2) + SBA))/FCGV["SW"]}}, 
 C[S[1], S[5], -S[6]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*(CBA - (S2B*SAB)/FCGV["CW"]^2))/FCGV["SW"]}}, 
 C[S[1], S[6], -S[5]] == {{((I/2)*FCGV["EL"]*FCGV["MW"]*(CBA - (S2B*SAB)/FCGV["CW"]^2))/FCGV["SW"]}}, 
 C[S[1], S[6], -S[6]] == {{((I/2)*C2B*FCGV["EL"]*FCGV["MW"]*SAB)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], S[5], -S[5]] == {{((-I)*(CBA - (C2B*CAB)/(2*FCGV["CW"]^2))*FCGV["EL"]*FCGV["MW"])/FCGV["SW"]}}, 
 C[S[2], S[5], -S[6]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*(-((CAB*S2B)/FCGV["CW"]^2) + SBA))/FCGV["SW"]}}, 
 C[S[2], S[6], -S[5]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*(-((CAB*S2B)/FCGV["CW"]^2) + SBA))/FCGV["SW"]}}, 
 C[S[2], S[6], -S[6]] == {{((-I/2)*C2B*CAB*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[3], S[5], -S[6]] == {{-(FCGV["EL"]*FCGV["MW"])/(2*FCGV["SW"])}}, 
 C[S[3], S[6], -S[5]] == {{(FCGV["EL"]*FCGV["MW"])/(2*FCGV["SW"])}}, 
 C[S[1], S[3], V[2]] == {{(CBA*FCGV["EL"]*$HKSign)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[1], S[4], V[2]] == {{(FCGV["EL"]*SBA*$HKSign)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[2], S[3], V[2]] == {{-(FCGV["EL"]*SBA*$HKSign)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[2], S[4], V[2]] == {{(CBA*FCGV["EL"]*$HKSign)/(2*FCGV["CW"]*FCGV["SW"])}}, 
 C[S[5], -S[5], V[1]] == {{I*FCGV["EL"]}}, C[S[5], -S[5], V[2]] == 
  {{((I/2)*FCGV["EL"]*(FCGV["CW"]^2 - FCGV["SW"]^2)*$HKSign)/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[1], S[5], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]*$HKSign)/FCGV["SW"]}}, 
 C[S[1], S[6], -V[3]] == {{((-I/2)*FCGV["EL"]*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], S[5], -V[3]] == {{((I/2)*FCGV["EL"]*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], S[6], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]*$HKSign)/FCGV["SW"]}}, 
 C[S[1], -S[5], V[3]] == {{((I/2)*CBA*FCGV["EL"]*$HKSign)/FCGV["SW"]}}, 
 C[S[1], -S[6], V[3]] == {{((I/2)*FCGV["EL"]*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], -S[5], V[3]] == {{((-I/2)*FCGV["EL"]*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], -S[6], V[3]] == {{((I/2)*CBA*FCGV["EL"]*$HKSign)/FCGV["SW"]}}, 
 C[S[3], S[5], -V[3]] == {{(FCGV["EL"]*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[3], -S[5], V[3]] == {{(FCGV["EL"]*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[1], V[2], V[2]] == {{(I*FCGV["EL"]*FCGV["MW"]*SBA)/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], V[2], V[2]] == {{(I*CBA*FCGV["EL"]*FCGV["MW"])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], V[3], -V[3]] == {{(I*FCGV["EL"]*FCGV["MW"]*SBA)/FCGV["SW"]}}, 
 C[S[2], V[3], -V[3]] == {{(I*CBA*FCGV["EL"]*FCGV["MW"])/FCGV["SW"]}}, 
 C[S[1], U[2], -U[2]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[Z])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[2], U[2], -U[2]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[Z])/(FCGV["CW"]^2*FCGV["SW"])}}, 
 C[S[1], U[3], -U[3]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[2], U[3], -U[3]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[1], U[4], -U[4]] == {{((-I/2)*FCGV["EL"]*FCGV["MW"]*SBA*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[2], U[4], -U[4]] == {{((-I/2)*CBA*FCGV["EL"]*FCGV["MW"]*FAGaugeXi[W])/FCGV["SW"]}}, 
 C[S[1], S[1], S[1], S[1]] == {{(((-3*I)/4)*C2A^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[1], S[2]] == {{(((-3*I)/4)*C2A*FCGV["EL"]^2*S2A)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[2], S[2]] == {{((-I/4)*FCGV["EL"]^2*(-1 + 3*S2A^2))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[2], S[2]] == {{(((3*I)/4)*C2A*FCGV["EL"]^2*S2A)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[2], S[2]] == {{(((-3*I)/4)*C2A^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[3], S[3]] == {{((-I/4)*C2A*C2B*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[3], S[4]] == {{((-I/4)*C2A*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[4], S[4]] == {{((I/4)*C2A*C2B*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[3], S[3]] == {{((-I/4)*C2B*FCGV["EL"]^2*S2A)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[3], S[4]] == {{((-I/4)*FCGV["EL"]^2*S2A*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[4], S[4]] == {{((I/4)*C2B*FCGV["EL"]^2*S2A)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[3], S[3]] == {{((I/4)*C2A*C2B*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[3], S[4]] == {{((I/4)*C2A*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[4], S[4]] == {{((-I/4)*C2A*C2B*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[5], -S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 - S2A*S2B + (C2A*C2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[1], S[5], -S[6]] == 
  {{((-I/4)*FCGV["EL"]^2*(C2B*S2A + (C2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[1], S[6], -S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(C2B*S2A + (C2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[1], S[6], -S[6]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 + S2A*S2B - (C2A*C2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[2], S[5], -S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(C2A*S2B + (C2B*S2A*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[2], S[5], -S[6]] == 
  {{((I/4)*FCGV["EL"]^2*(C2A*C2B - (S2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[2], S[6], -S[5]] == 
  {{((I/4)*FCGV["EL"]^2*(C2A*C2B - (S2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[2], S[6], -S[6]] == 
  {{((I/4)*FCGV["EL"]^2*(C2A*S2B + (C2B*S2A*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[2], S[2], S[5], -S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 + S2A*S2B - (C2A*C2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[2], S[2], S[5], -S[6]] == 
  {{((I/4)*FCGV["EL"]^2*(C2B*S2A + (C2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[2], S[2], S[6], -S[5]] == 
  {{((I/4)*FCGV["EL"]^2*(C2B*S2A + (C2A*S2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[2], S[2], S[6], -S[6]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 - S2A*S2B + (C2A*C2B*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[1], S[3], S[5], -S[6]] == {{-(FCGV["EL"]^2*SBA)/(4*FCGV["SW"]^2)}}, 
 C[S[1], S[3], S[6], -S[5]] == {{(FCGV["EL"]^2*SBA)/(4*FCGV["SW"]^2)}}, 
 C[S[1], S[4], S[5], -S[6]] == {{(CBA*FCGV["EL"]^2)/(4*FCGV["SW"]^2)}}, 
 C[S[1], S[4], S[6], -S[5]] == {{-(CBA*FCGV["EL"]^2)/(4*FCGV["SW"]^2)}}, 
 C[S[2], S[3], S[5], -S[6]] == {{-(CBA*FCGV["EL"]^2)/(4*FCGV["SW"]^2)}}, 
 C[S[2], S[3], S[6], -S[5]] == {{(CBA*FCGV["EL"]^2)/(4*FCGV["SW"]^2)}}, 
 C[S[2], S[4], S[5], -S[6]] == {{-(FCGV["EL"]^2*SBA)/(4*FCGV["SW"]^2)}}, 
 C[S[2], S[4], S[6], -S[5]] == {{(FCGV["EL"]^2*SBA)/(4*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[3], S[3]] == {{(((-3*I)/4)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[3], S[4]] == {{(((-3*I)/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[4], S[4]] == {{((-I/4)*FCGV["EL"]^2*(-1 + 3*S2B^2))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[4], S[4], S[4]] == {{(((3*I)/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[4], S[4]] == {{(((-3*I)/4)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[5], -S[5]] == {{((-I/4)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[5], -S[6]] == {{((-I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[6], -S[5]] == {{((-I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[6], -S[6]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 + S2B^2 - (C2B^2*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[3], S[4], S[5], -S[5]] == {{((-I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[4], S[5], -S[6]] == 
  {{((I/4)*FCGV["EL"]^2*(C2B^2 - (S2B^2*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[3], S[4], S[6], -S[5]] == 
  {{((I/4)*FCGV["EL"]^2*(C2B^2 - (S2B^2*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[3], S[4], S[6], -S[6]] == {{((I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[5], -S[5]] == 
  {{((-I/4)*FCGV["EL"]^2*(1 + S2B^2 - (C2B^2*FCGV["SW"]^2)/FCGV["CW"]^2))/FCGV["SW"]^2}}, 
 C[S[4], S[4], S[5], -S[6]] == {{((I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[6], -S[5]] == {{((I/4)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[6], -S[6]] == {{((-I/4)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[5], -S[5], -S[5]] == {{((-I/2)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[5], -S[5], -S[6]] == {{((-I/2)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[5], -S[6], -S[6]] == {{((-I/2)*FCGV["EL"]^2*S2B^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[6], -S[5], -S[5]] == {{((-I/2)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[6], -S[5], -S[6]] == {{((I/4)*FCGV["EL"]^2*(C2B^2 - S2B^2))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], S[6], -S[6], -S[6]] == {{((I/2)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], S[6], -S[5], -S[5]] == {{((-I/2)*FCGV["EL"]^2*S2B^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], S[6], -S[5], -S[6]] == {{((I/2)*C2B*FCGV["EL"]^2*S2B)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], S[6], -S[6], -S[6]] == {{((-I/2)*C2B^2*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[5], V[1], -V[3]] == {{((I/2)*CBA*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}}, 
 C[S[1], S[5], V[2], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[1], S[6], V[1], -V[3]] == {{((I/2)*FCGV["EL"]^2*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[1], S[6], V[2], -V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[1], -S[5], V[1], V[3]] == {{((I/2)*CBA*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}}, 
 C[S[1], -S[5], V[2], V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[1], -S[6], V[1], V[3]] == {{((I/2)*FCGV["EL"]^2*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[1], -S[6], V[2], V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], S[2], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[2], S[5], V[1], -V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], S[5], V[2], -V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], S[6], V[1], -V[3]] == {{((I/2)*CBA*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}}, 
 C[S[2], S[6], V[2], -V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[2], -S[5], V[1], V[3]] == {{((-I/2)*FCGV["EL"]^2*SBA*$HKSign)/FCGV["SW"]}}, 
 C[S[2], -S[5], V[2], V[3]] == {{((I/2)*FCGV["EL"]^2*SBA)/FCGV["CW"]}}, 
 C[S[2], -S[6], V[1], V[3]] == {{((I/2)*CBA*FCGV["EL"]^2*$HKSign)/FCGV["SW"]}}, 
 C[S[2], -S[6], V[2], V[3]] == {{((-I/2)*CBA*FCGV["EL"]^2)/FCGV["CW"]}}, 
 C[S[3], S[3], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[S[3], S[5], V[1], -V[3]] == {{-(FCGV["EL"]^2*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[3], S[5], V[2], -V[3]] == {{FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[3], -S[5], V[1], V[3]] == {{(FCGV["EL"]^2*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[3], -S[5], V[2], V[3]] == {{-FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[4], S[6], V[1], -V[3]] == {{-(FCGV["EL"]^2*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[4], S[6], V[2], -V[3]] == {{FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[4], -S[6], V[1], V[3]] == {{(FCGV["EL"]^2*$HKSign)/(2*FCGV["SW"])}}, 
 C[S[4], -S[6], V[2], V[3]] == {{-FCGV["EL"]^2/(2*FCGV["CW"])}}, 
 C[S[5], -S[5], V[1], V[1]] == {{(2*I)*FCGV["EL"]^2}}, 
 C[S[5], -S[5], V[1], V[2]] == {{(I*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)*$HKSign)/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[5], -S[5], V[2], V[2]] == {{((I/2)*FCGV["EL"]^2*(FCGV["CW"]^2 - FCGV["SW"]^2)^2)/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[5], -S[5], V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2)/FCGV["SW"]^2}}, 
 C[F[2, {j1}], -F[2, {j2}], S[1]] == 
  {{((I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(CB*FCGV["MW"]*FCGV["SW"])}, 
   {((I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(CB*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[1]] == 
  {{((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (FCGV["MW"]*SB*FCGV["SW"])}, {((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[1]] == 
  {{((I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1, o1}]])/
     (CB*FCGV["MW"]*FCGV["SW"])}, {((I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(CB*FCGV["MW"]*FCGV["SW"])}}, C[F[2, {j1}], -F[2, {j2}], S[4]] == 
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
  {{((-I/2)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}, {0}}, 
 C[-F[2, {j2}], F[2, {j1}], V[2]] == 
  {{((-I)*FCGV["EL"]*(-1/2 + FCGV["SW"]^2)*$HKSign*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}, 
   {((-I)*FCGV["EL"]*FCGV["SW"]*$HKSign*IndexDelta[j1, j2])/FCGV["CW"]}}, 
 C[-F[3, {j2, o1}], F[3, {j1, o2}], V[2]] == 
  {{((I/6)*FCGV["EL"]*(-3 + 4*FCGV["SW"]^2)*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2])/
     (FCGV["CW"]*FCGV["SW"])}, {(((2*I)/3)*FCGV["EL"]*FCGV["SW"]*$HKSign*IndexDelta[j1, j2]*
      IndexDelta[o1, o2])/FCGV["CW"]}}, C[-F[4, {j2, o1}], F[4, {j1, o2}], V[2]] == 
  {{((-I/6)*FCGV["EL"]*(-3 + 2*FCGV["SW"]^2)*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2])/
     (FCGV["CW"]*FCGV["SW"])}, {((-I/3)*FCGV["EL"]*FCGV["SW"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2])/
     FCGV["CW"]}}, C[F[2, {j1}], -F[2, {j2}], S[2]] == 
  {{((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(CB*FCGV["MW"]*FCGV["SW"])}, 
   {((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(CB*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[2]] == 
  {{((-I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (FCGV["MW"]*SB*FCGV["SW"])}, {((-I/2)*FCGV["EL"]*SA*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[2]] == 
  {{((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1, o1}]])/
     (CB*FCGV["MW"]*FCGV["SW"])}, {((-I/2)*CA*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(CB*FCGV["MW"]*FCGV["SW"])}}, C[F[2, {j1}], -F[2, {j2}], S[3]] == 
  {{(FCGV["EL"]*TB*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}, 
   {-(FCGV["EL"]*TB*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[3, {j2, o2}], S[3]] == 
  {{(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"]*TB)}, {-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
       Mass[F[3, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[F[4, {j1, o1}], -F[4, {j2, o2}], S[3]] == 
  {{(FCGV["EL"]*TB*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1, o1}]])/
     (2*FCGV["MW"]*FCGV["SW"])}, {-(FCGV["EL"]*TB*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
       Mass[F[4, {j1, o1}]])/(2*FCGV["MW"]*FCGV["SW"])}}, C[F[1, {j1}], -F[2, {j2}], S[6]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j2}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {0}}, 
 C[F[2, {j1}], -F[1, {j2}], -S[6]] == 
  {{0}, {((-I)*FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-F[2, {j2}], F[1, {j1}], V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[-F[1, {j2}], F[2, {j1}], -V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[F[1, {j1}], -F[2, {j2}], S[5]] == 
  {{(I*FCGV["EL"]*TB*IndexDelta[j1, j2]*Mass[F[2, {j2}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {0}}, 
 C[F[2, {j1}], -F[1, {j2}], -S[5]] == 
  {{0}, {(I*FCGV["EL"]*TB*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[3, {j1, o1}], -F[4, {j2, o2}], S[6]] == 
  {{((-I)*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*Mass[F[4, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {(I*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[4, {j1, o1}], -F[3, {j2, o2}], -S[6]] == 
  {{(I*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*Mass[F[3, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {((-I)*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-F[4, {j2, o1}], F[3, {j1, o2}], V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2])/
     (Sqrt[2]*FCGV["SW"])}, {0}}, C[-F[3, {j2, o1}], F[4, {j1, o2}], -V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*CKM[j2, j1]*IndexDelta[o1, o2])/(Sqrt[2]*FCGV["SW"])}, {0}}, 
 C[F[3, {j1, o1}], -F[4, {j2, o2}], S[5]] == 
  {{(I*FCGV["EL"]*TB*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*Mass[F[4, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}, {(I*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[F[4, {j1, o1}], -F[3, {j2, o2}], -S[5]] == 
  {{(I*FCGV["EL"]*CKM[j2, j1]*IndexDelta[o1, o2]*Mass[F[3, {j2, o1}]])/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}, {(I*FCGV["EL"]*TB*CKM[j2, j1]*IndexDelta[o1, o2]*
      Mass[F[4, {j1, o1}]])/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[3], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]]*
       ((MUE + TB*Conjugate[Af[2, j1, j1]])*Conjugate[USf[2, j1][s1, 2]]*
         USf[2, j1][s2, 1] - (TB*Af[2, j1, j1] + Conjugate[MUE])*
         Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[4], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*Mass[F[2, {j1}]]*
       ((MUE*TB - Conjugate[Af[2, j1, j1]])*Conjugate[USf[2, j1][s1, 2]]*
         USf[2, j1][s2, 1] + (Af[2, j1, j1] - TB*Conjugate[MUE])*
         Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[3], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1}]]*
       ((MUE*TB + Conjugate[Af[3, j1, j1]])*Conjugate[USf[3, j1][s1, 2]]*
         USf[3, j1][s2, 1] - (Af[3, j1, j1] + TB*Conjugate[MUE])*
         Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[S[4], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[3, {j1}]]*
      ((MUE - TB*Conjugate[Af[3, j1, j1]])*Conjugate[USf[3, j1][s1, 2]]*
        USf[3, j1][s2, 1] + (TB*Af[3, j1, j1] - Conjugate[MUE])*
        Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[S[3], S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1}]]*
       ((MUE + TB*Conjugate[Af[4, j1, j1]])*Conjugate[USf[4, j1][s1, 2]]*
         USf[4, j1][s2, 1] - (TB*Af[4, j1, j1] + Conjugate[MUE])*
         Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[4], S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{-(FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*Mass[F[4, {j1}]]*
       ((MUE*TB - Conjugate[Af[4, j1, j1]])*Conjugate[USf[4, j1][s1, 2]]*
         USf[4, j1][s2, 1] + (Af[4, j1, j1] - TB*Conjugate[MUE])*
         Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 2]))/(2*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[11, {j1}], -S[11, {j2}]] == 
  {{((I/2)*FCGV["EL"]*FCGV["MZ"]*SAB*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[2], S[11, {j1}], -S[11, {j2}]] == 
  {{((-I/2)*CAB*FCGV["EL"]*FCGV["MZ"]*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[1], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s1, 1]]*
        ((CB*FCGV["MW"]*FCGV["MZ"]*SAB*(-1 + 2*FCGV["SW"]^2) + 2*FCGV["CW"]*SA*Mass[F[2, {j1}]]^2)*
          USf[2, j1][s2, 1] + FCGV["CW"]*(SA*Af[2, j1, j1] + CA*Conjugate[MUE])*
          Mass[F[2, {j1}]]*USf[2, j1][s2, 2]) + Conjugate[USf[2, j1][s1, 2]]*
        (FCGV["CW"]*(CA*MUE + SA*Conjugate[Af[2, j1, j1]])*Mass[F[2, {j1}]]*
          USf[2, j1][s2, 1] - 2*CB*FCGV["MW"]*FCGV["MZ"]*SAB*FCGV["SW"]^2*USf[2, j1][s2, 2] + 
         2*FCGV["CW"]*SA*Mass[F[2, {j1}]]^2*USf[2, j1][s2, 2])))/(CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s1, 1]]*
        ((CAB*CB*FCGV["MW"]*FCGV["MZ"]*(1 - 2*FCGV["SW"]^2) - 2*CA*FCGV["CW"]*Mass[F[2, {j1}]]^2)*
          USf[2, j1][s2, 1] + FCGV["CW"]*(-(CA*Af[2, j1, j1]) + SA*Conjugate[MUE])*
          Mass[F[2, {j1}]]*USf[2, j1][s2, 2]) + Conjugate[USf[2, j1][s1, 2]]*
        (FCGV["CW"]*(MUE*SA - CA*Conjugate[Af[2, j1, j1]])*Mass[F[2, {j1}]]*
          USf[2, j1][s2, 1] + 2*CAB*CB*FCGV["MW"]*FCGV["MZ"]*FCGV["SW"]^2*USf[2, j1][s2, 2] - 
         2*CA*FCGV["CW"]*Mass[F[2, {j1}]]^2*USf[2, j1][s2, 2])))/(CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[1], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{((-I/6)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s1, 1]]*((FCGV["MW"]*FCGV["MZ"]*SAB*SB*(-3 + 4*FCGV["SW"]^2) + 
           6*CA*FCGV["CW"]*Mass[F[3, {j1}]]^2)*USf[3, j1][s2, 1] + 
         3*FCGV["CW"]*(CA*Af[3, j1, j1] + SA*Conjugate[MUE])*Mass[F[3, {j1}]]*
          USf[3, j1][s2, 2]) + Conjugate[USf[3, j1][s1, 2]]*
        (3*FCGV["CW"]*(MUE*SA + CA*Conjugate[Af[3, j1, j1]])*Mass[F[3, {j1}]]*
          USf[3, j1][s2, 1] - 4*FCGV["MW"]*FCGV["MZ"]*SAB*SB*FCGV["SW"]^2*USf[3, j1][s2, 2] + 
         6*CA*FCGV["CW"]*Mass[F[3, {j1}]]^2*USf[3, j1][s2, 2])))/(FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[S[2], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{((-I/6)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s1, 1]]*((CAB*FCGV["MW"]*FCGV["MZ"]*SB*(3 - 4*FCGV["SW"]^2) + 
           6*FCGV["CW"]*SA*Mass[F[3, {j1}]]^2)*USf[3, j1][s2, 1] + 
         3*FCGV["CW"]*(SA*Af[3, j1, j1] - CA*Conjugate[MUE])*Mass[F[3, {j1}]]*
          USf[3, j1][s2, 2]) + Conjugate[USf[3, j1][s1, 2]]*
        (3*FCGV["CW"]*(-(CA*MUE) + SA*Conjugate[Af[3, j1, j1]])*Mass[F[3, {j1}]]*
          USf[3, j1][s2, 1] + 4*CAB*FCGV["MW"]*FCGV["MZ"]*SB*FCGV["SW"]^2*USf[3, j1][s2, 2] + 
         6*FCGV["CW"]*SA*Mass[F[3, {j1}]]^2*USf[3, j1][s2, 2])))/(FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[S[1], S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((I/6)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s1, 1]]*((CB*FCGV["MW"]*FCGV["MZ"]*SAB*(-3 + 2*FCGV["SW"]^2) + 
           6*FCGV["CW"]*SA*Mass[F[4, {j1}]]^2)*USf[4, j1][s2, 1] + 
         3*FCGV["CW"]*(SA*Af[4, j1, j1] + CA*Conjugate[MUE])*Mass[F[4, {j1}]]*
          USf[4, j1][s2, 2]) + Conjugate[USf[4, j1][s1, 2]]*
        (3*FCGV["CW"]*(CA*MUE + SA*Conjugate[Af[4, j1, j1]])*Mass[F[4, {j1}]]*
          USf[4, j1][s2, 1] - 2*CB*FCGV["MW"]*FCGV["MZ"]*SAB*FCGV["SW"]^2*USf[4, j1][s2, 2] + 
         6*FCGV["CW"]*SA*Mass[F[4, {j1}]]^2*USf[4, j1][s2, 2])))/(CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[2], S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((-I/6)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s1, 1]]*((CAB*CB*FCGV["MW"]*FCGV["MZ"]*(-3 + 2*FCGV["SW"]^2) + 
           6*CA*FCGV["CW"]*Mass[F[4, {j1}]]^2)*USf[4, j1][s2, 1] + 
         3*FCGV["CW"]*(CA*Af[4, j1, j1] - SA*Conjugate[MUE])*Mass[F[4, {j1}]]*
          USf[4, j1][s2, 2]) + Conjugate[USf[4, j1][s1, 2]]*
        (3*FCGV["CW"]*(-(MUE*SA) + CA*Conjugate[Af[4, j1, j1]])*Mass[F[4, {j1}]]*
          USf[4, j1][s2, 1] - 2*CAB*CB*FCGV["MW"]*FCGV["MZ"]*FCGV["SW"]^2*USf[4, j1][s2, 2] + 
         6*CA*FCGV["CW"]*Mass[F[4, {j1}]]^2*USf[4, j1][s2, 2])))/(CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-S[5], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I)*FCGV["EL"]*CKM[j1, j2]*IndexDelta[o1, o2]*
      (-(Conjugate[USf[4, j2][s2, 2]]*Mass[F[4, {j2}]]*
         (TB*(MUE + TB*Conjugate[Af[4, j2, j2]])*USf[3, j1][s1, 1] + 
          (1 + TB^2)*Mass[F[3, {j1}]]*USf[3, j1][s1, 2])) + 
       Conjugate[USf[4, j2][s2, 1]]*
        (-((Mass[F[3, {j1}]]^2 + TB*(-(FCGV["MW"]^2*S2B) + TB*Mass[F[4, {j2}]]^2))*
           USf[3, j1][s1, 1]) - (Af[3, j1, j1] + TB*Conjugate[MUE])*
          Mass[F[3, {j1}]]*USf[3, j1][s1, 2])))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[S[5], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((-I)*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (-(Conjugate[USf[3, j1][s1, 2]]*Mass[F[3, {j1}]]*
         ((MUE*TB + Conjugate[Af[3, j1, j1]])*USf[4, j2][s2, 1] + 
          (1 + TB^2)*Mass[F[4, {j2}]]*USf[4, j2][s2, 2])) + 
       Conjugate[USf[3, j1][s1, 1]]*
        (-((Mass[F[3, {j1}]]^2 + TB*(-(FCGV["MW"]^2*S2B) + TB*Mass[F[4, {j2}]]^2))*
           USf[4, j2][s2, 1]) - TB*(TB*Af[4, j2, j2] + Conjugate[MUE])*
          Mass[F[4, {j2}]]*USf[4, j2][s2, 2])))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[-S[5], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2]*(-((MUE + TB*Conjugate[Af[2, j1, j1]])*
         Conjugate[USf[2, j1][s2, 2]]*Mass[F[2, {j1}]]) + 
       Conjugate[USf[2, j1][s2, 1]]*(FCGV["MW"]^2*S2B - TB*Mass[F[2, {j1}]]^2)))/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, C[S[5], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{((-I)*FCGV["EL"]*IndexDelta[j1, j2]*((FCGV["MW"]^2*S2B - TB*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s2, 1] - (TB*Af[2, j1, j1] + Conjugate[MUE])*
        Mass[F[2, {j1}]]*USf[2, j1][s2, 2]))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[-S[6], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{(I*FCGV["EL"]*CKM[j1, j2]*IndexDelta[o1, o2]*
      (TB*(MUE*TB - Conjugate[Af[4, j2, j2]])*Conjugate[USf[4, j2][s2, 2]]*
        Mass[F[4, {j2}]]*USf[3, j1][s1, 1] + Conjugate[USf[4, j2][s2, 1]]*
        (TB*(C2B*FCGV["MW"]^2 + Mass[F[3, {j1}]]^2 - Mass[F[4, {j2}]]^2)*
          USf[3, j1][s1, 1] + (TB*Af[3, j1, j1] - Conjugate[MUE])*
          Mass[F[3, {j1}]]*USf[3, j1][s1, 2])))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[S[6], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{(I*FCGV["EL"]*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      ((-MUE + TB*Conjugate[Af[3, j1, j1]])*Conjugate[USf[3, j1][s1, 2]]*
        Mass[F[3, {j1}]]*USf[4, j2][s2, 1] + TB*Conjugate[USf[3, j1][s1, 1]]*
        ((C2B*FCGV["MW"]^2 + Mass[F[3, {j1}]]^2 - Mass[F[4, {j2}]]^2)*
          USf[4, j2][s2, 1] + (-Af[4, j2, j2] + TB*Conjugate[MUE])*
          Mass[F[4, {j2}]]*USf[4, j2][s2, 2])))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"]*TB)}}, 
 C[-S[6], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{(I*FCGV["EL"]*IndexDelta[j1, j2]*((MUE*TB - Conjugate[Af[2, j1, j1]])*
        Conjugate[USf[2, j1][s2, 2]]*Mass[F[2, {j1}]] + 
       Conjugate[USf[2, j1][s2, 1]]*(C2B*FCGV["MW"]^2 - Mass[F[2, {j1}]]^2)))/
     (Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, C[S[6], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{(I*FCGV["EL"]*IndexDelta[j1, j2]*((C2B*FCGV["MW"]^2 - Mass[F[2, {j1}]]^2)*
        USf[2, j1][s2, 1] + (-Af[2, j1, j1] + TB*Conjugate[MUE])*
        Mass[F[2, {j1}]]*USf[2, j1][s2, 2]))/(Sqrt[2]*FCGV["MW"]*FCGV["SW"])}}, 
 C[S[11, {j1}], -S[11, {j2}], V[2]] == 
  {{((-I/2)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2])/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[1]] == 
  {{I*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[s1, s2]}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[2]] == 
  {{((-I/2)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*
      ((-1 + 2*FCGV["SW"]^2)*Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
       2*FCGV["SW"]^2*Conjugate[USf[2, j1][s1, 2]]*USf[2, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[1]] == 
  {{((-2*I)/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*IndexDelta[s1, s2]}}, 
 C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[2]] == 
  {{((I/6)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((-3 + 4*FCGV["SW"]^2)*Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s2, 1] + 
       4*FCGV["SW"]^2*Conjugate[USf[3, j1][s1, 2]]*USf[3, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[1]] == 
  {{(I/3)*FCGV["EL"]*IndexDelta[j1, j2]*IndexDelta[o1, o2]*IndexDelta[s1, s2]}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[2]] == 
  {{((-I/6)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((-3 + 2*FCGV["SW"]^2)*Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] + 
       2*FCGV["SW"]^2*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*Conjugate[USf[3, j1][s1, 1]]*
      IndexDelta[o1, o2]*USf[4, j2][s2, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}], -V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*CKM[j1, j2]*Conjugate[USf[4, j2][s2, 1]]*
      IndexDelta[o1, o2]*USf[3, j1][s1, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[11, {j1}], -S[12, {s2, j2}], V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[12, {s2, j2}], -S[11, {j1}], -V[3]] == 
  {{((-I)*FCGV["EL"]*$HKSign*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2])/
     (Sqrt[2]*FCGV["SW"])}}, C[F[11, {n2}], F[11, {n1}], S[1]] == 
  {{((-I/2)*FCGV["EL"]*$HKSign*(SA*Conjugate[ZNeu[n1, 3]]*
        (FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + 
       CA*Conjugate[ZNeu[n1, 4]]*(FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - 
         FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + (FCGV["SW"]*Conjugate[ZNeu[n1, 1]] - 
         FCGV["CW"]*Conjugate[ZNeu[n1, 2]])*(SA*Conjugate[ZNeu[n2, 3]] + 
         CA*Conjugate[ZNeu[n2, 4]])))/(FCGV["CW"]*FCGV["SW"])}, 
   {((I/2)*FCGV["EL"]*$HKSign*(ZNeu[n1, 4]*(-(CA*FCGV["SW"]*ZNeu[n2, 1]) + 
         CA*FCGV["CW"]*ZNeu[n2, 2]) + ZNeu[n1, 3]*(-(SA*FCGV["SW"]*ZNeu[n2, 1]) + 
         FCGV["CW"]*SA*ZNeu[n2, 2]) - (FCGV["SW"]*ZNeu[n1, 1] - FCGV["CW"]*ZNeu[n1, 2])*
        (SA*ZNeu[n2, 3] + CA*ZNeu[n2, 4])))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[F[11, {n2}], F[11, {n1}], S[2]] == 
  {{((I/2)*FCGV["EL"]*$HKSign*(CA*Conjugate[ZNeu[n1, 3]]*(FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - 
         FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + Conjugate[ZNeu[n1, 4]]*
        (-(SA*FCGV["SW"]*Conjugate[ZNeu[n2, 1]]) + FCGV["CW"]*SA*Conjugate[ZNeu[n2, 2]]) + 
       (FCGV["SW"]*Conjugate[ZNeu[n1, 1]] - FCGV["CW"]*Conjugate[ZNeu[n1, 2]])*
        (CA*Conjugate[ZNeu[n2, 3]] - SA*Conjugate[ZNeu[n2, 4]])))/(FCGV["CW"]*FCGV["SW"])}, 
   {((I/2)*FCGV["EL"]*$HKSign*(CA*ZNeu[n1, 3]*(FCGV["SW"]*ZNeu[n2, 1] - FCGV["CW"]*ZNeu[n2, 2]) + 
       ZNeu[n1, 4]*(-(SA*FCGV["SW"]*ZNeu[n2, 1]) + FCGV["CW"]*SA*ZNeu[n2, 2]) + 
       (FCGV["SW"]*ZNeu[n1, 1] - FCGV["CW"]*ZNeu[n1, 2])*(CA*ZNeu[n2, 3] - SA*ZNeu[n2, 4])))/
     (FCGV["CW"]*FCGV["SW"])}}, C[F[11, {n2}], F[11, {n1}], S[3]] == 
  {{(FCGV["EL"]*$HKSign*(SB*Conjugate[ZNeu[n1, 3]]*(FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - 
         FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + Conjugate[ZNeu[n1, 4]]*
        (-(CB*FCGV["SW"]*Conjugate[ZNeu[n2, 1]]) + CB*FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + 
       (FCGV["SW"]*Conjugate[ZNeu[n1, 1]] - FCGV["CW"]*Conjugate[ZNeu[n1, 2]])*
        (SB*Conjugate[ZNeu[n2, 3]] - CB*Conjugate[ZNeu[n2, 4]])))/(2*FCGV["CW"]*FCGV["SW"])}, 
   {-(FCGV["EL"]*$HKSign*(SB*ZNeu[n1, 3]*(FCGV["SW"]*ZNeu[n2, 1] - FCGV["CW"]*ZNeu[n2, 2]) + 
        ZNeu[n1, 4]*(-(CB*FCGV["SW"]*ZNeu[n2, 1]) + CB*FCGV["CW"]*ZNeu[n2, 2]) + 
        (FCGV["SW"]*ZNeu[n1, 1] - FCGV["CW"]*ZNeu[n1, 2])*(SB*ZNeu[n2, 3] - CB*ZNeu[n2, 4])))/
     (2*FCGV["CW"]*FCGV["SW"])}}, C[F[11, {n2}], F[11, {n1}], S[4]] == 
  {{-(FCGV["EL"]*$HKSign*(CB*Conjugate[ZNeu[n1, 3]]*(FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - 
          FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + SB*Conjugate[ZNeu[n1, 4]]*
         (FCGV["SW"]*Conjugate[ZNeu[n2, 1]] - FCGV["CW"]*Conjugate[ZNeu[n2, 2]]) + 
        (FCGV["SW"]*Conjugate[ZNeu[n1, 1]] - FCGV["CW"]*Conjugate[ZNeu[n1, 2]])*
         (CB*Conjugate[ZNeu[n2, 3]] + SB*Conjugate[ZNeu[n2, 4]])))/
     (2*FCGV["CW"]*FCGV["SW"])}, 
   {(FCGV["EL"]*$HKSign*(CB*ZNeu[n1, 3]*(FCGV["SW"]*ZNeu[n2, 1] - FCGV["CW"]*ZNeu[n2, 2]) + 
       SB*ZNeu[n1, 4]*(FCGV["SW"]*ZNeu[n2, 1] - FCGV["CW"]*ZNeu[n2, 2]) + 
       (FCGV["SW"]*ZNeu[n1, 1] - FCGV["CW"]*ZNeu[n1, 2])*(CB*ZNeu[n2, 3] + SB*ZNeu[n2, 4])))/
     (2*FCGV["CW"]*FCGV["SW"])}}, C[F[12, {c1}], -F[12, {c2}], S[1]] == 
  {{(I*FCGV["EL"]*(SA*Conjugate[UCha[c1, 2]]*Conjugate[VCha[c2, 1]] - 
       CA*Conjugate[UCha[c1, 1]]*Conjugate[VCha[c2, 2]]))/(Sqrt[2]*FCGV["SW"])}, 
   {(I*FCGV["EL"]*(SA*UCha[c2, 2]*VCha[c1, 1] - CA*UCha[c2, 1]*VCha[c1, 2]))/
     (Sqrt[2]*FCGV["SW"])}}, C[F[12, {c1}], -F[12, {c2}], S[2]] == 
  {{((-I)*FCGV["EL"]*(CA*Conjugate[UCha[c1, 2]]*Conjugate[VCha[c2, 1]] + 
       SA*Conjugate[UCha[c1, 1]]*Conjugate[VCha[c2, 2]]))/(Sqrt[2]*FCGV["SW"])}, 
   {((-I)*FCGV["EL"]*(CA*UCha[c2, 2]*VCha[c1, 1] + SA*UCha[c2, 1]*VCha[c1, 2]))/
     (Sqrt[2]*FCGV["SW"])}}, C[F[12, {c1}], -F[12, {c2}], S[3]] == 
  {{-((FCGV["EL"]*(SB*Conjugate[UCha[c1, 2]]*Conjugate[VCha[c2, 1]] + 
        CB*Conjugate[UCha[c1, 1]]*Conjugate[VCha[c2, 2]]))/(Sqrt[2]*FCGV["SW"]))}, 
   {(FCGV["EL"]*(SB*UCha[c2, 2]*VCha[c1, 1] + CB*UCha[c2, 1]*VCha[c1, 2]))/
     (Sqrt[2]*FCGV["SW"])}}, C[F[12, {c1}], -F[12, {c2}], S[4]] == 
  {{(FCGV["EL"]*(CB*Conjugate[UCha[c1, 2]]*Conjugate[VCha[c2, 1]] - 
       SB*Conjugate[UCha[c1, 1]]*Conjugate[VCha[c2, 2]]))/(Sqrt[2]*FCGV["SW"])}, 
   {(FCGV["EL"]*(-(CB*UCha[c2, 2]*VCha[c1, 1]) + SB*UCha[c2, 1]*VCha[c1, 2]))/
     (Sqrt[2]*FCGV["SW"])}}, C[F[11, {n1}], -F[12, {c2}], S[5]] == 
  {{((-I)*CB*FCGV["EL"]*$HKSign*((Conjugate[VCha[c2, 2]]*
         ((FCGV["SW"]*Conjugate[ZNeu[n1, 1]])/FCGV["CW"] + Conjugate[ZNeu[n1, 2]]))/Sqrt[2] + 
       Conjugate[VCha[c2, 1]]*Conjugate[ZNeu[n1, 4]]))/FCGV["SW"]}, 
   {((-I)*FCGV["EL"]*SB*$HKSign*(-((UCha[c2, 2]*((FCGV["SW"]*ZNeu[n1, 1])/FCGV["CW"] + ZNeu[n1, 2]))/
         Sqrt[2]) + UCha[c2, 1]*ZNeu[n1, 3]))/FCGV["SW"]}}, 
 C[F[11, {n1}], -F[12, {c2}], S[6]] == 
  {{((-I)*FCGV["EL"]*SB*$HKSign*((Conjugate[VCha[c2, 2]]*
         ((FCGV["SW"]*Conjugate[ZNeu[n1, 1]])/FCGV["CW"] + Conjugate[ZNeu[n1, 2]]))/Sqrt[2] + 
       Conjugate[VCha[c2, 1]]*Conjugate[ZNeu[n1, 4]]))/FCGV["SW"]}, 
   {(I*CB*FCGV["EL"]*$HKSign*(-((UCha[c2, 2]*((FCGV["SW"]*ZNeu[n1, 1])/FCGV["CW"] + ZNeu[n1, 2]))/
         Sqrt[2]) + UCha[c2, 1]*ZNeu[n1, 3]))/FCGV["SW"]}}, 
 C[F[12, {c2}], F[11, {n1}], -S[5]] == 
  {{((-I)*FCGV["EL"]*SB*$HKSign*(-((Conjugate[UCha[c2, 2]]*
          ((FCGV["SW"]*Conjugate[ZNeu[n1, 1]])/FCGV["CW"] + Conjugate[ZNeu[n1, 2]]))/
         Sqrt[2]) + Conjugate[UCha[c2, 1]]*Conjugate[ZNeu[n1, 3]]))/FCGV["SW"]}, 
   {((-I)*CB*FCGV["EL"]*$HKSign*((VCha[c2, 2]*((FCGV["SW"]*ZNeu[n1, 1])/FCGV["CW"] + ZNeu[n1, 2]))/
        Sqrt[2] + VCha[c2, 1]*ZNeu[n1, 4]))/FCGV["SW"]}}, 
 C[F[12, {c2}], F[11, {n1}], -S[6]] == 
  {{(I*CB*FCGV["EL"]*$HKSign*(-((Conjugate[UCha[c2, 2]]*((FCGV["SW"]*Conjugate[ZNeu[n1, 1]])/
            FCGV["CW"] + Conjugate[ZNeu[n1, 2]]))/Sqrt[2]) + Conjugate[UCha[c2, 1]]*
        Conjugate[ZNeu[n1, 3]]))/FCGV["SW"]}, 
   {((-I)*FCGV["EL"]*SB*$HKSign*((VCha[c2, 2]*((FCGV["SW"]*ZNeu[n1, 1])/FCGV["CW"] + ZNeu[n1, 2]))/
        Sqrt[2] + VCha[c2, 1]*ZNeu[n1, 4]))/FCGV["SW"]}}, 
 C[F[11, {n1}], -F[1, {j1}], S[11, {j2}]] == 
  {{0}, {(I*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(FCGV["SW"]*ZNeu[n1, 1] - FCGV["CW"]*ZNeu[n1, 2]))/
     (Sqrt[2]*FCGV["CW"]*FCGV["SW"])}}, C[F[11, {n1}], -F[2, {j1}], S[12, {s2, j2}]] == 
  {{((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(2*CB*FCGV["MW"]*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*
        Conjugate[USf[2, j1][s2, 2]] + FCGV["CW"]*Conjugate[ZNeu[n1, 3]]*
        Conjugate[USf[2, j1][s2, 1]]*Mass[F[2, {j1}]]))/
     (Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}, 
   {(I*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(CB*FCGV["MW"]*Conjugate[USf[2, j1][s2, 1]]*
        (FCGV["SW"]*ZNeu[n1, 1] + FCGV["CW"]*ZNeu[n1, 2]) - FCGV["CW"]*Conjugate[USf[2, j1][s2, 2]]*
        Mass[F[2, {j1}]]*ZNeu[n1, 3]))/(Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[11, {n1}], -F[3, {j1, o1}], S[13, {s2, j2, o2}]] == 
  {{((I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (4*FCGV["MW"]*SB*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*Conjugate[USf[3, j1][s2, 2]] - 
       3*FCGV["CW"]*Conjugate[ZNeu[n1, 4]]*Conjugate[USf[3, j1][s2, 1]]*
        Mass[F[3, {j1, o1}]]))/(Sqrt[2]*FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}, 
   {((-I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (FCGV["MW"]*SB*Conjugate[USf[3, j1][s2, 1]]*(FCGV["SW"]*ZNeu[n1, 1] + 
         3*FCGV["CW"]*ZNeu[n1, 2]) + 3*FCGV["CW"]*Conjugate[USf[3, j1][s2, 2]]*
        Mass[F[3, {j1, o1}]]*ZNeu[n1, 4]))/(Sqrt[2]*FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}}, 
 C[F[11, {n1}], -F[4, {j1, o1}], S[14, {s2, j2, o2}]] == 
  {{((-I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (2*CB*FCGV["MW"]*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*Conjugate[USf[4, j1][s2, 2]] + 
       3*FCGV["CW"]*Conjugate[ZNeu[n1, 3]]*Conjugate[USf[4, j1][s2, 1]]*
        Mass[F[4, {j1, o1}]]))/(Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}, 
   {((I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (CB*FCGV["MW"]*Conjugate[USf[4, j1][s2, 1]]*(-(FCGV["SW"]*ZNeu[n1, 1]) + 
         3*FCGV["CW"]*ZNeu[n1, 2]) - 3*FCGV["CW"]*Conjugate[USf[4, j1][s2, 2]]*
        Mass[F[4, {j1, o1}]]*ZNeu[n1, 3]))/(Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, 
 C[F[1, {j1}], F[11, {n1}], -S[11, {j2}]] == 
  {{(I*FCGV["EL"]*$HKSign*(FCGV["SW"]*Conjugate[ZNeu[n1, 1]] - FCGV["CW"]*Conjugate[ZNeu[n1, 2]])*
      IndexDelta[j1, j2])/(Sqrt[2]*FCGV["CW"]*FCGV["SW"])}, {0}}, 
 C[F[2, {j1}], F[11, {n1}], -S[12, {s2, j2}]] == 
  {{(I*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(CB*FCGV["MW"]*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*
        USf[2, j1][s2, 1] + FCGV["CW"]*(CB*FCGV["MW"]*Conjugate[ZNeu[n1, 2]]*
          USf[2, j1][s2, 1] - Conjugate[ZNeu[n1, 3]]*Mass[F[2, {j1}]]*
          USf[2, j1][s2, 2])))/(Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}, 
   {((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(FCGV["CW"]*Mass[F[2, {j1}]]*ZNeu[n1, 3]*
        USf[2, j1][s2, 1] + 2*CB*FCGV["MW"]*FCGV["SW"]*ZNeu[n1, 1]*USf[2, j1][s2, 2]))/
     (Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, C[F[3, {j1, o1}], F[11, {n1}], 
   -S[13, {s2, j2, o2}]] == 
  {{((-I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (FCGV["MW"]*SB*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*USf[3, j1][s2, 1] + 
       3*FCGV["CW"]*(FCGV["MW"]*SB*Conjugate[ZNeu[n1, 2]]*USf[3, j1][s2, 1] + 
         Conjugate[ZNeu[n1, 4]]*Mass[F[3, {j1, o1}]]*USf[3, j1][s2, 2])))/
     (Sqrt[2]*FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}, {((I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*
      IndexDelta[o1, o2]*(-3*FCGV["CW"]*Mass[F[3, {j1, o1}]]*ZNeu[n1, 4]*
        USf[3, j1][s2, 1] + 4*FCGV["MW"]*SB*FCGV["SW"]*ZNeu[n1, 1]*USf[3, j1][s2, 2]))/
     (Sqrt[2]*FCGV["CW"]*FCGV["MW"]*SB*FCGV["SW"])}}, C[F[4, {j1, o1}], F[11, {n1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (-(CB*FCGV["MW"]*FCGV["SW"]*Conjugate[ZNeu[n1, 1]]*USf[4, j1][s2, 1]) + 
       3*FCGV["CW"]*(CB*FCGV["MW"]*Conjugate[ZNeu[n1, 2]]*USf[4, j1][s2, 1] - 
         Conjugate[ZNeu[n1, 3]]*Mass[F[4, {j1, o1}]]*USf[4, j1][s2, 2])))/
     (Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}, {((-I/3)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*
      IndexDelta[o1, o2]*(3*FCGV["CW"]*Mass[F[4, {j1, o1}]]*ZNeu[n1, 3]*
        USf[4, j1][s2, 1] + 2*CB*FCGV["MW"]*FCGV["SW"]*ZNeu[n1, 1]*USf[4, j1][s2, 2]))/
     (Sqrt[2]*CB*FCGV["CW"]*FCGV["MW"]*FCGV["SW"])}}, C[F[12, {c1}], -F[4, {j2, o1}], 
   S[13, {s1, j1, o2}]] == 
  {{(I*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*Conjugate[UCha[c1, 2]]*
      Conjugate[USf[3, j1][s1, 1]]*IndexDelta[o1, o2]*Mass[F[4, {j2, o1}]])/
     (Sqrt[2]*CB*FCGV["MW"]*FCGV["SW"])}, {((-I/2)*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*
      IndexDelta[o1, o2]*(2*FCGV["MW"]*SB*Conjugate[USf[3, j1][s1, 1]]*VCha[c1, 1] - 
       Sqrt[2]*Conjugate[USf[3, j1][s1, 2]]*Mass[F[3, {j1}]]*VCha[c1, 2]))/
     (FCGV["MW"]*SB*FCGV["SW"])}}, C[-F[12, {c1}], -F[3, {j1, o1}], S[14, {s2, j2, o2}]] == 
  {{(I*FCGV["EL"]*$HKSign*CKM[j1, j2]*Conjugate[VCha[c1, 2]]*
      Conjugate[USf[4, j2][s2, 1]]*IndexDelta[o1, o2]*Mass[F[3, {j1, o1}]])/
     (Sqrt[2]*FCGV["MW"]*SB*FCGV["SW"])}, {((-I/2)*FCGV["EL"]*$HKSign*CKM[j1, j2]*IndexDelta[o1, o2]*
      (2*CB*FCGV["MW"]*Conjugate[USf[4, j2][s2, 1]]*UCha[c1, 1] - 
       Sqrt[2]*Conjugate[USf[4, j2][s2, 2]]*Mass[F[4, {j2}]]*UCha[c1, 2]))/
     (CB*FCGV["MW"]*FCGV["SW"])}}, C[F[12, {c1}], -F[2, {j2}], S[11, {j1}]] == 
  {{(I*FCGV["EL"]*$HKSign*Conjugate[UCha[c1, 2]]*IndexDelta[j1, j2]*Mass[F[2, {j1}]])/
     (Sqrt[2]*CB*FCGV["MW"]*FCGV["SW"])}, {((-I)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*VCha[c1, 1])/
     FCGV["SW"]}}, C[-F[12, {c1}], -F[1, {j1}], S[12, {s2, j2}]] == 
  {{0}, {((I/2)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*
      (-2*Conjugate[USf[2, j1][s2, 1]]*UCha[c1, 1] + 
       (Sqrt[2]*Conjugate[USf[2, j1][s2, 2]]*Mass[F[2, {j1}]]*UCha[c1, 2])/
        (CB*FCGV["MW"])))/FCGV["SW"]}}, C[F[4, {j2, o1}], -F[12, {c1}], 
   -S[13, {s1, j1, o2}]] == 
  {{((-I/2)*FCGV["EL"]*$HKSign*CKM[j1, j2]*IndexDelta[o1, o2]*
      (2*FCGV["MW"]*SB*Conjugate[VCha[c1, 1]]*USf[3, j1][s1, 1] - 
       Sqrt[2]*Conjugate[VCha[c1, 2]]*Mass[F[3, {j1}]]*USf[3, j1][s1, 2]))/
     (FCGV["MW"]*SB*FCGV["SW"])}, {(I*FCGV["EL"]*$HKSign*CKM[j1, j2]*IndexDelta[o1, o2]*
      Mass[F[4, {j2, o1}]]*UCha[c1, 2]*USf[3, j1][s1, 1])/
     (Sqrt[2]*CB*FCGV["MW"]*FCGV["SW"])}}, C[F[3, {j1, o1}], F[12, {c1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((-I/2)*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (2*CB*FCGV["MW"]*Conjugate[UCha[c1, 1]]*USf[4, j2][s2, 1] - 
       Sqrt[2]*Conjugate[UCha[c1, 2]]*Mass[F[4, {j2}]]*USf[4, j2][s2, 2]))/
     (CB*FCGV["MW"]*FCGV["SW"])}, {(I*FCGV["EL"]*$HKSign*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      Mass[F[3, {j1, o1}]]*VCha[c1, 2]*USf[4, j2][s2, 1])/
     (Sqrt[2]*FCGV["MW"]*SB*FCGV["SW"])}}, C[F[2, {j2}], -F[12, {c1}], -S[11, {j1}]] == 
  {{((-I)*FCGV["EL"]*$HKSign*Conjugate[VCha[c1, 1]]*IndexDelta[j1, j2])/FCGV["SW"]}, 
   {(I*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*Mass[F[2, {j1}]]*UCha[c1, 2])/
     (Sqrt[2]*CB*FCGV["MW"]*FCGV["SW"])}}, C[F[1, {j1}], F[12, {c1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]*$HKSign*IndexDelta[j1, j2]*(-2*Conjugate[UCha[c1, 1]]*
        USf[2, j1][s2, 1] + (Sqrt[2]*Conjugate[UCha[c1, 2]]*Mass[F[2, {j1}]]*
         USf[2, j1][s2, 2])/(CB*FCGV["MW"])))/FCGV["SW"]}, {0}}, 
 C[F[11, {n1}], F[11, {n2}], V[2]] == 
  {{((I/2)*FCGV["EL"]*$HKSign*(-(Conjugate[ZNeu[n2, 3]]*ZNeu[n1, 3]) + 
       Conjugate[ZNeu[n2, 4]]*ZNeu[n1, 4]))/(FCGV["CW"]*FCGV["SW"])}, 
   {((I/2)*FCGV["EL"]*$HKSign*(Conjugate[ZNeu[n1, 3]]*ZNeu[n2, 3] - 
       Conjugate[ZNeu[n1, 4]]*ZNeu[n2, 4]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[F[11, {n2}], -F[12, {c1}], V[3]] == 
  {{(I*FCGV["EL"]*$HKSign*(Conjugate[VCha[c1, 1]]*ZNeu[n2, 2] - 
       (Conjugate[VCha[c1, 2]]*ZNeu[n2, 4])/Sqrt[2]))/FCGV["SW"]}, 
   {(I*FCGV["EL"]*$HKSign*(Conjugate[ZNeu[n2, 2]]*UCha[c1, 1] + 
       (Conjugate[ZNeu[n2, 3]]*UCha[c1, 2])/Sqrt[2]))/FCGV["SW"]}}, 
 C[F[12, {c1}], F[11, {n2}], -V[3]] == 
  {{(I*FCGV["EL"]*$HKSign*(Conjugate[ZNeu[n2, 2]]*VCha[c1, 1] - 
       (Conjugate[ZNeu[n2, 4]]*VCha[c1, 2])/Sqrt[2]))/FCGV["SW"]}, 
   {(I*FCGV["EL"]*$HKSign*(Conjugate[UCha[c1, 1]]*ZNeu[n2, 2] + 
       (Conjugate[UCha[c1, 2]]*ZNeu[n2, 3])/Sqrt[2]))/FCGV["SW"]}}, 
 C[-F[12, {c2}], F[12, {c1}], V[1]] == {{I*FCGV["EL"]*IndexDelta[c1, c2]}, 
   {I*FCGV["EL"]*IndexDelta[c1, c2]}}, C[-F[12, {c2}], F[12, {c1}], V[2]] == 
  {{((-I)*FCGV["EL"]*$HKSign*(FCGV["SW"]^2*IndexDelta[c1, c2] - Conjugate[UCha[c1, 1]]*
        UCha[c2, 1] - (Conjugate[UCha[c1, 2]]*UCha[c2, 2])/2))/(FCGV["CW"]*FCGV["SW"])}, 
   {((-I)*FCGV["EL"]*$HKSign*(FCGV["SW"]^2*IndexDelta[c1, c2] - Conjugate[VCha[c2, 1]]*
        VCha[c1, 1] - (Conjugate[VCha[c2, 2]]*VCha[c1, 2])/2))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[1], S[1], S[11, {j2}], -S[11, {j1}]] == 
  {{((I/4)*C2A*FCGV["EL"]^2*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (C2A*CB^2*FCGV["MW"]^2*(-1 + 2*FCGV["SW"]^2) - 2*FCGV["CW"]^2*SA^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] - 2*Conjugate[USf[2, j1][s2, 2]]*
        (C2A*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + FCGV["CW"]^2*SA^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 2]))/(CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[1], S[13, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(C2A*FCGV["MW"]^2*SB^2*(-3 + 4*FCGV["SW"]^2) + 
         6*CA^2*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       2*Conjugate[USf[3, j1][s2, 2]]*(-2*C2A*FCGV["MW"]^2*SB^2*FCGV["SW"]^2 + 
         3*CA^2*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)}}, C[S[1], S[1], S[14, {s2, j2, o1}], 
   -S[14, {s1, j1, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(C2A*CB^2*FCGV["MW"]^2*(-3 + 2*FCGV["SW"]^2) - 
         6*FCGV["CW"]^2*SA^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] - 
       2*Conjugate[USf[4, j1][s2, 2]]*(C2A*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*SA^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[2], S[2], S[11, {j2}], -S[11, {j1}]] == 
  {{((-I/4)*C2A*FCGV["EL"]^2*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((-I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (C2A*CB^2*FCGV["MW"]^2*(-1 + 2*FCGV["SW"]^2) + 2*CA^2*FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] + 2*Conjugate[USf[2, j1][s2, 2]]*
        (-(C2A*CB^2*FCGV["MW"]^2*FCGV["SW"]^2) + CA^2*FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 2]))/(CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[2], S[2], S[13, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(C2A*FCGV["MW"]^2*SB^2*(3 - 4*FCGV["SW"]^2) + 
         6*FCGV["CW"]^2*SA^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       2*Conjugate[USf[3, j1][s2, 2]]*(2*C2A*FCGV["MW"]^2*SB^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*SA^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)}}, C[S[2], S[2], S[14, {s2, j2, o1}], 
   -S[14, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(C2A*CB^2*FCGV["MW"]^2*(-3 + 2*FCGV["SW"]^2) + 
         6*CA^2*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] - 
       2*Conjugate[USf[4, j1][s2, 2]]*(C2A*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 - 
         3*CA^2*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[3], S[3], S[11, {j2}], -S[11, {j1}]] == 
  {{((I/4)*C2B*FCGV["EL"]^2*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[3], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((-I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (C2B*FCGV["MW"]^2*(1 - 2*FCGV["SW"]^2) + 2*FCGV["CW"]^2*TB^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] + 2*Conjugate[USf[2, j1][s2, 2]]*
        (C2B*FCGV["MW"]^2*FCGV["SW"]^2 + FCGV["CW"]^2*TB^2*Mass[F[2, {j1}]]^2)*USf[2, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[3], S[3], S[13, {s2, j2, o1}], 
   -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(C2B*FCGV["MW"]^2*(-3 + 4*FCGV["SW"]^2)*TB^2 + 
         6*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       2*Conjugate[USf[3, j1][s2, 2]]*(-2*C2B*FCGV["MW"]^2*FCGV["SW"]^2*TB^2 + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB^2)}}, C[S[3], S[3], S[14, {s2, j2, o1}], 
   -S[14, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(C2B*FCGV["MW"]^2*(3 - 2*FCGV["SW"]^2) + 
         6*FCGV["CW"]^2*TB^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] + 
       2*Conjugate[USf[4, j1][s2, 2]]*(C2B*FCGV["MW"]^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*TB^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[4], S[4], S[11, {j2}], -S[11, {j1}]] == 
  {{((-I/4)*C2B*FCGV["EL"]^2*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((-I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (C2B*FCGV["MW"]^2*(-1 + 2*FCGV["SW"]^2) + 2*FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] + 2*Conjugate[USf[2, j1][s2, 2]]*
        (-(C2B*FCGV["MW"]^2*FCGV["SW"]^2) + FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*USf[2, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[4], S[4], S[13, {s2, j2, o1}], 
   -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(C2B*FCGV["MW"]^2*(3 - 4*FCGV["SW"]^2) + 
         6*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       2*Conjugate[USf[3, j1][s2, 2]]*(2*C2B*FCGV["MW"]^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/(FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], S[4], S[14, {s2, j2, o1}], -S[14, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(C2B*FCGV["MW"]^2*(-3 + 2*FCGV["SW"]^2) + 
         6*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] - 
       2*Conjugate[USf[4, j1][s2, 2]]*(C2B*FCGV["MW"]^2*FCGV["SW"]^2 - 
         3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/(FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[11, {j2}], -S[11, {j1}]] == 
  {{((I/4)*FCGV["EL"]^2*S2A*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[1], S[2], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((I/4)*FCGV["EL"]^2*S2A*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (CB^2*FCGV["MW"]^2*(-1 + 2*FCGV["SW"]^2) + FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] + Conjugate[USf[2, j1][s2, 2]]*
        (-2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*USf[2, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[3], S[4], S[11, {j2}], -S[11, {j1}]] == 
  {{((I/4)*FCGV["EL"]^2*S2B*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[3], S[4], S[12, {s2, j2}], -S[12, {s1, j1}]] == 
  {{((I/4)*FCGV["EL"]^2*S2B*IndexDelta[j1, j2]*(Conjugate[USf[2, j1][s2, 1]]*
        (CB^2*FCGV["MW"]^2*(-1 + 2*FCGV["SW"]^2) + FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*
        USf[2, j1][s1, 1] + Conjugate[USf[2, j1][s2, 2]]*
        (-2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + FCGV["CW"]^2*Mass[F[2, {j1}]]^2)*USf[2, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[1], S[2], S[13, {s2, j2, o1}], 
   -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*S2A*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(FCGV["MW"]^2*SB^2*(-3 + 4*FCGV["SW"]^2) + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       Conjugate[USf[3, j1][s2, 2]]*(-4*FCGV["MW"]^2*SB^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)}}, C[S[1], S[2], S[14, {s2, j2, o1}], 
   -S[14, {s1, j1, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*S2A*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(CB^2*FCGV["MW"]^2*(-3 + 2*FCGV["SW"]^2) + 
         3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] + 
       Conjugate[USf[4, j1][s2, 2]]*(-2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[3], S[4], S[13, {s2, j2, o1}], 
   -S[13, {s1, j1, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*S2B*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[3, j1][s2, 1]]*(FCGV["MW"]^2*SB^2*(-3 + 4*FCGV["SW"]^2) + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 1] + 
       Conjugate[USf[3, j1][s2, 2]]*(-4*FCGV["MW"]^2*SB^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j1][s1, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)}}, C[S[3], S[4], S[14, {s2, j2, o1}], 
   -S[14, {s1, j1, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*S2B*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      (Conjugate[USf[4, j1][s2, 1]]*(CB^2*FCGV["MW"]^2*(-3 + 2*FCGV["SW"]^2) + 
         3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 1] + 
       Conjugate[USf[4, j1][s2, 2]]*(-2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2 + 
         3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j1][s1, 2]))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[1], S[5], S[13, {s1, j1, o1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[3, j1][s1, 1]]*(-(CA*CB*Mass[F[3, {j1}]]^2) + 
         SB*(CAB*FCGV["MW"]^2*SB + SA*TB^2*Mass[F[4, {j2}]]^2))*USf[4, j2][s2, 1] - 
       2*SB^2*SBA*Conjugate[USf[3, j1][s1, 2]]*Mass[F[3, {j1}]]*
        Mass[F[4, {j2}]]*USf[4, j2][s2, 2]))/(Sqrt[2]*FCGV["MW"]^2*S2B*SB^2*FCGV["SW"]^2)}}, 
 C[S[1], -S[5], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[4, j2][s2, 1]]*(-(CA*CB*Mass[F[3, {j1}]]^2) + 
         SB*(CAB*FCGV["MW"]^2*SB + SA*TB^2*Mass[F[4, {j2}]]^2))*USf[3, j1][s1, 1] - 
       2*SB^2*SBA*Conjugate[USf[4, j2][s2, 2]]*Mass[F[3, {j1}]]*
        Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/(Sqrt[2]*FCGV["MW"]^2*S2B*SB^2*FCGV["SW"]^2)}}, 
 C[S[1], S[6], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[3, j1][s1, 1]]*(CB*FCGV["MW"]^2*SAB*SB - 
         CA*CB*Mass[F[3, {j1}]]^2 - SA*SB*Mass[F[4, {j2}]]^2)*
        USf[4, j2][s2, 1] + 2*CB*CBA*SB*Conjugate[USf[3, j1][s1, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[4, j2][s2, 2]))/
     (Sqrt[2]*CB*FCGV["MW"]^2*S2B*SB*FCGV["SW"]^2)}}, 
 C[S[1], -S[6], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[4, j2][s2, 1]]*(CB*FCGV["MW"]^2*SAB*SB - 
         CA*CB*Mass[F[3, {j1}]]^2 - SA*SB*Mass[F[4, {j2}]]^2)*
        USf[3, j1][s1, 1] + 2*CB*CBA*SB*Conjugate[USf[4, j2][s2, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/
     (Sqrt[2]*CB*FCGV["MW"]^2*S2B*SB*FCGV["SW"]^2)}}, 
 C[S[3], S[5], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{(FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*Conjugate[USf[3, j1][s1, 1]]*
      IndexDelta[o1, o2]*(C2B - Mass[F[3, {j1}]]^2/(FCGV["MW"]^2*TB^2) + 
       (TB^2*Mass[F[4, {j2}]]^2)/FCGV["MW"]^2)*USf[4, j2][s2, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], -S[5], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{-(FCGV["EL"]^2*CKM[j1, j2]*Conjugate[USf[4, j2][s2, 1]]*IndexDelta[o1, o2]*
       (C2B - Mass[F[3, {j1}]]^2/(FCGV["MW"]^2*TB^2) + (TB^2*Mass[F[4, {j2}]]^2)/
         FCGV["MW"]^2)*USf[3, j1][s1, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], S[6], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{(FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[3, j1][s1, 1]]*(-Mass[F[3, {j1}]]^2 + 
         TB*(FCGV["MW"]^2*S2B - TB*Mass[F[4, {j2}]]^2))*USf[4, j2][s2, 1] - 
       2*TB*Conjugate[USf[3, j1][s1, 2]]*Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*
        USf[4, j2][s2, 2]))/(2*Sqrt[2]*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB)}}, 
 C[S[3], -S[6], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{-(FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*(S2B*Conjugate[USf[4, j2][s2, 1]]*
         (-Mass[F[3, {j1}]]^2 + TB*(FCGV["MW"]^2*S2B - TB*Mass[F[4, {j2}]]^2))*
         USf[3, j1][s1, 1] - 2*TB*Conjugate[USf[4, j2][s2, 2]]*
         Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/
     (2*Sqrt[2]*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB)}}, 
 C[S[1], S[5], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{((-I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(CAB + (SA*TB*Mass[F[2, {j1}]]^2)/
        (CB*FCGV["MW"]^2))*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[1], -S[5], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
      (CAB + (SA*TB*Mass[F[2, {j1}]]^2)/(CB*FCGV["MW"]^2)))/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[1], S[6], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{((-I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(SAB - (SA*Mass[F[2, {j1}]]^2)/(CB*FCGV["MW"]^2))*
      USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[1], -S[6], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
      (SAB - (SA*Mass[F[2, {j1}]]^2)/(CB*FCGV["MW"]^2)))/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], S[5], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{(FCGV["EL"]^2*IndexDelta[j1, j2]*(C2B + (TB^2*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2)*
      USf[2, j1][s2, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], -S[5], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{-(FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
       (C2B + (TB^2*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], S[6], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{(FCGV["EL"]^2*IndexDelta[j1, j2]*(S2B - (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2)*
      USf[2, j1][s2, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[3], -S[6], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{-(FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
       (S2B - (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[2], S[5], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (-(S2B*Conjugate[USf[3, j1][s1, 1]]*(CB*SA*Mass[F[3, {j1}]]^2 + 
          SB*(-(FCGV["MW"]^2*SAB*SB) + CA*TB^2*Mass[F[4, {j2}]]^2))*
         USf[4, j2][s2, 1]) - 2*CBA*SB^2*Conjugate[USf[3, j1][s1, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[4, j2][s2, 2]))/
     (Sqrt[2]*FCGV["MW"]^2*S2B*SB^2*FCGV["SW"]^2)}}, 
 C[S[2], -S[5], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((-I/2)*FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*
      (-(S2B*Conjugate[USf[4, j2][s2, 1]]*(CB*SA*Mass[F[3, {j1}]]^2 + 
          SB*(-(FCGV["MW"]^2*SAB*SB) + CA*TB^2*Mass[F[4, {j2}]]^2))*
         USf[3, j1][s1, 1]) - 2*CBA*SB^2*Conjugate[USf[4, j2][s2, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/
     (Sqrt[2]*FCGV["MW"]^2*S2B*SB^2*FCGV["SW"]^2)}}, 
 C[S[2], S[6], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{((I/2)*FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[3, j1][s1, 1]]*(CAB*CB*FCGV["MW"]^2*SB + 
         CB*SA*Mass[F[3, {j1}]]^2 - CA*SB*Mass[F[4, {j2}]]^2)*
        USf[4, j2][s2, 1] + 2*CB*SB*SBA*Conjugate[USf[3, j1][s1, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[4, j2][s2, 2]))/
     (Sqrt[2]*CB*FCGV["MW"]^2*S2B*SB*FCGV["SW"]^2)}}, 
 C[S[2], -S[6], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{((I/2)*FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[4, j2][s2, 1]]*(CAB*CB*FCGV["MW"]^2*SB + 
         CB*SA*Mass[F[3, {j1}]]^2 - CA*SB*Mass[F[4, {j2}]]^2)*
        USf[3, j1][s1, 1] + 2*CB*SB*SBA*Conjugate[USf[4, j2][s2, 2]]*
        Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/
     (Sqrt[2]*CB*FCGV["MW"]^2*S2B*SB*FCGV["SW"]^2)}}, 
 C[S[4], S[5], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{(FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*IndexDelta[o1, o2]*
      (S2B*Conjugate[USf[3, j1][s1, 1]]*(-Mass[F[3, {j1}]]^2 + 
         TB*(FCGV["MW"]^2*S2B - TB*Mass[F[4, {j2}]]^2))*USf[4, j2][s2, 1] + 
       2*TB*Conjugate[USf[3, j1][s1, 2]]*Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*
        USf[4, j2][s2, 2]))/(2*Sqrt[2]*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB)}}, 
 C[S[4], -S[5], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{-(FCGV["EL"]^2*CKM[j1, j2]*IndexDelta[o1, o2]*(S2B*Conjugate[USf[4, j2][s2, 1]]*
         (-Mass[F[3, {j1}]]^2 + TB*(FCGV["MW"]^2*S2B - TB*Mass[F[4, {j2}]]^2))*
         USf[3, j1][s1, 1] + 2*TB*Conjugate[USf[4, j2][s2, 2]]*
         Mass[F[3, {j1}]]*Mass[F[4, {j2}]]*USf[3, j1][s1, 2]))/
     (2*Sqrt[2]*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB)}}, 
 C[S[4], S[6], S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}]] == 
  {{-(FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*Conjugate[USf[3, j1][s1, 1]]*
       IndexDelta[o1, o2]*(C2B*FCGV["MW"]^2 + Mass[F[3, {j1}]]^2 - 
        Mass[F[4, {j2}]]^2)*USf[4, j2][s2, 1])/(2*Sqrt[2]*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[4], -S[6], S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}]] == 
  {{(FCGV["EL"]^2*CKM[j1, j2]*Conjugate[USf[4, j2][s2, 1]]*IndexDelta[o1, o2]*
      (C2B*FCGV["MW"]^2 + Mass[F[3, {j1}]]^2 - Mass[F[4, {j2}]]^2)*USf[3, j1][s1, 1])/
     (2*Sqrt[2]*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[2], S[5], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{((-I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(SAB - (CA*TB*Mass[F[2, {j1}]]^2)/
        (CB*FCGV["MW"]^2))*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[2], -S[5], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
      (SAB - (CA*TB*Mass[F[2, {j1}]]^2)/(CB*FCGV["MW"]^2)))/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[2], S[6], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{((-I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(-CAB + (CA*Mass[F[2, {j1}]]^2)/
        (CB*FCGV["MW"]^2))*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[2], -S[6], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
      (-CAB + (CA*Mass[F[2, {j1}]]^2)/(CB*FCGV["MW"]^2)))/(Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[4], S[5], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{(FCGV["EL"]^2*IndexDelta[j1, j2]*(S2B - (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2)*
      USf[2, j1][s2, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[4], -S[5], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{-(FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
       (S2B - (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[4], S[6], S[11, {j1}], -S[12, {s2, j2}]] == 
  {{(FCGV["EL"]^2*IndexDelta[j1, j2]*(-C2B + Mass[F[2, {j1}]]^2/FCGV["MW"]^2)*
      USf[2, j1][s2, 1])/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[4], -S[6], S[12, {s2, j2}], -S[11, {j1}]] == 
  {{-(FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2]*
       (-C2B + Mass[F[2, {j1}]]^2/FCGV["MW"]^2))/(2*Sqrt[2]*FCGV["SW"]^2)}}, 
 C[S[5], -S[5], S[11, {j1}], -S[11, {j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*((C2B*(-2 + FCGV["CW"]^(-2)))/2 - 
       (TB^2*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/FCGV["SW"]^2}}, 
 C[S[5], -S[6], S[11, {j1}], -S[11, {j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(((-2 + FCGV["CW"]^(-2))*S2B)/2 + 
       (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/FCGV["SW"]^2}}, 
 C[S[6], -S[5], S[11, {j1}], -S[11, {j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(((-2 + FCGV["CW"]^(-2))*S2B)/2 + 
       (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2))/FCGV["SW"]^2}}, 
 C[S[5], -S[5], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(C2B*FCGV["MW"]^2*Conjugate[USf[2, j1][s1, 1]]*
        USf[2, j1][s2, 1] - 2*Conjugate[USf[2, j1][s1, 2]]*
        (C2B*FCGV["MW"]^2*FCGV["SW"]^2 + FCGV["CW"]^2*TB^2*Mass[F[2, {j1}]]^2)*USf[2, j1][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[5], -S[6], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(S2B*(1 + (-1/2 + FCGV["SW"]^2)/FCGV["CW"]^2)*
        Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
       Conjugate[USf[2, j1][s1, 2]]*(-((S2B*FCGV["SW"]^2)/FCGV["CW"]^2) + 
         (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2)*USf[2, j1][s2, 2]))/FCGV["SW"]^2}}, 
 C[S[6], -S[5], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(S2B*(1 + (-1/2 + FCGV["SW"]^2)/FCGV["CW"]^2)*
        Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
       Conjugate[USf[2, j1][s1, 2]]*(-((S2B*FCGV["SW"]^2)/FCGV["CW"]^2) + 
         (TB*Mass[F[2, {j1}]]^2)/FCGV["MW"]^2)*USf[2, j1][s2, 2]))/FCGV["SW"]^2}}, 
 C[S[5], -S[5], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(TB^2*Conjugate[USf[3, j1][s1, 1]]*
        (C2B*(1 + 2*FCGV["CW"]^2)*FCGV["MW"]^2*IndexDelta[j1, j2] + 6*FCGV["CW"]^2*TB^2*
          IndexSum[CKM[j2, gn]*Conjugate[CKM[j1, gn]]*Mass[F[4, {gn}]]^2, 
           {gn, 3}])*USf[3, j2][s2, 1] + 2*Conjugate[USf[3, j1][s1, 2]]*
        IndexDelta[j1, j2]*(-2*C2B*FCGV["MW"]^2*FCGV["SW"]^2*TB^2 + 
         3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB^2)}}, C[S[5], -S[6], S[13, {s1, j1, o1}], 
   -S[13, {s2, j2, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(TB*Conjugate[USf[3, j1][s1, 1]]*
        ((1 + 2*FCGV["CW"]^2)*FCGV["MW"]^2*S2B*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*TB*IndexSum[CKM[j2, gn]*Conjugate[CKM[j1, gn]]*
            Mass[F[4, {gn}]]^2, {gn, 3}])*USf[3, j2][s2, 1] + 
       2*Conjugate[USf[3, j1][s1, 2]]*IndexDelta[j1, j2]*
        (-2*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB + 3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB)}}, C[S[6], -S[5], S[13, {s1, j1, o1}], 
   -S[13, {s2, j2, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(TB*Conjugate[USf[3, j1][s1, 1]]*
        ((1 + 2*FCGV["CW"]^2)*FCGV["MW"]^2*S2B*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*TB*IndexSum[CKM[j2, gn]*Conjugate[CKM[j1, gn]]*
            Mass[F[4, {gn}]]^2, {gn, 3}])*USf[3, j2][s2, 1] + 
       2*Conjugate[USf[3, j1][s1, 2]]*IndexDelta[j1, j2]*
        (-2*FCGV["MW"]^2*S2B*FCGV["SW"]^2*TB + 3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB)}}, C[S[5], -S[5], S[14, {s1, j1, o1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(Conjugate[USf[4, j1][s1, 1]]*
        (C2B*(-1 + 4*FCGV["CW"]^2)*FCGV["MW"]^2*TB^2*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*IndexSum[CKM[gn, j1]*Conjugate[CKM[gn, j2]]*
            Mass[F[3, {gn}]]^2, {gn, 3}])*USf[4, j2][s2, 1] - 
       2*TB^2*Conjugate[USf[4, j1][s1, 2]]*IndexDelta[j1, j2]*
        (C2B*FCGV["MW"]^2*FCGV["SW"]^2 + 3*FCGV["CW"]^2*TB^2*Mass[F[4, {j1}]]^2)*USf[4, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB^2)}}, C[S[5], -S[6], S[14, {s1, j1, o1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(Conjugate[USf[4, j1][s1, 1]]*
        ((-1 + 4*FCGV["CW"]^2)*FCGV["MW"]^2*S2B*TB*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*IndexSum[CKM[gn, j1]*Conjugate[CKM[gn, j2]]*
            Mass[F[3, {gn}]]^2, {gn, 3}])*USf[4, j2][s2, 1] + 
       2*TB*Conjugate[USf[4, j1][s1, 2]]*IndexDelta[j1, j2]*
        (-(FCGV["MW"]^2*S2B*FCGV["SW"]^2) + 3*FCGV["CW"]^2*TB*Mass[F[4, {j1}]]^2)*USf[4, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB)}}, C[S[6], -S[5], S[14, {s1, j1, o1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(Conjugate[USf[4, j1][s1, 1]]*
        ((-1 + 4*FCGV["CW"]^2)*FCGV["MW"]^2*S2B*TB*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*IndexSum[CKM[gn, j1]*Conjugate[CKM[gn, j2]]*
            Mass[F[3, {gn}]]^2, {gn, 3}])*USf[4, j2][s2, 1] + 
       2*TB*Conjugate[USf[4, j1][s1, 2]]*IndexDelta[j1, j2]*
        (-(FCGV["MW"]^2*S2B*FCGV["SW"]^2) + 3*FCGV["CW"]^2*TB*Mass[F[4, {j1}]]^2)*USf[4, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2*TB)}}, C[S[6], -S[6], S[11, {j1}], -S[11, {j2}]] == 
  {{((I/4)*FCGV["EL"]^2*IndexDelta[j1, j2]*(C2B*(-1 + 2*FCGV["CW"]^2)*FCGV["MW"]^2 - 
       2*FCGV["CW"]^2*Mass[F[2, {j1}]]^2))/(FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[6], -S[6], S[12, {s1, j1}], -S[12, {s2, j2}]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*(-(C2B*(1 + (-1/2 + FCGV["SW"]^2)/FCGV["CW"]^2)*
         Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1]) + 
       Conjugate[USf[2, j1][s1, 2]]*((C2B*FCGV["SW"]^2)/FCGV["CW"]^2 - Mass[F[2, {j1}]]^2/
          FCGV["MW"]^2)*USf[2, j1][s2, 2]))/FCGV["SW"]^2}}, 
 C[S[6], -S[6], S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(Conjugate[USf[3, j1][s1, 1]]*
        (C2B*(1 + 2*FCGV["CW"]^2)*FCGV["MW"]^2*IndexDelta[j1, j2] - 
         6*FCGV["CW"]^2*IndexSum[CKM[j2, gn]*Conjugate[CKM[j1, gn]]*
            Mass[F[4, {gn}]]^2, {gn, 3}])*USf[3, j2][s2, 1] - 
       2*Conjugate[USf[3, j1][s1, 2]]*IndexDelta[j1, j2]*
        (2*C2B*FCGV["MW"]^2*FCGV["SW"]^2 + 3*FCGV["CW"]^2*Mass[F[3, {j1}]]^2)*USf[3, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[6], -S[6], S[14, {s1, j1, o1}], 
   -S[14, {s2, j2, o2}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[o1, o2]*(Conjugate[USf[4, j1][s1, 1]]*
        (C2B*(-1 + 4*FCGV["CW"]^2)*FCGV["MW"]^2*IndexDelta[j1, j2] + 
         6*FCGV["CW"]^2*IndexSum[CKM[gn, j1]*Conjugate[CKM[gn, j2]]*
            Mass[F[3, {gn}]]^2, {gn, 3}])*USf[4, j2][s2, 1] - 
       2*Conjugate[USf[4, j1][s1, 2]]*IndexDelta[j1, j2]*
        (C2B*FCGV["MW"]^2*FCGV["SW"]^2 - 3*FCGV["CW"]^2*Mass[F[4, {j1}]]^2)*USf[4, j2][s2, 2]))/
     (FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[11, {j1}], -S[11, {j2}], V[2], V[2]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2])/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[1], V[1]] == 
  {{(2*I)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[s1, s2]}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[1], V[2]] == 
  {{((-I)*FCGV["EL"]^2*$HKSign*IndexDelta[j1, j2]*
      ((-1 + 2*FCGV["SW"]^2)*Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
       2*FCGV["SW"]^2*Conjugate[USf[2, j1][s1, 2]]*USf[2, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[2], V[2]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2]*
      ((1 - 2*FCGV["SW"]^2)^2*Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
       4*FCGV["SW"]^4*Conjugate[USf[2, j1][s1, 2]]*USf[2, j1][s2, 2]))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[1], V[1]] == 
  {{((8*I)/9)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
     IndexDelta[s1, s2]}}, C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[1], 
   V[2]] == {{(((-2*I)/9)*FCGV["EL"]^2*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((-3 + 4*FCGV["SW"]^2)*Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s2, 1] + 
       4*FCGV["SW"]^2*Conjugate[USf[3, j1][s1, 2]]*USf[3, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], V[2], V[2]] == 
  {{((I/18)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((3 - 4*FCGV["SW"]^2)^2*Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s2, 1] + 
       16*FCGV["SW"]^4*Conjugate[USf[3, j1][s1, 2]]*USf[3, j1][s2, 2]))/
     (FCGV["CW"]^2*FCGV["SW"]^2)}}, C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[1], 
   V[1]] == {{((2*I)/9)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
     IndexDelta[s1, s2]}}, C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[1], 
   V[2]] == {{((-I/9)*FCGV["EL"]^2*$HKSign*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((-3 + 2*FCGV["SW"]^2)*Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] + 
       2*FCGV["SW"]^2*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]))/(FCGV["CW"]*FCGV["SW"])}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[2], V[2]] == 
  {{((I/18)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[o1, o2]*
      ((3 - 2*FCGV["SW"]^2)^2*Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] + 
       4*FCGV["SW"]^4*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[1], V[3]] == 
  {{((I/3)*FCGV["EL"]^2*$HKSign*Conjugate[CKM[j1, j2]]*Conjugate[USf[3, j1][s1, 1]]*
      IndexDelta[o1, o2]*USf[4, j2][s2, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}], V[1], -V[3]] == 
  {{((I/3)*FCGV["EL"]^2*$HKSign*CKM[j1, j2]*Conjugate[USf[4, j2][s2, 1]]*
      IndexDelta[o1, o2]*USf[3, j1][s1, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[11, {j1}], -S[12, {s2, j2}], V[1], V[3]] == 
  {{((-I)*FCGV["EL"]^2*$HKSign*IndexDelta[j1, j2]*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["SW"])}}, 
 C[S[12, {s2, j2}], -S[11, {j1}], V[1], -V[3]] == 
  {{((-I)*FCGV["EL"]^2*$HKSign*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2])/
     (Sqrt[2]*FCGV["SW"])}}, C[S[13, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[2], 
   V[3]] == {{((-I/3)*FCGV["EL"]^2*Conjugate[CKM[j1, j2]]*
      Conjugate[USf[3, j1][s1, 1]]*IndexDelta[o1, o2]*USf[4, j2][s2, 1])/
     (Sqrt[2]*FCGV["CW"])}}, C[S[14, {s2, j2, o1}], -S[13, {s1, j1, o2}], V[2], 
   -V[3]] == {{((-I/3)*FCGV["EL"]^2*CKM[j1, j2]*Conjugate[USf[4, j2][s2, 1]]*
      IndexDelta[o1, o2]*USf[3, j1][s1, 1])/(Sqrt[2]*FCGV["CW"])}}, 
 C[S[11, {j1}], -S[12, {s2, j2}], V[2], V[3]] == 
  {{(I*FCGV["EL"]^2*IndexDelta[j1, j2]*USf[2, j1][s2, 1])/(Sqrt[2]*FCGV["CW"])}}, 
 C[S[12, {s2, j2}], -S[11, {j1}], V[2], -V[3]] == 
  {{(I*FCGV["EL"]^2*Conjugate[USf[2, j1][s2, 1]]*IndexDelta[j1, j2])/(Sqrt[2]*FCGV["CW"])}}, 
 C[S[11, {j1}], -S[11, {j2}], V[3], -V[3]] == 
  {{((I/2)*FCGV["EL"]^2*IndexDelta[j1, j2])/FCGV["SW"]^2}}, 
 C[S[12, {s1, j1}], -S[12, {s2, j2}], V[3], -V[3]] == 
  {{((I/2)*FCGV["EL"]^2*Conjugate[USf[2, j1][s1, 1]]*IndexDelta[j1, j2]*
      USf[2, j1][s2, 1])/FCGV["SW"]^2}}, C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], 
   V[3], -V[3]] == {{((I/2)*FCGV["EL"]^2*Conjugate[USf[3, j1][s1, 1]]*
      IndexDelta[j1, j2]*IndexDelta[o1, o2]*USf[3, j1][s2, 1])/FCGV["SW"]^2}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], V[3], -V[3]] == 
  {{((I/2)*FCGV["EL"]^2*Conjugate[USf[4, j1][s1, 1]]*IndexDelta[j1, j2]*
      IndexDelta[o1, o2]*USf[4, j1][s2, 1])/FCGV["SW"]^2}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], S[14, {s3, j3, o3}], 
   -S[14, {s4, j4, o4}]] == 
  {{IndexDelta[j1, j4]*IndexDelta[j2, j3]*((-I)*FAGS^2*SUNTSum[o2, o3, o4, o1]*
        (Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s4, 1] - 
         Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s4, 2])*
        (Conjugate[USf[4, j2][s3, 1]]*USf[4, j2][s2, 1] - 
         Conjugate[USf[4, j2][s3, 2]]*USf[4, j2][s2, 2]) - 
       ((I/36)*FCGV["EL"]^2*IndexDelta[o1, o4]*IndexDelta[o2, o3]*
         (Conjugate[USf[4, j1][s1, 1]]*(CB^2*(1 + 8*FCGV["CW"]^2)*FCGV["MW"]^2*
             Conjugate[USf[4, j2][s3, 1]]*USf[4, j1][s4, 1]*
             USf[4, j2][s2, 1] + 2*Conjugate[USf[4, j2][s3, 2]]*
             (9*FCGV["CW"]^2*MQD[j1]*MQD[j2]*USf[4, j1][s4, 2]*USf[4, j2][s2, 1] + 
              CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[4, j1][s4, 1]*USf[4, j2][s2, 2])) + 
          2*Conjugate[USf[4, j1][s1, 2]]*(2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2*
             Conjugate[USf[4, j2][s3, 2]]*USf[4, j1][s4, 2]*
             USf[4, j2][s2, 2] + Conjugate[USf[4, j2][s3, 1]]*
             (CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[4, j1][s4, 2]*USf[4, j2][s2, 1] + 
              9*FCGV["CW"]^2*MQD[j1]*MQD[j2]*USf[4, j1][s4, 1]*USf[4, j2][s2, 2]))))/
        (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)) + IndexDelta[j1, j2]*IndexDelta[j3, j4]*
      ((-I)*FAGS^2*SUNTSum[o2, o1, o4, o3]*(Conjugate[USf[4, j1][s1, 1]]*
          USf[4, j1][s2, 1] - Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2])*
        (Conjugate[USf[4, j3][s3, 1]]*USf[4, j3][s4, 1] - 
         Conjugate[USf[4, j3][s3, 2]]*USf[4, j3][s4, 2]) - 
       ((I/36)*FCGV["EL"]^2*IndexDelta[o1, o2]*IndexDelta[o3, o4]*
         (Conjugate[USf[4, j1][s1, 1]]*(CB^2*(1 + 8*FCGV["CW"]^2)*FCGV["MW"]^2*
             Conjugate[USf[4, j3][s3, 1]]*USf[4, j1][s2, 1]*
             USf[4, j3][s4, 1] + 2*Conjugate[USf[4, j3][s3, 2]]*
             (9*FCGV["CW"]^2*MQD[j1]*MQD[j3]*USf[4, j1][s2, 2]*USf[4, j3][s4, 1] + 
              CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[4, j1][s2, 1]*USf[4, j3][s4, 2])) + 
          2*Conjugate[USf[4, j1][s1, 2]]*(2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2*
             Conjugate[USf[4, j3][s3, 2]]*USf[4, j1][s2, 2]*
             USf[4, j3][s4, 2] + Conjugate[USf[4, j3][s3, 1]]*
             (CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[4, j1][s2, 2]*USf[4, j3][s4, 1] + 
              9*FCGV["CW"]^2*MQD[j1]*MQD[j3]*USf[4, j1][s2, 1]*USf[4, j3][s4, 2]))))/
        (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2))}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], S[12, {s3, j3}], 
   -S[12, {s4, j4}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[j3, j4]*IndexDelta[o1, o2]*
      (Conjugate[USf[2, j3][s3, 1]]*(CB^2*FCGV["MW"]^2*(3*FCGV["CW"]^2 - FCGV["SW"]^2)*
          Conjugate[USf[4, j1][s1, 1]]*USf[2, j3][s4, 1]*USf[4, j1][s2, 1] + 
         2*Conjugate[USf[4, j1][s1, 2]]*(3*FCGV["CW"]^2*MLE[j3]*MQD[j1]*
            USf[2, j3][s4, 2]*USf[4, j1][s2, 1] - CB^2*FCGV["MW"]^2*FCGV["SW"]^2*
            USf[2, j3][s4, 1]*USf[4, j1][s2, 2])) + 
       2*Conjugate[USf[2, j3][s3, 2]]*(2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2*
          Conjugate[USf[4, j1][s1, 2]]*USf[2, j3][s4, 2]*USf[4, j1][s2, 2] + 
         Conjugate[USf[4, j1][s1, 1]]*(CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[2, j3][s4, 2]*
            USf[4, j1][s2, 1] + 3*FCGV["CW"]^2*MLE[j3]*MQD[j1]*USf[2, j3][s4, 1]*
            USf[4, j1][s2, 2]))))/(CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], S[11, {j3}], -S[11, {j4}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[j3, j4]*IndexDelta[o1, o2]*
      ((1 + 2*FCGV["CW"]^2)*Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] + 
       2*FCGV["SW"]^2*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[14, {s1, j1, o1}], -S[14, {s2, j2, o2}], S[13, {s3, j3, o3}], 
   -S[13, {s4, j4, o4}]] == 
  {{IndexDelta[j1, j2]*IndexDelta[j3, j4]*((-I)*FAGS^2*SUNTSum[o2, o1, o4, o3]*
        (Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1] - 
         Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2])*
        (Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] - 
         Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]) + 
       ((I/36)*FCGV["EL"]^2*IndexDelta[o1, o2]*IndexDelta[o3, o4]*
         (4*FCGV["SW"]^2*Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2]*
           (Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] + 
            2*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2]) + 
          Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1]*
           ((9*FCGV["CW"]^2 - FCGV["SW"]^2)*Conjugate[USf[4, j1][s1, 1]]*USf[4, j1][s2, 1] - 
            2*FCGV["SW"]^2*Conjugate[USf[4, j1][s1, 2]]*USf[4, j1][s2, 2])))/
        (FCGV["CW"]^2*FCGV["SW"]^2)) - ((I/2)*FCGV["EL"]^2*CKM[j4, j1]*Conjugate[CKM[j3, j2]]*
       IndexDelta[o1, o4]*IndexDelta[o2, o3]*
       (CB^2*Conjugate[USf[3, j3][s3, 2]]*Conjugate[USf[4, j1][s1, 1]]*
         MQU[j3]*MQU[j4]*USf[3, j4][s4, 2]*USf[4, j2][s2, 1] + 
        SB^2*Conjugate[USf[3, j3][s3, 1]]*USf[3, j4][s4, 1]*
         (CB^2*FCGV["MW"]^2*Conjugate[USf[4, j1][s1, 1]]*USf[4, j2][s2, 1] + 
          Conjugate[USf[4, j1][s1, 2]]*MQD[j1]*MQD[j2]*USf[4, j2][s2, 2])))/
      (CB^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)}}, C[S[14, {s1, j1, o1}], -S[12, {s2, j2}], 
   S[11, {j3}], -S[13, {s4, j4, o4}]] == 
  {{((-I/2)*FCGV["EL"]^2*CKM[j4, j1]*IndexDelta[j2, j3]*IndexDelta[o1, o4]*
      (CB^2*FCGV["MW"]^2*Conjugate[USf[4, j1][s1, 1]]*USf[2, j2][s2, 1] + 
       Conjugate[USf[4, j1][s1, 2]]*MLE[j2]*MQD[j1]*USf[2, j2][s2, 2])*
      USf[3, j4][s4, 1])/(CB^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, 
 C[S[12, {s1, j1}], -S[14, {s2, j2, o2}], S[13, {s3, j3, o3}], 
   -S[11, {j4}]] == 
  {{((-I/2)*FCGV["EL"]^2*Conjugate[CKM[j3, j2]]*Conjugate[USf[3, j3][s3, 1]]*
      IndexDelta[j1, j4]*IndexDelta[o2, o3]*
      (CB^2*FCGV["MW"]^2*Conjugate[USf[2, j1][s1, 1]]*USf[4, j2][s2, 1] + 
       Conjugate[USf[2, j1][s1, 2]]*MLE[j1]*MQD[j2]*USf[4, j2][s2, 2]))/
     (CB^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[12, {s1, j1}], -S[12, {s2, j2}], 
   S[12, {s3, j3}], -S[12, {s4, j4}]] == 
  {{((-I/4)*FCGV["EL"]^2*(Conjugate[USf[2, j1][s1, 1]]*
        (CB^2*FCGV["MW"]^2*Conjugate[USf[2, j2][s3, 1]]*IndexDelta[j1, j4]*
          IndexDelta[j2, j3]*USf[2, j1][s4, 1]*USf[2, j2][s2, 1] + 
         2*Conjugate[USf[2, j2][s3, 2]]*IndexDelta[j1, j4]*IndexDelta[j2, j3]*
          (FCGV["CW"]^2*MLE[j1]*MLE[j2]*USf[2, j1][s4, 2]*USf[2, j2][s2, 1] - 
           CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[2, j1][s4, 1]*USf[2, j2][s2, 2]) + 
         IndexDelta[j1, j2]*IndexDelta[j3, j4]*
          (CB^2*FCGV["MW"]^2*Conjugate[USf[2, j3][s3, 1]]*USf[2, j1][s2, 1]*
            USf[2, j3][s4, 1] + 2*Conjugate[USf[2, j3][s3, 2]]*
            (FCGV["CW"]^2*MLE[j1]*MLE[j3]*USf[2, j1][s2, 2]*USf[2, j3][s4, 1] - 
             CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[2, j1][s2, 1]*USf[2, j3][s4, 2]))) + 
       2*Conjugate[USf[2, j1][s1, 2]]*(2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2*
          Conjugate[USf[2, j2][s3, 2]]*IndexDelta[j1, j4]*IndexDelta[j2, j3]*
          USf[2, j1][s4, 2]*USf[2, j2][s2, 2] + Conjugate[USf[2, j2][s3, 1]]*
          IndexDelta[j1, j4]*IndexDelta[j2, j3]*
          (-(CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[2, j1][s4, 2]*USf[2, j2][s2, 1]) + 
           FCGV["CW"]^2*MLE[j1]*MLE[j2]*USf[2, j1][s4, 1]*USf[2, j2][s2, 2]) + 
         IndexDelta[j1, j2]*IndexDelta[j3, j4]*
          (2*CB^2*FCGV["MW"]^2*FCGV["SW"]^2*Conjugate[USf[2, j3][s3, 2]]*USf[2, j1][s2, 2]*
            USf[2, j3][s4, 2] + Conjugate[USf[2, j3][s3, 1]]*
            (-(CB^2*FCGV["MW"]^2*FCGV["SW"]^2*USf[2, j1][s2, 2]*USf[2, j3][s4, 1]) + 
             FCGV["CW"]^2*MLE[j1]*MLE[j3]*USf[2, j1][s2, 1]*USf[2, j3][s4, 2])))))/
     (CB^2*FCGV["CW"]^2*FCGV["MW"]^2*FCGV["SW"]^2)}}, C[S[12, {s1, j1}], -S[12, {s2, j2}], 
   S[11, {j3}], -S[11, {j4}]] == 
  {{((I/4)*FCGV["EL"]^2*((IndexDelta[j1, j2]*IndexDelta[j3, j4]*
         ((FCGV["CW"]^2 - FCGV["SW"]^2)*Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1] + 
          2*FCGV["SW"]^2*Conjugate[USf[2, j1][s1, 2]]*USf[2, j1][s2, 2]))/FCGV["CW"]^2 - 
       (2*IndexDelta[j1, j4]*IndexDelta[j2, j3]*
         (CB^2*FCGV["MW"]^2*Conjugate[USf[2, j1][s1, 1]]*USf[2, j2][s2, 1] + 
          Conjugate[USf[2, j1][s1, 2]]*MLE[j1]*MLE[j2]*USf[2, j2][s2, 2]))/
        (CB^2*FCGV["MW"]^2)))/FCGV["SW"]^2}}, C[S[12, {s1, j1}], -S[12, {s2, j2}], 
   S[13, {s3, j3, o3}], -S[13, {s4, j4, o4}]] == 
  {{((I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[j3, j4]*IndexDelta[o3, o4]*
      (-2*FCGV["SW"]^2*Conjugate[USf[2, j1][s1, 2]]*USf[2, j1][s2, 2]*
        (Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1] - 
         4*Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2]) + 
       Conjugate[USf[2, j1][s1, 1]]*USf[2, j1][s2, 1]*
        ((1 + 2*FCGV["CW"]^2)*Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1] - 
         4*FCGV["SW"]^2*Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2])))/
     (FCGV["CW"]^2*FCGV["SW"]^2)}}, C[S[11, {j1}], -S[11, {j2}], S[11, {j3}], 
   -S[11, {j4}]] == 
  {{((-I/4)*FCGV["EL"]^2*(IndexDelta[j1, j4]*IndexDelta[j2, j3] + 
       IndexDelta[j1, j2]*IndexDelta[j3, j4]))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[11, {j1}], -S[11, {j2}], S[13, {s3, j3, o3}], -S[13, {s4, j4, o4}]] == 
  {{((-I/12)*FCGV["EL"]^2*IndexDelta[j1, j2]*IndexDelta[j3, j4]*IndexDelta[o3, o4]*
      ((3*FCGV["CW"]^2 - FCGV["SW"]^2)*Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1] + 
       4*FCGV["SW"]^2*Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2]))/(FCGV["CW"]^2*FCGV["SW"]^2)}}, 
 C[S[13, {s1, j1, o1}], -S[13, {s2, j2, o2}], S[13, {s3, j3, o3}], 
   -S[13, {s4, j4, o4}]] == 
  {{IndexDelta[j1, j4]*IndexDelta[j2, j3]*((-I)*FAGS^2*SUNTSum[o2, o3, o4, o1]*
        (Conjugate[USf[3, j1][s1, 1]]*USf[3, j1][s4, 1] - 
         Conjugate[USf[3, j1][s1, 2]]*USf[3, j1][s4, 2])*
        (Conjugate[USf[3, j2][s3, 1]]*USf[3, j2][s2, 1] - 
         Conjugate[USf[3, j2][s3, 2]]*USf[3, j2][s2, 2]) - 
       ((I/36)*FCGV["EL"]^2*IndexDelta[o1, o4]*IndexDelta[o2, o3]*
         (Conjugate[USf[3, j1][s1, 1]]*((1 + 8*FCGV["CW"]^2)*FCGV["MW"]^2*SB^2*
             Conjugate[USf[3, j2][s3, 1]]*USf[3, j1][s4, 1]*
             USf[3, j2][s2, 1] + 2*Conjugate[USf[3, j2][s3, 2]]*
             (9*FCGV["CW"]^2*MQU[j1]*MQU[j2]*USf[3, j1][s4, 2]*USf[3, j2][s2, 1] - 
              2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*USf[3, j1][s4, 1]*USf[3, j2][s2, 2])) + 
          2*Conjugate[USf[3, j1][s1, 2]]*(8*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*
             Conjugate[USf[3, j2][s3, 2]]*USf[3, j1][s4, 2]*
             USf[3, j2][s2, 2] + Conjugate[USf[3, j2][s3, 1]]*
             (-2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*USf[3, j1][s4, 2]*USf[3, j2][s2, 1] + 
              9*FCGV["CW"]^2*MQU[j1]*MQU[j2]*USf[3, j1][s4, 1]*USf[3, j2][s2, 2]))))/
        (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2)) + IndexDelta[j1, j2]*IndexDelta[j3, j4]*
      ((-I)*FAGS^2*SUNTSum[o2, o1, o4, o3]*(Conjugate[USf[3, j1][s1, 1]]*
          USf[3, j1][s2, 1] - Conjugate[USf[3, j1][s1, 2]]*USf[3, j1][s2, 2])*
        (Conjugate[USf[3, j3][s3, 1]]*USf[3, j3][s4, 1] - 
         Conjugate[USf[3, j3][s3, 2]]*USf[3, j3][s4, 2]) - 
       ((I/36)*FCGV["EL"]^2*IndexDelta[o1, o2]*IndexDelta[o3, o4]*
         (Conjugate[USf[3, j1][s1, 1]]*((1 + 8*FCGV["CW"]^2)*FCGV["MW"]^2*SB^2*
             Conjugate[USf[3, j3][s3, 1]]*USf[3, j1][s2, 1]*
             USf[3, j3][s4, 1] + 2*Conjugate[USf[3, j3][s3, 2]]*
             (9*FCGV["CW"]^2*MQU[j1]*MQU[j3]*USf[3, j1][s2, 2]*USf[3, j3][s4, 1] - 
              2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*USf[3, j1][s2, 1]*USf[3, j3][s4, 2])) + 
          2*Conjugate[USf[3, j1][s1, 2]]*(8*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*
             Conjugate[USf[3, j3][s3, 2]]*USf[3, j1][s2, 2]*
             USf[3, j3][s4, 2] + Conjugate[USf[3, j3][s3, 1]]*
             (-2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2*USf[3, j1][s2, 2]*USf[3, j3][s4, 1] + 
              9*FCGV["CW"]^2*MQU[j1]*MQU[j3]*USf[3, j1][s2, 1]*USf[3, j3][s4, 2]))))/
        (FCGV["CW"]^2*FCGV["MW"]^2*SB^2*FCGV["SW"]^2))}}}


(* The following definitions of renormalization constants are
   for the on-shell renormalization of the MSSM in a scheme
   similar to A. Denner, Fortschr. d. Physik, 41 (1993) 4.

   The renormalization constants are not directly used by
   FeynArts, and hence do not restrict the generation of diagrams
   and amplitudes in any way. *)

Clear[RenConst]

RenConst[ dMf1[type_, j1_] ] := MassRC[F[type, {j1}]]

RenConst[ dZfL1[type_, j1_, j2_] ] :=
  FieldRC[F[type, {j1}], F[type, {j2}]][[1]]

RenConst[ dZfR1[type_, j1_, j2_] ] :=
  FieldRC[F[type, {j1}], F[type, {j2}]][[2]]

RenConst[ dMZsq1 ] := MassRC[V[2]]

RenConst[ dMWsq1 ] := MassRC[V[3]]

RenConst[ dMHsq1 ] := MassRC[S[1]]

RenConst[ dZAA1 ] := FieldRC[V[1]]

RenConst[ dZAZ1 ] := FieldRC[V[1], V[2]]

RenConst[ dZZA1 ] := FieldRC[V[2], V[1]]

RenConst[ dZZZ1 ] := FieldRC[V[2]]

RenConst[ dZG01 ] := FieldRC[S[2]]

RenConst[ dZW1 ] := FieldRC[V[3]]

RenConst[ dZGp1 ] := FieldRC[S[3]]

RenConst[ dZH1 ] := FieldRC[S[1]]

RenConst[ dTH1 ] := TadpoleRC[S[1]]

RenConst[ dSW1 ] := -$HKSign FCGV["CW"]^2/FCGV["SW"]/2 (dMZsq1/FCGV["MZ"]^2 - dMWsq1/FCGV["MW"]^2)

RenConst[ dZe1 ] := -1/2 (dZAA1 - $HKSign FCGV["SW"]/FCGV["CW"] dZZA1)

