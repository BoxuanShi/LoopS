(* Patched for use with FeynCalc *)
(*
	QED.gen
		Generic model file for QED
		(simplex version of Lorentz.gen)
		by A. Denner, H. Eck, O. Hahn, S. Kueblbeck
		last modified 25 Mar 13 by Thomas Hahn
*)


	(* Kinematic indices are `transported' along a propagator line.
	   KinematicIndices[X] = {Name} means that the generic field X
	   will carry an index Index[Name, i] along the line:  
	   X[ n, {m..}, p, {Index[Name, i]} -> {Index[Name, i + 1]} ] *)

KinematicIndices[ F ] = {};
KinematicIndices[ V ] = {Lorentz}

IndexStyle[ Index[Lorentz, i_Integer] ] := Greek[i + 11]

Attributes[ FAMetricTensor ] = Attributes[ FAScalarProduct ] = {Orderless}


FAFourVector/: -FAFourVector[ mom_, mu___ ] := FAFourVector[Expand[-mom], mu]

FAFourVector[ 0, ___ ] = 0


M$GenericPropagators = {

	(* general fermion propagator: *)

  AnalyticalPropagator[External][ s F[i, mom] ] == 
    FANonCommutative[
      FADiracSpinor[-mom, Mass[F[i]], Sequence@@ Drop[{i}, 1]] ],

  AnalyticalPropagator[Internal][ s F[i, mom] ] ==
    FANonCommutative[ FADiracSlash[-mom] + Mass[F[i]] ] *
      I FAPropagatorDenominator[mom, Mass[F[i]]], 

	(* general vector boson propagator: *)

  AnalyticalPropagator[External][ s V[i, mom, {li2}] ] ==
    FAPolarizationVector[V[i], mom, li2],

  AnalyticalPropagator[Internal][ s V[i, mom, {li1} -> {li2}] ] ==
    -I FAPropagatorDenominator[mom, Mass[V[i]]] *
      (FAMetricTensor[li1, li2] - (1 - FAGaugeXi[V[i]]) *
         FAFourVector[mom, li1] FAFourVector[mom, li2] *
         FAPropagatorDenominator[mom, Sqrt[FAGaugeXi[V[i]]] Mass[V[i]]])
}

	(* Definition of the generic couplings.
	   The couplings must be defined as a Dot product of the (generic)
	   coupling vector G[+/-][ field1, field2, .. ] and the
	   kinematical vector Gamma = {Gamma1, Gamma2, ...}.
	   The kinematical vector must have the following properties:
	   a) the entries of Gamma must close under permutation of the
	      fields, i.e. under permutation of the momenta and
	      kinematical indices. One exception is allowed: if the
	      elements of Gamma only change their signs under certain
	      permutations (e.g. Gamma1 = mom1 - mom2), a coupling vector
	      G[-] can be used.
	      This leads to the following behaviour during the
	      construction of the classes couplings: if a permuted
	      coupling was found and the corresponding permutation doesn't
	      resolve the coupling vector entry, then the program tries
	      the negative expression of the corresponding Gamma and
	      multiplies the coupling with (-1).
	   b) the entries of the kinematical vector have to be closed
	      under application of the M$FlippingRules, i.e. fermionic
	      couplings have to be written such that the flipped couplings
	      are present in the generic coupling. Again, it is possible
	      to define flippings that change the sign of Gamma and to
	      take care for those signs by using a G[-]. *)

M$GenericCouplings = {

        (* F-F: *)

  AnalyticalCoupling[ s1 F[i, mom1], s2 F[j, mom2] ] ==
    G[1][s1 F[i], s2 F[j]] .
      { FANonCommutative[FADiracSlash[mom1], FAChiralityProjector[-1]],
        FANonCommutative[FADiracSlash[mom2], FAChiralityProjector[+1]],
        FANonCommutative[FAChiralityProjector[-1]],
        FANonCommutative[FAChiralityProjector[+1]] },

	(* V-V: *)

  AnalyticalCoupling[ s1 V[i, mom1, {li1}], s2 V[j, mom2, {li2}] ] ==
    G[1][s1 V[i], s2 V[j]] .
      { FAMetricTensor[li1, li2] FAScalarProduct[mom1, mom2],
        FAMetricTensor[li1, li2],
        FAFourVector[mom1, li2] FAFourVector[mom2, li1] },

	(* F-F-V: *)

  AnalyticalCoupling[ s1 F[i, mom1], s2 F[j, mom2],
      s3 V[k, mom3, {li3}] ] ==
    G[-1][s1 F[i], s2 F[j], s3 V[k]] .
      { FANonCommutative[FADiracMatrix[li3], FAChiralityProjector[-1]], 
        FANonCommutative[FADiracMatrix[li3], FAChiralityProjector[+1]] }
}

	(* FlippingRules: the flipping rules determines how Dirac
	   objects change when the order of fermion fields in the
	   coupling is reversed. In other words, it defines how the
	   coupling C[F, -F, ...] is derived from C[-F, F, ...].
	   Of the elements of the Dirac algebra we need to consider
	   only gamma_mu omega_pm since the others are either
	   unchanged or not used (sigma_{mu,nu}).
	   See Denner, Eck, Hahn, Kueblbeck, NPB 387 (1992) 467. *)

M$FlippingRules =
  FANonCommutative[dm:_FADiracMatrix | _FADiracSlash, FAChiralityProjector[pm_]] ->
    -FANonCommutative[dm, FAChiralityProjector[-pm]]

	(* TruncationRules: rule for omitting the wave functions of
	   external Propagators defined in this file. *)

M$TruncationRules = {
  _FAPolarizationVector -> 1,
  _FADiracSpinor -> 1
}

	(* LastGenericRules: the very last rules that are applied to an
	   amplitude before it is returned by CreateFeynAmp. *)

M$LastGenericRules = {
	(* relicts of the truncation of spinors: *)
  Dot[1, line__, 1] :> Dot[line],
  Dot[1, 1] :> 1,
	(* outgoing vector bosons: throw away signs of momenta *)
  FAPolarizationVector[p_, _. k:FourMomentum[Outgoing, _], li_] :>
    Conjugate[FAPolarizationVector][p, k, li]
}


	(* cosmetics: *)

Format[
  FermionChain[
    FANonCommutative[_[s1_. mom1_, mass1_]],
    r___,
    FANonCommutative[_[s2_. mom2_, mass2_]]] ] :=
  Overscript[If[FreeQ[mom1, Incoming], "u", "v"], "_"][mom1, mass1] .
    r . If[FreeQ[mom2, Outgoing], "u", "v"][mom2, mass2]

Format[ FADiracSlash ] = "gs"

Format[ FADiracMatrix ] = "ga"

Format[ FAChiralityProjector[1] ] = Subscript["om", "+"]

Format[ FAChiralityProjector[-1] ] = Subscript["om", "-"]

Format[ FAGaugeXi[a_] ] := Subscript["xi", a]

Format[ FAPolarizationVector ] = "ep"

Unprotect[Conjugate];
Format[ Conjugate[a_] ] := Superscript[a, "*"];
Protect[Conjugate]

Format[ FAMetricTensor ] = "g"

Format[ FAScalarProduct[a__] ] := Dot[a]

Format[ FAFourVector[a_, b_] ] := a[b]

Format[ FAFourVector[a_] ] := a

