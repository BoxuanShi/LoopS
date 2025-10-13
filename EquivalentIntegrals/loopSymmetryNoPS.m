
(*The MIT License (MIT)

Copyright (C) 2022 Yan-Qing Ma

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Modifications made for LoopS are redistributed under the GPL-3.0 license.
By using, modifying, or redistributing this file as part of LoopS, you
agree to comply with the terms of the GPL-3.0 license.
*)

ClearAll[loopSymmetryNoPS];
MMATranspose = Transpose;
Options[loopSymmetryNoPS] = {"PrintLog" -> False};
loopSymmetryNoPS[props0_List, loopmoms_List, 
   process_String : "CurrentProcess", opt : OptionsPattern[]] /; 
  OptRestrict[opt] := 
 loopSymmetryNoPS[props0, loopmoms, ToExpression[process], opt]
loopSymmetryNoPS[props0_List, loopmoms_List, process_Association, 
   opt : OptionsPattern[]] /; OptRestrict[opt] := 
 loopSymmetryNoPS[props0, loopmoms, process["moms"], opt]
loopSymmetryNoPS[props0_List, loopmoms_List, moms_, opt : OptionsPattern[]] /;
    OptRestrict[opt] := Module[
   	{i, props, nl, extmoms, ne, x, propshape, sgns, cycextedg, branches, 
    reducycedg, branchpropstd, reduLB, fullLB,
    		LBrules, propsnew, sgns2, canonicalProps, ruleList},
   	
   	props = props0 // TogetherExpand;
   	nl = Length@loopmoms;
   	
   	(*** find out external momenta ***)
   	extmoms = Select[Variables@props[[All, 1]], MemberQ[moms, #] &];
   	(*** check ***)
   	If[Union@Exponent[#, x] =!= {1} || Union[# /. x -> 0] =!= {0},
      		Print["Propagators are not  homogeneous linear in momenta: ", 
       props0];
      		Abort[];
      	] &@(props[[All, 1]] /. Thread[extmoms -> x*extmoms]);
   	extmoms = Complement[extmoms, loopmoms];
   	ne = Length@extmoms;
   	
   	(*** shape of each propagator: {0, mass} or {n,mass}, 
   where n can be the gauge link direction ***)
   	propshape = 
    If[#[[1]] === #[[2]], {0, #[[3]]}, {#[[2]], #[[3]]}] & /@ props;
   	

   	(*** check loop momenta dependence ***)
   	If[Or @@ (FreeQ[#[[1]], 
          Alternatives @@ loopmoms] || #[[1]] =!= #[[2]] && ! 
           FreeQ[#[[2]], Alternatives @@ loopmoms] & /@ props),
    		Print[
     "Incorrect input for LoopSymmetry. Please check loop momenta \
dependence."]; 
    		Print["Propagators are given by: ", {props0, loopmoms}];
    		Abort[];
    	];
   	
   	(*** Step 1: 
   find a canonical form for each propagator and then classify propagators \
into branches: 
   		 sgns: a list of sign (+1 or -1), 
   denotes the sign difference between props and their unique form;
   		 cycextedg: a matrix satisfies sgn*props[[All,1]]=cycextedg.Join[
   loopmoms,extmoms]; 
   		 branches: {{i1,i2,...},{j1,j2,..},}, 
   each list (a set of numbers) denotes a branch;
   		 reducycedge: a sub-matrix of cycextedg, 
   keep only information of loop momenta defining each branch ***)
   	{sgns, cycextedg, branches, reducycedg} = 
    branchClassify[props, loopmoms, extmoms];
   	If[OptionValue["PrintLog"] == True,
    		Print["cycextedg=", cycextedg];
    		Print["sgns=", sgns];
    	Print["branches=", branches];
    	];	
   	
   	(*** Step 2: for each branch, find one (or two, if only two equal-
   mass propagators) special propagator ***)
   	(*** branchpropstd[[i]]: {i1} or {i1,i2}, 
   i1 (i2) is the propagator number ***)
   	branchpropstd = 
    sortInBranch[#, cycextedg[[#, -ne ;; -1]], propshape[[#]]] & /@ branches;
   	(*** branchpropstd[[i]]: {i1,...,
   i#branches} is a possible choice of special-propagator sets ***)
   	branchpropstd = Tuples[branchpropstd];
   	If[OptionValue["PrintLog"] == True,
    		Print["Step 2: possible choices of special propagator sets:\n", 
     branchpropstd]
    	];
   	
   	(*** the set of special propagators form a reduced vacuum diagram. 
   Find all possible choices 
   		 of loop bases (LB, where to insert loop momenta l1, ..., 
   lL) in the reduced diagram ***)
   	(*** reduLB[[i]]: {b1,...,bL}, 
   bi means the bi'th branck, (not the b1'th propagator in the orginal \
diagram). ***)
   	reduLB = loopBasis[reducycedg];
   	If[OptionValue["PrintLog"] == True,
    		Print["{reducycedg,reduLB}=", {reducycedg, reduLB}]
    	];
   	
   	(*** Step 3: 
   find all equivalent propagator sets to insert pure loop momenta, 
   with generic orientation and order ***)
   	(***fullLB[[i]]: {i1,i2,...,iL} ***)
   	fullLB = sortLoopBasis[branchpropstd, reduLB, cycextedg, propshape];
   	If[OptionValue["PrintLog"] == True,
    		Print["Step 3: propagator sets with generic orientation&order, fullLB=",
      fullLB]
    	];
   	
   	(*** Step 4: 
   find all equivalent propagator sets to insert pure loop momenta, 
   with full orientations but generic ordering ***)
   	(***fullLB[[i]]: {-i1,+i2,...,-iL} ***)
   	fullLB = sortOrientation[fullLB, cycextedg, propshape];
   	If[OptionValue["PrintLog"] == True,
    		Print[
     "Step 4: propagator sets with full orientation&order, LBrules=", \
{Length@#, Short@#} &@fullLB]
    	];
   	
   	(*** Step 5: 
   find all equivalent propagator sets to insert pure loop momenta, 
   with full orders and orientations specified ***)
   	(***fullLB[[i]]: {-i1,+i2,...,-iL} ***)
   	LBrules = sortPermutation[fullLB, cycextedg, propshape];
   	If[OptionValue["PrintLog"] == True,
    		Print[
     "Step 5: propagator sets with full perumations but generic orientation, \
fullLB=", {Length@#, #[[1 ;; Min[4, Length@#]]]} &@LBrules]
    	];	
   	
   	(*** calculate standard propagators results ***)
   	(*** standard form of propagators: {prop1, prop2,...}  ***)
   	cycextedg = cycextedg . LBrules[[1]];
   	sgns2 = If[OrderedQ[{-#, #}], 1, -1] & /@ cycextedg;
   	propsnew = cycextedg . Join[loopmoms, extmoms];
   	canonicalProps = Table[
       		If[propshape[[i, 1]] === 0,
        			(*** quadratic propagator ***)
        			{sgns2[[i]]*propsnew[[i]], sgns2[[i]]*propsnew[[i]], 
         propshape[[i, 2]], Sequence @@ props0[[i, 4 ;; -1]]},
        			(*** linear propagator ***)
        			{sgns2[[i]]*propsnew[[i]], sgns2[[i]]*sgns[[i]]*propshape[[i, 1]], 
         propshape[[i, 2]], Sequence @@ props0[[i, 4 ;; -1]]}
        		], {i, Length@propsnew} 
       	] // Expand // SortBy[#, LeafCount] &;
   		
   	(*If[OptionValue["AllTransRules"]===False,LBrules=LBrules[[1;;1]]];*)
   	
   	ruleList = 
    Thread[loopmoms -> (#[[1 ;; nl]] . Join[loopmoms, extmoms])] & /@ 
     LBrules;
   	
   	{canonicalProps, ruleList}
   ];

Options[branchClassify]={};
branchClassify[props_,loopmoms_,extmoms_,opt:OptionsPattern[]]/;OptRestrict[opt]:=Module[
	{nl,cycextedgmat,sgns,cycextedgmatstd,mat,propclass,cycedgmatred},
	
	nl=Length@loopmoms;
	
	(*** cycextedgmat is a matrix: each line corresponds to a propagator, and each colomn 
		 corresponds to a momentum in the list Join[loopmoms,extmoms] ***)
	cycextedgmat=Coefficient[props[[All,1]],#]&/@Join[loopmoms,extmoms]//MMATranspose;
	(*In case of no loopmoms and extmoms*)
	If[cycextedgmat==={},cycextedgmat=ConstantArray[{},Length@props]];
	
	(*** align orientation of propagator momenta in an unique way, so that loop momenta in 
		 all propagators in the same branch are the same ***)
	sgns=If[OrderedQ[{-#,#}//Expand],1,-1]&/@cycextedgmat;
	(*** note for linear propagator: no problem, because final result is a replacement rule ***)
	cycextedgmatstd=sgns*cycextedgmat;
	
	(*** classify prop momenta into branches, by their dependences on loop momenta ***)
	mat=Table[{i,cycextedgmatstd[[i,1;;nl]]},{i,Length@cycextedgmatstd}];
	mat=GatherBy[mat,#[[2]]&];
	propclass=#[[All,1]]&/@mat;
	cycedgmatred=#[[1,2]]&/@mat;
	
	{sgns,cycextedgmatstd,propclass,cycedgmatred}
];

(*** Find all loop bases from symanzik polynomial of loop-internal momenta matrix. 
	Each basis is a possible choice of {l1, l2, ...}***)
loopBasis[cycedgmat_] := Module[{symanzik1, x, y, res},
  symanzik1 = 
   Expand[Det[
     MMATranspose[cycedgmat] . 
      DiagonalMatrix[Array[x, Length[cycedgmat]]] . cycedgmat]]; 
  res = If[Head[symanzik1] === Plus, List @@ symanzik1, {symanzik1}]; 
  res = (If[Head[#1] === Times, List @@ #1, {#1}] &) /@ res;
  (*res=DeleteCases[#,y_/;NumberQ[y],{2}]&@res;*)
  res = DeleteCases[#, y_ /; NumberQ[y[[1]]], {1}] &@res;
  res /. x -> Identity]

(*** the transformation for a single choice of loop basis ***)
lbTransform[cycextedg_,loopbasis0_]:=Module[
	{loopbasis,orient,nl,ne,old,new,T1,T2,tranMat,cycextedgnew,identityMatrix},
	
	loopbasis=loopbasis0//Abs;
	orient=loopbasis0//Sign;
	
	nl=Length@loopbasis;
	ne=Length@cycextedg[[1]]-nl;
	
	identityMatrix[0]={};
	identityMatrix[n_]:=IdentityMatrix[n];
	
	(*** old and new loop basis props. only loop parts are kept in new props ***)
	old=cycextedg[[loopbasis]];
	new=DiagonalMatrix@orient;
	
	(*** {loop-old,ext-old}.tranMat=={loop-new,0}, let tranMat={{T1,T2},{0,1}} ***)
	{T1,T2}=Inverse@old[[All,1;;nl]] . #&/@{new,-old[[All,nl+1;;-1]]};
	tranMat=Join[Join[T1,Table[0,{ne},{nl}]],Join[T2,identityMatrix[ne]],2];
	
	tranMat
];

(*** sort according to the later values, and return the first value ***)
(*** x,y,z: use to distinguish 0, 1, -1 ***)
findShortestUnique[choices0_]:=Module[
	{choices,x,y,z,minlen},
	choices=SortBy[choices0,{#[[2;;-2]],(x+y)*Abs@#[[-1]]//LeafCount,(x)*#[[-1]]//LeafCount,#[[-1]]}&];
	
	choices=SplitBy[choices,Last];
	
	minlen=Min[Length/@choices];
	choices=Select[choices,Length@#===minlen&][[1]];
	choices[[All,1]]
];

sortInBranch[branch_,extedgbranch_,propshape_]:=Module[
	{propnew,propchoices,propstd,propstdlist},
	(*Print[{branch,extedgbranch,propshape}];*)
	
	
	If[Length@branch===1,Return[branch,Module]];
	
	(*** choose one propagator as a baseline (together with different orientation), 
		 and then calculate relative part of all other propagators ***)
	propchoices=Join@@Table[
		propnew=orient(#-extedgbranch[[i]])&/@extedgbranch//TogetherExpand;
		{branch[[i]],Join[propnew,propshape,2]//Sort}
		,{orient,1,-1,-2},{i,Length@branch}
	];
	
	(*** sort all possible choices, and return the unique one 
		 (maybe two if the branch has and only has two equal-mass propagators)  ***)
		 
	propchoices=findShortestUnique[propchoices];
	(*propchoices=SortBy[propchoices,#[[2]]&];
	propchoices=Select[propchoices,#[[2]]===propchoices[[1,2]]&];*)
	
	propchoices

];

sortLoopBasis[branchpropstd_,reduLB_,cycextedgold_,propshape_,opt:OptionsPattern[]]/;OptRestrict[opt]:=Module[
	{fullLB,np,nl,ne,LBrules,cycextedg,temp,loopInf,extInf,projMatAll,projMat1},
	
	np=Length@cycextedgold;
	nl=Length@reduLB[[1]];
	ne=Length@cycextedgold[[1]]-nl;
	
	(***  list all choices of loop bases, including choices of special propagators 
		 and choices of loop bases of reduced diagram ***)
	(***  fullLB[[i]]:  {i1,...,iL}, denotes prop number ***)
	fullLB=Join@@Table[branchpropstd[[All,reduLB[[j]]]],{j,Length@reduLB}]//DeleteDuplicates;
	
	(*** calculate transformation matrix for each choice of loop basis. An arbitrary choice 
		 of the permutation group between l1, ..., lL is made. And an arbitrary choice of orientation
		 of each li is made. Will be fixed later. ***)
	(*** LBrules[[i]]: cycexted=cycextedgold.LBrules[[i]] ***)
	LBrules=lbTransform[cycextedgold,#]&/@fullLB;
	
	(*** projected matrix for all loop basis choices ***)
	projMatAll=Table[
		cycextedg=cycextedgold . LBrules[[j]];
		(*** projected matrix for each loop basis choice ***)
		projMat1=Table[
			temp=cycextedg[[i]]; (*** the i'th propagator ***)
			loopInf=Plus@@Abs@temp[[1;;nl]]; (*** total number of loop momenta ***)
			extInf=Sort[{temp[[-ne;;-1]],-temp[[-ne;;-1]]}][[-1]]; (*** unique choice of external momenta ***)
			{loopInf,extInf,propshape[[i]]}
			,{i,np}
		];
		loopInf=Plus@@Abs@cycextedg[[All,1;;nl]]; (*** total number of each loop momentum in all propagators***)
		{j,Plus@@loopInf,Sort@loopInf,Sort@projMat1}
		,{j,Length@fullLB}
	];
	
	projMatAll=findShortestUnique[projMatAll];
	
	fullLB[[projMatAll]]
];

sortOrientation[fullLB0_,cycextedgold_,propshape_,opt:OptionsPattern[]]/;OptRestrict[opt]:=Module[
	{np,nl,ne,fullLB,hold,nlb,LBrules,cycextedg,temp,loopInf,extInf,projMatAll,projMat1},
	
	np=Length@cycextedgold;
	nl=Length@fullLB0[[1]];
	ne=Length@cycextedgold[[1]]-nl;
	
	fullLB=Join@@Outer[Times,hold/@fullLB0,hold/@Tuples[{1,-1},nl]]/.hold->Identity;
	
	nlb=Length@fullLB;
	
	(*** calculate transformation matrix for each choice of loop basis, with orderless for loop momenta. 
		Will be fixed at the later step.***)
	(*** LBrules[[i]]: cycexted=cycextedgold.LBrules[[i]] ***)
	LBrules=lbTransform[cycextedgold,#]&/@fullLB;
	
	(*** projected matrix for all loop basis choices ***)
	projMatAll=Table[
		cycextedg=cycextedgold . LBrules[[j]];
		(*** projected matrix for each loop basis choice ***)
		projMat1=Table[
			{Sort[{-#,#}][[-1]]&@cycextedg[[i]],propshape[[i]]}
			,{i,np}
		];
		{j,Sort@projMat1}
		,{j,nlb}
	];
	
	(*** projected matrix for all loop basis choices ***)
	projMatAll=Table[
		cycextedg=cycextedgold . LBrules[[j]];
		(*** projected matrix for each loop basis choice ***)
		projMat1=Table[
			temp=cycextedg[[i]]; (*** the i'th propagator ***)
			(*** orderless loop momenta. unique choice of a sign***)
			Sort[{Sort@#[[1;;nl]],#[[-ne;;-1]],propshape[[i]]}&/@{temp,-temp}][[-1]]
			,{i,np}
		];
		{j,Sort@projMat1}
		,{j,nlb}
	];
	
	projMatAll=findShortestUnique[projMatAll];
	
	fullLB[[projMatAll]]
];

sortPermutation[fullLB0_,cycextedgold_,propshape_,opt:OptionsPattern[]]/;OptRestrict[opt]:=Module[
	{np,nl,ne,fullLB2,nlb,LBrules,cycextedg,temp,loopInf,extInf,projMatAll,permu,cycextedgi,rulei},
	
	np=Length@cycextedgold;
	nl=Length@fullLB0[[1]];
	ne=Length@cycextedgold[[1]]-nl;
	
	permu=Permutations[Range[nl]];
	
	(*** calculate transformation matrix for each choice of loop basis.***)
	(*** LBrules[[i]]: cycexted=cycextedgold.LBrules[[i]] ***)
	LBrules=lbTransform[cycextedgold,#]&/@fullLB0;
	nlb=Length@fullLB0;
	
	(*** projected matrix for all loop basis choices ***)
	projMatAll=Table[
		cycextedgi=cycextedgold . LBrules[[i]];
		(*** try all possible permutations ***)
		Table[
			cycextedg=Join[cycextedgi[[All,permu[[j]]]],cycextedgi[[All,-ne;;-1]],2];
			(*** projected matrix for each loop basis choice ***)
			{{i,j},Sort@Table[{Sort[{-#,#}][[-1]]&@cycextedg[[k]],propshape[[k]]},{k,np}]}
			,{j,Length@permu}
		]	
		,{i,nlb}
	];
	
	projMatAll=Flatten[projMatAll,1];
	
	projMatAll=findShortestUnique[projMatAll];
	
	(*** remained LBrules with permutation ***)
	Table[
		rulei=LBrules[[projMatAll[[i,1]]]];
		Join[rulei[[All,permu[[projMatAll[[i,2]]]]]],rulei[[All,-ne;;-1]],2]
	,{i,Length@projMatAll}]
];