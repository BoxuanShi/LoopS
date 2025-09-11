ParallelLoad["ToSFAD"] := Module[{},
  ClearAll[ToSFAD];
  Options[ToSFAD] = {
    	EtaSign 	-> Automatic,
    	FCI			-> False,
    	FCE			-> False,
    	FCVerbose	-> False
    };
  ToSFAD[expr_, OptionsPattern[]] :=
   	Block[{ex, res, fads, pds, pdsEval, fadsConverted, pdsConverted, rulePds, 
     ruleFads, ruleFinal},
    
    		If[	OptionValue[FCVerbose] === False,
     			sfadVerbose = $VeryVerbose,
     			If[	MatchQ[OptionValue[FCVerbose], _Integer],
       				sfadVerbose = OptionValue[FCVerbose]
       			];
     		];
    
    		FCPrint[1, "ToSFAD: Entering.", FCDoControl -> sfadVerbose];
    		FCPrint[3, "ToSFAD: Entering with: ", expr, 
     FCDoControl -> sfadVerbose];
    
    		If[ OptionValue[FCI],
     			ex = expr,
     			ex = FCI[expr]
     		];
    
    		If[	
     FreeQ2[{ex}, {PropagatorDenominator, CartesianPropagatorDenominator}],
     			(*	Nothing to do.	*)
     			Return[ex]
     		];
    
    		optEtaSign = OptionValue[EtaSign];
    
    		pds = 
     Cases2[ex, {PropagatorDenominator, CartesianPropagatorDenominator}];
    
    		FCPrint[3, "ToSFAD: Relevant propagator denominators: ", pds, 
     FCDoControl -> sfadVerbose];
    
    		pdsEval = toSFAD[MomentumCombine[#, FCI -> True]] & /@ pds;
    
    		pdsEval = pdsEval /. ToSFAD[x_CartesianPropagatorDenominator] :> x;
    
    		FCPrint[3, "ToSFAD: After toSFAD: ", pdsEval, 
     FCDoControl -> sfadVerbose];
    
    		If[ ! FreeQ[pdsEval, toSFAD],
     			Message[ToSFAD::failmsg, 
      "Failed to convert all PropagatorDenominators to \
StandardPropagatorDenominators."];
     			Abort[]
     		];
    
    		ruleFinal = Thread[Rule[pds, pdsEval]];
    
    		res = ex /. ruleFinal;
    
    		If[	! FreeQ2[{res}, {FAD, PropagatorDenominator}],
     			Message[ToSFAD::failmsg, 
      "Failed to eliminate all the occurences of FADs or PDs."]
     		];
    
    		If[	OptionValue[FCE],
     			res = FCE[res]
     		];
    
    		FCPrint[1, "ToSFAD: Leaving.", FCDoControl -> sfadVerbose];
    
    		res
    
    	];
  
  (* (q^0)^2 - (q^i)^2 - m^2 -> q^2 - m^2 *)
  toSFAD[CartesianPropagatorDenominator[CartesianMomentum[q_, dim_ - 1], 
     0, (c_ : 0) - 
      TemporalPair[ExplicitLorentzIndex[0], TemporalMomentum[q_]]^2, {n_, 
      s_}]] :=
   	StandardPropagatorDenominator[Complex[0, 1] Momentum[q, dim], 0, 
     c, {n, s}] /; 
    FreeQ2[{c, q}, {Complex, 
       TemporalPair}] && (FeynCalc`Package`MetricS === -1) && \
(FeynCalc`Package`MetricT === 1);
  
  toSFAD[CartesianPropagatorDenominator[
     Complex[0, 1] CartesianMomentum[q_, dim_ - 1], 
     0, (c_ : 0) + 
      TemporalPair[ExplicitLorentzIndex[0], TemporalMomentum[q_]]^2, {n_, 
      s_}]] :=
   	StandardPropagatorDenominator[Momentum[q, dim], 0, c, {n, s}] /; 
    FreeQ2[{c, q}, {Complex, 
       TemporalPair}] && (FeynCalc`Package`MetricS === -1) && \
(FeynCalc`Package`MetricT === 1);
  
  toSFAD[PropagatorDenominator[c_. Momentum[q_, dim___], b_]] :=
   	StandardPropagatorDenominator[c Momentum[q, dim], 0, -b^2, {1, 1}] /; 
    FreeQ[{c, q}, Complex] && optEtaSign === Automatic;
  
  toSFAD[PropagatorDenominator[Complex[0, 1] c_. Momentum[q_, dim___], b_]] :=
   	StandardPropagatorDenominator[Complex[0, 1] c Momentum[q, dim], 
     0, -b^2, {1, -1}] /; FreeQ[{c, q}, Complex] && optEtaSign === Automatic;
  
  toSFAD[PropagatorDenominator[a_, b_]] :=
   	StandardPropagatorDenominator[a, 0, -b^2, {1, optEtaSign}] /; 
    optEtaSign =!= Automatic;
  
  toSFAD[PropagatorDenominator[a_, b_]] :=
   	StandardPropagatorDenominator[a, 0, -b^2, {1, 1}] /; 
    FreeQ[a, Complex] && optEtaSign === Automatic;
  ]
ParallelLoad["ToSFAD"];