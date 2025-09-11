ClearAll[GatherAmplitudes];
GatherAmplitudes::usage = 
  "1. GatherAmplitudes[amp] gather amplitudes in amp list only differ \
by factors.
2. This is purely polynomial operation, FactorAll first is better.";
Options[GatherAmplitudes] = {"GatherAmplitudesZeroRules" -> {}};
GatherAmplitudes[amp_List, opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 Module[{tp1, tp2, tp3, tp4, tp5, tp6}, 
  tp1 = amp // Separate[#, AmplitudePattern] &;
  tp1 = If[# =!= {{}, {}}, {#[[1, 1]], 
       Dot @@ {#[[1]]/#[[1, 1]] // Factor, #[[2]]}}, {0, 0}] & /@ 
    tp1;
  tp2 = Transpose@{Range@Length@tp1, tp1};
  tp3 = tp2 // GatherBy[#, #[[2, 2]] &] &;
  tp4 = {Transpose@{#[[All, 1]], #[[All, 2, 1]]}, #[[1, 2, 2]]} & /@ 
    tp3;
  tp5 = ({Total[#[[1, All, 2]]], #[[2]]} & /@ tp4);
  tp5[[All, 1]] = 
   If[Factor[# /. Dispatch@OptionValue["GatherAmplitudesZeroRules"]] ===
        0, 0, #] & /@ tp5[[All, 1]];
  tp6 = tp4[[All, 1]];
  TableS[
   tp6[[i, All, 2]] = 
    tp6[[i, All, 2]]*If[tp5[[i, 1]] === 0, 0, 1/tp5[[i, 1]]] // 
     Factor, {i, Length@tp4}];
  {Times @@@ tp5, tp6}]