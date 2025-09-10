(* ::Package:: *)

(*
    Copyright (C) Alexander Smirnov.
    The program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License version 2 as
    published by the Free Software Foundation.

    The program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
*)

If[Not[TrueQ[$VersionNumber>=8.0]],
    Print["Mathematica version 8 or higher expected"];
    Abort[];
];

If[Options[FIRE] === {},
    Options[FIRE] = {
        "AutoDetectRestrictions" -> True,
        "Parallel" -> False,
        "LI" -> False,
        "PositiveIndices" -> Automatic,
        "FactorCoefficients" -> True,
        "LeeIdeas" -> True,
        "UsingIBP" -> True,
        "PrintIrreducibleIntegrals" -> True,
        "DVar" -> d,
        "ResultVar" -> G,
        "ProgressReport" -> False
    }
];

FIRE::usage = "See the paper for details";

LiteRed`j = j;
LiteRed`IBP = IBP;

BeginPackage["FIRE`"];

F;
SaveStart;
LoadStart;
EvaluateAndSave;
LoadLRules;
LoadRules;
LoadSBases;
SaveSBases;
WriteRules;
SaveRulesToFile;
FindRules;
MasterIntegrals;
startinglist;
RESTRICTIONS;
SYMMETRIES;
Internal;
External;
Propagators;
Replacements;
Problems;
Prepare;
PrepareIBP;
ClearIBP;
LII;
Burn;
ClearTables;
TransformRules;
SaveTables;
LoadTables;
SaveData;
DumpSaveData;
LoadData;
ConvertStart;

{ProblemNumber,ExampleDimension, SBasis0L, SBasis0D, SBasis0C, SBasisL, SBasisD,
          SBasisA, SBasisH, SBasisO, SBasisC, SBasisS, SBasisR,
            SBasisRL, SBasisM, Burning, MaxDimension, SectorNumber, MaxRegion,
          RealRegion,RealSectors,RealSector2Number,Number2RealSector,HPI,SBasisN,LRules};

CompareTables::usage = "CompareTables[filename1, filename2] compares table coefficients. Equal structure is supposed, errors otherwise. The result is the list of differences between coefficients
{0} means equal";

Tables2Rules::usage = "Tables2Rules[filename, Func:Identity, JoinTerms:True] loads tables and transforms them to Mathematica rules format. The Func is called on coefficients, and if JoinTerms is True, we get sums on the right-hand sides, list of pairs suitable for ImproveMasters otherwise";

Tables2Masters::usage = "Tables2Masters[filename] picks out master integrals from tables";

CombineTables::usage = "CombineTables[filename, numbers] joins tables from reductions with different masters set to zero. Numbers is a list of either numbers or pairs of numbers designating ranges.";

Begin["`Private`"];

MemoryInfo=100; (*measured in mb*)

(*functions instead of the Combinatorica package *)

ClearAll[MyCompositions];
MyCompositions[n_Integer, k_Integer] := DeleteDuplicates[SortBy[Join @@ Permutations /@ IntegerPartitions[n, {k}, Join[{0}, Range[n]]], !First[#] &]] /; k > 0;
MyCompositions[n_Integer, 0] := {{n - 1}};

MyKSubsets[l_List, 0] := {{}}
MyKSubsets[l_List, 1] := Partition[l, 1]
MyKSubsets[l_List, 2] := Flatten[Table[{l[[i]], l[[j]]}, {i, Length[l] - 1}, {j, i + 1, Length[l]}], 1]
MyKSubsets[l_List, k_Integer?Positive] := {l} /; (k == Length[l])
MyKSubsets[l_List, k_Integer?Positive] := {} /; (k > Length[l])
MyKSubsets[s_List, k_Integer] := Prepend[Map[s[[#]] &, MyKS[Length[s], k]], s[[Range[k]]]]
MyKS = Compile[{{n, _Integer}, {k, _Integer}}, Module[{h, ss = Range[k], x},
    Table[(h = Length[ss]; x = n; While[x === ss[[h]], h--; x--];
    ss = Join[Take[ss, h - 1],  Range[ss[[h]] + 1, ss[[h]] + Length[ss] - h + 1]]), {Binomial[n, k] - 1}]]
];

MasterIntegrals[]:=GetII /@ IrreducibleIntegrals[];

MyToString[x_]:=ToString[x];
MyToString[x_,y_]:=ToString[x,y];

MyTimeUsed[]:=AbsoluteTime[];
(*MyTimeUsed[]:=TimeUsed[];*)
(*should use AbsoluteTime, since the database access is not measured by Timing*)

Cleanup[] := (
    UserCleanup[];
);

CodeInfo[]:=Module[{temp}, (*just some usefull output*)
    Print["FIRE, version 6.5.2"];
]

CodeInfo[] (*and we run it when loading the code*)



MemoryTest[]:=Module[{temp},
If[Head[LastMemoryInfo]===Symbol,LastMemoryInfo=MemoryInfo*1000000];
    While[LastMemoryInfo<MemoryInUse[],
        Print["MEMORY INFORMATION: ",LastMemoryInfo/1000000," MEGABYTES REACHED"];
        LastMemoryInfo=LastMemoryInfo+MemoryInfo*1000000;
    ];
]


InitializeValues[]:=Module[{temp}, (*sets some initial values*)
    If[Not[TrueQ[Burning]],Print["FIRE not ready. Run the Burn[] command"];Abort[]];
    If[Head[hp]===Symbol,hp=0];
    If[Head[hc]===Symbol,hc=0];
    If[Head[NegativeNumber]===Symbol,NegativeNumber=0];
    If[Head[TotalNumber]===Symbol,TotalNumber=1];
    If[Head[SBasisM[0]]==SBasisM,SBasisM[0]={}];
    totaltimecounter=MyTimeUsed[];
]

CheckInput[n_,x_]:=Module[{temp}, (*checks if you have requested
            for an itegral of an existing problem number and
            proper dimension*)
    If[Head[ExampleDimension[n]]===ExampleDimension, Print["Load the start file first"]; Abort[]];
    If[Not[Length[x]===ExampleDimension[n]],Print["Wrong dimension"];Abort[]];
    If[Or[x[[##]]>1,x[[##]]<0],Print["Heavy point index can be either 0 or 1"];Abort[]]&/@HPI[n];
]



(*--------------------------------------------------------------------*)
(*Some technical functions, look for those when needed only, just look further now*)

AVRulesD[x_]:=Dispatch[Table[a[here]->x[[here]],{here,1,Length[x]}]]
Delta[j_,size_]:=Delta[j,size]=Table[If[j===here,1,0],{here,1,size}]
notzero[x_] := Not[(x === 0)]
DefinedFor[x_] := (ReleaseHold[Apply[List, ##[[1]], 1]]) & /@ DownValues[x]
Degree2Point[x_, y_] := x*y + (If[##===1,1,0]&/@y)
FirstParts[x_]:=(##[[1]])&/@x;
subs[x_] := (## - x[[1]]) & /@ x

ProportionalCoeff[x_, y_] := Module[{i},
If[x==Table[0,{Length[x]}],Return[0]];
    i = First[First[Position[y, First[Select[y, notzero]]]]];
(x[[i]]/y[[i]])
]

MultiMore[pn_,x_, y_]:=Module[{xx,yy},
    If[And[SBasisRL[pn]>0,y[[SBasisRL[pn]]]===1]===True,
        xx=Delete[x,SBasisRL[pn]];
        yy=Delete[y,SBasisRL[pn]]
        ,
        xx=x;
        yy=y
    ];
    Return[And@@((##>=0)&/@(xx-yy))];
]


UseSymmetry[x_, y_] := Module[{result},
    result=Table[y[[x[[here]]]], {here, 1, Length[x]}];
    result
]
SatisfiesCondition[x_,y_]:=Module[{result},
    result=And@@Table[If[y[[ii]]===0,True,If[y[[ii]]>0,x[[ii]]>0,x[[ii]]<=0]],{ii,Length[x]}];
    result
]

DoubleOrbit[xx_] := Module[{result},
    result=If[SatisfiesCondition[xx[[2]],##[[3]]],
        {{xx[[1]],UseSymmetry[##[[1]],xx[[2]]]},##[[2]]},
        {xx,Table[1,{Length[xx[[2]]]}]}
    ]&/@SBasisS[xx[[1]]];
    result
]

NOrbit[x_] := Union[ObtainNN[
    If[SatisfiesCondition[
        GetII[x][[2]],##[[3]]],
        {GetII[x][[1]],UseSymmetry[##[[1]],GetII[x][[2]]]},
        GetII[x]
    ]]&/@SBasisS[GetII[x][[1]]]]

NewSPoint[pn_,x_] := Module[{temp},
    temp = (If[##>=1,1,0])&/@x;
    If[SBasisRL[pn]>0,Return[ReplacePart[temp,1,SBasisRL[pn]]]];
    temp
]

Info[]:=Print["New relations: ",stepcounter," , for substitution: ", tosubstitute,", integrals considered: ",calculated,", encountered: ", needed]

Answer[x_, options:OptionsPattern[Global`FIRE]]:=Module[{temp}, (*prints the output. the only place,
                where the Factor function is used, just to make answers look pretty*)
    Done[x]=True;
    temp=GetTableD[x];
    If[temp==={},Return[0]];
    If[Or[temp==={x},Head[temp]===TableD],temp=OptionValue["ResultVar"]@@Evaluate[GetII[x]],
        temp=Plus@@((If[OptionValue["FactorCoefficients"],Factor[ToExpression[##[[2]]]],ToExpression[##[[2]]]]*OptionValue["ResultVar"]@@Evaluate[GetII[Sequence@@(##[[1]])]])&/@GetTableC[x]);
    ];
    temp
]


(*end of technical functions*)
(*--------------------------------------------------------------------*)



(*-------------------------------------------------------------------------*)
(*This part is on the usage of tables*)
(*an integral is denoted by a pair {pn,x}, where pn is a number of
a problem and x is a list of indices with the corresponding length.
NN[pair] gives a unique number coresponding to the pair
II[pair] is inverse
However, negative nubmers do not correspond to real intgrals but
are used for tail masking. II[negative number] returns some pair,
and its value is used in the code to know the substitution priority
TableD[n] gives a list of integrals n is represented by (a proper expression)
TableC[n] also has coeffictions but if the database is used, it is not in memory
TableIBP[n] keeps in memory if the IBP's for this point have been constructed
*)


GetNN[x_]:=Module[{temp},
    Return[NN[x]];
]


SetNN[x_,y_]:=Module[{temp},
    NN[x]=y;
]


MakeMaster[x_,n_]:=Module[{x2,s,temp},
    InitializeValues[];
    x2={x[[1]],NewSPoint[x[[1]],x[[2]]]};
    s=ToString[x2,InputForm];
    temp=GetNN[s];
    If[Head[temp]===NN,
        While[Not[Head[GetII[TotalNumber]]===II],TotalNumber++];
        SetNN[s,TotalNumber];
        SetII[TotalNumber,s];
        SetIntegralNumber[TotalNumber,ToExpression[PairNumber[x2]<>"9"<>ZerosString[8]]]
    ];
    s=ToString[x,InputForm];
    temp=GetNN[s];
    If[Head[temp]===NN,
        While[Not[Head[GetII[TotalNumber]]===II],TotalNumber++];
        SetNN[s,TotalNumber];
        SetII[TotalNumber,s];
        ,
        RemoveIntegralNumber[temp]
    ];
    temp=GetNN[s];
    SetIntegralNumber[temp,ToExpression[PairNumber[x2]<>"9"<>ZerosString[8-StringLength[ToString[n]]]<>ToString[n]]];
]

ObtainNN[x_]:=Module[{s,temp}, (*gets a new number for a pair if needed*)
    s=ToString[x,InputForm];
    temp=GetNN[s];
    If[Head[temp]===NN,
        While[Not[Head[GetII[TotalNumber]]===II],TotalNumber++];
        SetNN[s,TotalNumber];
        SetII[TotalNumber,s];
        SetIntegralNumber[TotalNumber,ToExpression[PairNumber[x]<>"9"<>ZerosString[8]]];
        Return[TotalNumber]
        ,
        Return[temp]
    ]
]

SetII[x_,y_]:=Module[{temp},
    II[x]=y
]


GetII[x_]:=Module[{temp},
    If[Head[II[x]]===II,
        Return[II[x]],
        Return[ToExpression[II[x]]]
    ]
]


ClearTables[]:=Module[{temp}, (*how did you guess? it clears the tables!*)
    Clear[TableD,TableC,TableIBP,TotalNumber,II,NN,NegativeNumber,TablesLoaded,UsedIBP,UsedIBPs,EL,ELMet,ELLength,ELcounter];
    Clear[INTERNALERROR,Done];
    TotalNumber=1;
]

SetTableD[x_,y_]:=(TableD[x]=y)

SetTableC[x_,y_]:=(TableC[x]=y)

ClearTableD[x_]:=(TableD[x]=.)

GetDefinedTableD[]:=(DefinedFor[TableD])

ClearTableC[x_]:=(TableC[x]=.)

ClearTable[x_]:=Module[{temp,n},
    If[ELMet[x],ELMet[x]=.];
    temp=GetTableD[x];
    If[Not[temp==={}],
        TableC[x]=.
    ];
    IntegralNumber[x]=.;
    temp=GetII[x];
    If[x>0,
        NN[MyToString[temp]]=.
    ];
    II[x]=.;
    TableD[x]=.;
]

GetTableD[x_]:=Module[{temp}, (*inverse to SetTableC*)
    temp=TableD[x];
    temp
]

GetTableC[x_]:=Module[{temp}, (*inverse to SetTableC*)
    temp=GetTableD[x];
    If[Or[Head[temp]===TableD,temp==={x}],Return[{{x,"1"}}]];
    If[temp==={},Return[{}]];
    Return[TableC[x]]
]

SetIntegralNumber[x_,y_]:=(IntegralNumber[x]=y)

GetIntegralNumber[x_]:=Module[{temp},
    Return[IntegralNumber[x]]
]

RemoveIntegralNumber[x_]:=Module[{temp},
    IntegralNumber[x]=.
]



MakeTable[y_,zz_]:=Module[{i, z}, (*called to fill TableD and TableC from a temporary storage*)
    z=zz;
    If[And[Length[z]>0,HigherNumber[HighestNumber[z],y]],Print[II[y]];Print[II/@z];Abort[]];
    MemoryTest[];
    SetTableD[y,z];
    SetTableC[y,{##,Coeff[##]}&/@z];
]

MakeTable2[y_,z_]:=Module[{i,zn,zp}, (*a complicated version of
                            MakeTable that also performs
                            tail-masking*)
    If[And[Length[z]>0,HigherNumber[HighestNumber[z],y]],Print[II[y]];Print[II/@z];Abort[]];
    MemoryTest[];
    zn=Select[z,(Not[SameSector[##,y]]) &];
    If[Length[zn]>0,
        NegativeNumber++;
        SetTableD[-NegativeNumber,zn];
        SetTableC[-NegativeNumber,{##,Coeff[##]}&/@zn];
        zp=Complement[z,zn];
        SetTableD[y,Append[zp,-NegativeNumber]];
        SetTableC[y,Append[{##,Coeff[##]}&/@zp,{-NegativeNumber,"1"}]];
        SetII[-NegativeNumber,ToString[{GetII[y][[1]],NewSPoint[GetII[y][[1]],GetII[y][[2]]]},InputForm]];
        SetIntegralNumber[-NegativeNumber,ToExpression[SavedPairNumber[{GetII[y][[1]],NewSPoint[GetII[y][[1]],GetII[y][[2]]]}]<>ToDigits[NegativeNumber,9]]];
    ,
        zp=z;
        SetTableD[y,zp];
        SetTableC[y,{##,Coeff[##]}&/@zp];
    ];
]

MakeZeroTable[y_]:=Module[{i}, (*for integrals equal to zero*)
    SetTableD[y,{}];
]

MakeIrreducible[y_, options:OptionsPattern[Global`FIRE]]:=Module[{temp}, (*after this call the integral is treated completely irreducible*)
    If[OptionValue["PrintIrreducibleIntegrals"], Print["IRREDUCIBLE INTEGRAL: ", GetII[y]]];
    SetTableD[y,{y}];
    SetTableC[y,{{y,"1"}}];
]

IrreducibleIntegrals[]:=Select[Flatten[GetDefinedTableD[]],(GetTableD[##]==={##})&];
(*lists all irreducible integrals (numbers)*)


(*Table usage part over*)
(*------------------------------------------------------------------------*)
(*and now everything on saving and loading tables
The syntax for saving tables is
SaveTables[File(obligatory),IntegalList(non-obligatory),SaveSymmetric(non-obligatory)]
The file parameter points at a file, the integral list can be
missing, in this case all tables are saved. This option is not recomended
and can result in memory overrflow, and in real problems you will
need only thousands of values, while there can be millions and
more stored in tables.
The SaveSymmetric option is assumed to be False, but if it is
True, the tables for symmetric integrals are also saved.
Might be usefull and save time if you did a long computation of integrals, that
are not minimal in there symmetry orbits, and might need
the symmetrical integrals later.

The syntax for loading tables is either LoadTables[File] or
LoadTables[FileList]. Please keep in mind that you cannot run this
command twice without quitting the kernel, or do a calculation and
then load some tables. This is done for the reason that same
integrals might have different numbers in different calculations
and it is not easy to combine them together. Hoewver, the
LoadTables[FileList] syntax gives you all the functionality you
need. For example, if you have done an evaluation and now want to
load some tables, you can first save what you have in memory now,
quit the kernel, then load the tables together.
*)

SaveTables[file_,temp_]:=SaveTables[file,temp,False]

SaveTables[file_,temp_,SaveSymmetric_] := Module[{y,tt},
    y=ObtainNN/@temp;
    y=Union[y,IrreducibleIntegrals[]];
    tt=Union[Flatten[GetTableD/@y]];
    tt=Select[tt,(Head[GetTableD[##]]===TableD)&];
    If[Length[tt]>0,
        Print["TABLES SAVED INCORRECTLY"];
        Print["No tables for points ",If[##<0,##,GetII[##]]&/@tt];
    ];
    CTables={##,GetTableC[##]}&/@y;
    NITables={##,GetII[##]}&/@y;
    Put[{CTables,NITables},file];
    Clear[CTables,NITables]
]

DeNumerate2[x_]:={II[##[[1]]],##[[2]]}&/@x;

DeNumerate[]:=Module[{temp},
    temp = {II[##[[1]]], ToString[##[[2]],InputForm]} & /@ NITables;
    Apply[Set, temp, {1}];
    CTables={II[##[[1]]],DeNumerate2[##[[2]]]}&/@CTables;
    Clear[II,NITables];
]

Enumerate2[x_]:={ObtainNN[ToExpression[##[[1]]]],##[[2]]}&/@x;

Enumerate[]:=Module[{temp},
    temp=Union[(##[[1]])&/@CTables,(##[[1]])&/@(Join@@((##[[2]])&/@CTables))];
    NITables=Transpose[{Range[Length[temp]],temp}];
    ProblemNumbers=Union[ToExpression[##[[2]]][[1]]&/@NITables];
    If[Not[Complement[ProblemNumbers,AllProblems[]]==={}],
        Print["Tables cannot be loaded."];
        Print["Probably you have not loaded all sbases or start files."];
        Print["The following problems are missing: ",Complement[ProblemNumbers,AllProblems[]]];
        Abort[]
    ];

    temp = Hold[SetII[##[[1]], ##[[2]]]] & /@ NITables;
    Apply[List, temp, {1}];
    temp = Hold[SetNN[##[[2]], ##[[1]]]] & /@ NITables;
    Apply[List, temp, {1}];
    temp = Hold[SetIntegralNumber[##[[1]],ToExpression[PairNumber[ToExpression[##[[2]]]]<>"9"<>ZerosString[8]]]]& /@ NITables;
    Apply[List, temp, {1}];
    TotalNumber=Length[temp]+1;
    CTables={ObtainNN[ToExpression[##[[1]]]],Enumerate2[##[[2]]]}&/@CTables;
]

LoadTables[FileList_List]:=Module[{temp,i},
    If[TablesLoaded,Print["Tables already loaded. If you want to load tables from multiple files, use the LoadTables[{file_1,...file_n}] command."]; Return[]];
    If[TotalNumber>1,Print["Tables can be loaded only before calculations"];Return[]];
    InitializeValues[];
    CTables=Flatten[Reap[
        (Clear[NITables,CTables];
            Check[
                {CTables,NITables}=ReadList[##][[1]],
                Print["File not found"]; Abort[],
                Get::"noopen"
            ];
            DeNumerate[];
            Sow[CTables];
        )&/@FileList;
    ][[2]][[1]],1];
    Enumerate[];
    temp = Hold[##[[1]],##[[2]]]&/@CTables;
    Apply[SetTableC, temp, {1}];
    CTables={##[[1]],FirstParts[##[[2]]]}&/@CTables;
    temp = Hold[##[[1]],##[[2]]]&/@CTables;
    Apply[SetTableD, temp, {1}];
    temp = {Done[##[[1]]],True}&/@CTables;
    Apply[Set, temp, {1}];
    Clear[NITables,CTables];
    TablesLoaded=True;
]

LoadTables[file_String]:=LoadTables[{file}];


(*-------------------------------------------------------------------------*)
(*-------------------------------------------------------------------------*)
(*Sectors, indices, degrees and regions
A sector is denoted by its direction - a set of 1 and -1s.
There is some special treatement of regularized lines here,
because making such an index negative does not move you to a new
sector.
A region is a set of sectors, denoted by a set of 1, 0 and -1s
(the indices corresponding to zeros can be abritrary)
The regions are used if there are s-bases build for regions
or if you want to write rules corresponding to multiple sectors
They are stored in SBasisM[pn].
*)

SSector[pn_,x_] := Module[{temp},
    temp = (If[##>=1,1,-1])&/@x;
    If[SBasisRL[pn]>0,Return[ReplacePart[temp,1,SBasisRL[pn]]]];
    temp
]   (*input - a point, output - a direction *)

SPoint[x_] := Module[{temp}, (*the corner point of a sector*)
    temp = Map[(If[## >= 1, 1, 0]) &, x, {1}];
    temp
]   (*input - a point, output - a starting point *)

Pair2Degree[x_]:=Module[{temp}, (*returns the degree of a point*)
    temp=If[##>=1,##-1,-##]&/@(x[[2]]);
    If[SBasisRL[x[[1]]]>0,Return[ReplacePart[temp,x[[2]][[SBasisRL[x[[1]]]]]-1,SBasisRL[x[[1]]]]]];
    temp
]

MaxRegion[pn_,x_]:=MaxRegion[pn,x] = Module[{result,i,temp},(*returns the maximum region in which the sector is contained*)
    Return[Max@@Reap[Sow[0];
        For[i=1,i<=Length[SBasisM[pn]],i++,
            If[And@@((##==0)&/@Evaluate[(x-SBasisM[pn][[i]])*SBasisM[pn][[i]]]),Sow[i]];
        ];
    ][[2]][[1]]];
]


SameSector[x_,y_]:=Module[{xx,yy,pn}, (*answers if two points are in
        the same sector; the negative numbers that do not correspond to
        real integrals do not lie in any sector*)
    If[x<0,Return[False]];
    If[y<0,Return[False]];
    xx=GetII[x];
    yy=GetII[y];
    If[xx[[1]]===yy[[1]],pn=xx[[1]];SSector[pn,xx[[2]]]===SSector[pn,yy[[2]]],False]
]


(*end of sectors, degrees and regions*)
(*-------------------------------------------------------------------------*)


LOrdering[sector_] := Module[{temp, n,i,lpos,neg,zzz},
    n = Length[sector];
    If[Or[sector === Table[1, {n}], sector === Table[-1, {n}]],
        temp = Prepend[Drop[DiagonalMatrix[sector], -1], Table[1, {n}]];
    ,
        temp = {Table[1, {n}], If[## === 1, 0, 1] & /@ sector};
        neg=temp[[2]];
        lpos=Last[Position[sector,1]][[1]];
        For[i=1,i<=n,i++,
            If[sector[[i]]==1,
                zzz=Table[0,{n}];
                zzz[[i]]=1;
                If[i=!=lpos,
                    AppendTo[temp,zzz];
                 ]
            ,
                neg[[i]]=0;
                If[neg=!=Table[0,{n}],
                    AppendTo[temp,neg];
                ]
            ]
        ]
    ];
    temp
]

(*reverse homogeneous ordering*)
RHO[n_Integer]:=RHO[n]=Table[If[ii<=jj,1,0],{ii,1,n},{jj,1,n}]

HOR[n_Integer]:=HOR[n]=Table[If[ii+jj==n+1,1,0],{ii,1,n},{jj,1,n}]

PutAtPositions[x_, y_, n_] := (*technical*)
    Normal[SparseArray[Apply[Rule, Transpose[{x, y}], {1}], {n}]]

R3HO[last_,xx_, n_] := Module[{temp1, temp2,temp3,temp4,temp5,x,y},
    x=Complement[xx,{last}];
    y=Complement[Range[n],{last}];
        temp1 = RHO[Length[y]];
        temp1 = {((PutAtPositions[y, ##, n]) & /@ temp1)[[1]]};
    If[Length[x]>0,
        temp3 = RHO[Length[x]];
        temp3 = (PutAtPositions[x, ##, n]) & /@ temp3;
        If[Length[x]==Length[y],temp3=Drop[temp3,1]]
    ,
        temp3 = {}
    ];
    If[Length[x]<Length[y],
        temp4 = RHO[Length[y] - Length[x]];
        temp4 = Drop[(PutAtPositions[Complement[y, x], ##, n]) & /@ temp4,1];
    ,
        temp4 = {}
    ];
    If[last>0,temp5={Delta[last,n]},temp5={}];
    Join[temp1, temp3,temp4,temp5]
]


(*the orderings have been described*)
(*-----------------------------------------------------------------------*)
(*Now we come to comparing integrals*)


(*the main comparing function. Indeed, the center of everything.
compares two pairs (problem number,set of indices
should be commented inside
*)
HigherPair[xx_,yy_]:=Module[{temp,xs,ys,i,xd,yd,x,y,pn,totaltemp,xr,yr,xsn,ysn,xdn,ydn,ordering,rho},
        (*comparing problem numbers first*)
    If[xx[[1]]<yy[[1]],Return[True]];
    If[xx[[1]]>yy[[1]],Return[False]];
    pn=xx[[1]];
    x=xx[[2]];
    y=yy[[2]];
    If[x==y,Return[True]];
    If[Head[ExampleDimension[pn]]===ExampleDimension,
        For[i=1,i<=Length[x],i++,
            If[x[[i]]<y[[i]],Return[True]];
            If[x[[i]]>y[[i]],Return[False]];
        ];
    ];
    (*finding sectors*)
    xs=SSector[pn,x];
    ys=SSector[pn,y];
        (*boundary conditions - zero intergrals are surely low*)
    If[And[SBasisR[pn,xs]==False,SBasisR[pn,ys]==True],Return[True]];
    If[And[SBasisR[pn,xs]==True,SBasisR[pn,ys]==False],Return[False]];
        (*finding the maximum regions*)
    xr=MaxRegion[pn,xs];
    yr=MaxRegion[pn,ys];
        (*we assume that the reduction does not go from regions
        with smaller numbers to regions with bigger ones;
        thus comparing region numbers*)
    If[xr<yr,Return[True]];
    If[xr>yr,Return[False]];
        (*if it is a region without a basis we will do normal comparing inside*)
    If[And[xr>0,Or[SBasisL[pn,SBasisM[pn][[xr]]]===0,Head[SBasisL[pn,SBasisM[pn][[xr]]]]===SBasisL]],
        xr=yr=0;
    ];
        (*for points in regions we will consider regions instead of sectors*)
    xsn=If[xr===0,xs,SBasisM[pn][[xr]]];
    ysn=If[yr===0,ys,SBasisM[pn][[yr]]];
    If[xsn===ysn, (*if they are in the same region*)
            (*finding degrees of points*)
        xd=Pair2Degree[{pn,x}];
        yd=Pair2Degree[{pn,y}];
            (*the degrees in sense of regions, others are parameters*)
        xdn=Table[If[xsn[[here]]===0,0,xd[[here]]],{here,1,Length[x]}];
        ydn=Table[If[ysn[[here]]===0,0,yd[[here]]],{here,1,Length[x]}];
            (*if there is no ordering defined yet, we set one*)
        If[Head[SBasisO[pn,xsn]]===SBasisO,SBasisO[pn,xsn]=LOrdering[xsn]];
        ordering=If[Head[SBasisO[pn,xsn]]===SBasisO,RHO[Length[x]],SBasisO[pn,xsn]];
            (*comparing those degrees; if we are in real sectors,
            not regions, comparing will stop here*)
        For[i=1,i<=Length[x],i++,
            temp=Total[(xdn-ydn)*ordering[[i]]];
                (*a little more complicated comparing in case of
                regularized lines - that line stands at the end of
                the ordering, but the value can be both positive
                and negative. For hystorical reasons, the positive
                one are considered to be lower*)
            If[And[SBasisRL[pn]>0,i==Length[x]],
                If[And[xdn[[SBasisRL[pn]]]<0,ydn[[SBasisRL[pn]]]>=0],Return[True]];
                If[And[xdn[[SBasisRL[pn]]]>=0,ydn[[SBasisRL[pn]]]<0],Return[False]];
                If[And[xdn[[SBasisRL[pn]]]<0,ydn[[SBasisRL[pn]]]<0],Return[xdn[[SBasisRL[pn]]]<=ydn[[SBasisRL[pn]]]]];
                If[And[xdn[[SBasisRL[pn]]]>=0,ydn[[SBasisRL[pn]]]>=0],Return[xdn[[SBasisRL[pn]]]>=ydn[[SBasisRL[pn]]]]];
            ];
            If[temp<0,Return[False]];
            If[temp>0,Return[True]];
        ];
        rho=HOR[Length[x]];
            (*ok now, if the degrees in terms of regions are the same,
            then we get to compare what remains - the indices that
            are 0 in the region definition can be abritrary now;
            first we compare the sectors of points*)
        For[i=1,i<=Length[x],i++,
            temp=Total[(xs-ys)*rho[[i]]];
            If[temp<0,Return[False]];
            If[temp>0,Return[True]];
        ];
            (*and now the remaining parts of degrees*)
        For[i=1,i<=Length[x],i++,
            temp=Total[(xd-yd)*ordering[[i]]];
            If[And[SBasisRL[pn]>0,i==Length[x]],
                If[And[xd[[SBasisRL[pn]]]<0,yd[[SBasisRL[pn]]]>=0],Return[True]];
                If[And[xd[[SBasisRL[pn]]]>=0,yd[[SBasisRL[pn]]]<0],Return[False]];
                If[And[xd[[SBasisRL[pn]]]<0,yd[[SBasisRL[pn]]]<0],Return[xd[[SBasisRL[pn]]]<=yd[[SBasisRL[pn]]]]];
                If[And[xd[[SBasisRL[pn]]]>=0,yd[[SBasisRL[pn]]]>=0],Return[xd[[SBasisRL[pn]]]>=yd[[SBasisRL[pn]]]]];
            ];
            If[temp<0,Return[False]];
            If[temp>0,Return[True]];
        ];
        ,   (*if the regions of points are different*)
        temp=(If[##===0,-1,##]&/@xsn)-(If[##===0,-1,##]&/@ysn);
        totaltemp=Total[temp];
            (*then we first compare the total sums of indices,
            corresponding to the number of non-trivial lines in
            the diagram*)
        If[totaltemp<0,Return[False]];
        If[totaltemp>0,Return[True]];
            (*now we check if there are s-bases in sectors - a
            sector with a basis will be lower than a sector
            without so that the symmetries would send the
            integrals in a right direction*)
        If[And[SBasisL[pn,xs]==0,SBasisL[pn,ys]>0],Return[True]];
        If[And[SBasisL[pn,xs]>0,SBasisL[pn,ys]==0],Return[False]];
            (*same for new type bases*)
        If[And[Head[SBasisN[pn,xs]]===SBasisN,Head[SBasisN[pn,ys]]=!=SBasisN],Return[True]];
        If[And[Head[SBasisN[pn,xs]]=!=SBasisN,Head[SBasisN[pn,ys]]===SBasisN],Return[False]];
            (*the same goes for rules in sectors*)
        rho=HOR[Length[x]];
            (*and if nothing is left, we compare the sector by a
            total ordering*)
        For[i=2,i<=ExampleDimension[pn],i++,
            totaltemp=Total[temp*rho[[i]]];
            If[totaltemp<0,Return[False]];
            If[totaltemp>0,Return[True]];
        ];
    ];
    Print["HigherPair error"]; (*should not happen normally*)
    Print[xx];Print[yy];Abort[];
]

(*the definition for comparing two numbers
as you see, there is a special treatement of negative numbers,
for they do not correspond to real integrals
the II[negative number] points at the corner of the sector,
this "integral" appeared in.
All negatives corresponding to a sector are needed before
the substitutions in it, so are higher than all points
of the sector.*)
HigherNumber[x_,y_]:=(GetIntegralNumber[x]>=GetIntegralNumber[y])
HighestNumberPosition[x_]:=Ordering[x,1,HigherNumber][[1]];
HighestNumber[x_]:=x[[Ordering[x,1,HigherNumber][[1]]]];
LowestNumber[x_]:=x[[Ordering[x,-1,HigherNumber][[1]]]];

(*done with comparing*)
(*--------------------------------------------------------*)


(*-------------------------------------------------------*)
(*now here is the main function
the main cycle consists of running repeatedly the
EvaluateList function and the Laporta algorithm
on the points that were left irreducible.
After nothing else can be done, the list is sorted and everything
is substituted. If there are bases or rules or symmetries
everywhere, so that the Laporta algorithm is not needed,
then there are made NO substitutions in the main cycle.
Look at the description of EvaluateList lower*)

F[x_List]:=F[0,x]

F[number_Integer, x_, options:OptionsPattern[Global`FIRE]] := Module[{xx,list,temp,BackList,timecounter},
    Clear[ELMet,EL,ELLength];
    ELLength[Infinity]=0;
    EvaluateAndSaveQ=False;
    InitializeValues[];
    CheckInput[number,x];
    If[INTERNALERROR,Abort[]];
    CheckAbort[
        xx={number,x};
        If[Head[GetTableD[ObtainNN[xx]]]===TableD,Print["EVALUATING ",xx]];
        If[Done[ObtainNN[xx]],Return[Answer[ObtainNN[xx], options]]];
        Clear[ELLength];
        temp = Transpose[{Range[RealSectors], Table[0, {RealSectors}]}];
        temp = {ELLength[##[[1]]], ##[[2]]} & /@ temp;
        temp = Apply[Set, temp, {1}];
        BackList=EvaluateList[{ObtainNN[xx]},RealSector2Number[RealSector[xx]], options];
        timecounter=MyTimeUsed[];
        BackList=Sort[BackList,HigherNumber];
        timecounter=MyTimeUsed[]-timecounter;
        If[Length[BackList]>1,Print["SORTING THE LIST OF ",Length[BackList]," INTEGRALS: ",timecounter," seconds."]];
        timecounter=MyTimeUsed[];
        Substitute[BackList,False];
        timecounter=MyTimeUsed[]-timecounter;
        If[Length[BackList]>1,Print["Substituting ",Length[BackList]," values: ",timecounter," seconds."]];
        Print["Total time: ",MyTimeUsed[]-totaltimecounter," seconds"];
        Return[Answer[ObtainNN[xx], options]];
    ,
        Print["Internal error."];
        INTERNALERROR=True;
        Abort[];
    ]
]

EvaluateAndSave[list_,file_,options:OptionsPattern[Global`FIRE]] := Module[{xx, timecounter},
    TotalIntegralsInvolved=0;
    EvaluateAndSaveQ=True;
    InitializeValues[];
    CodeInfo[];
    (CheckInput[##[[1]],##[[2]]];If[INTERNALERROR,Abort[]])&/@list;
    CheckAbort[
        BackList=EvaluateList[ObtainNN/@list,1, options];
        timecounter=MyTimeUsed[];
        BackList=Sort[BackList,HigherNumber];
        timecounter=MyTimeUsed[]-timecounter;
        If[Length[BackList]>1,Print["SORTING THE LIST OF ",Length[BackList]," INTEGRALS: ",timecounter," seconds."]];
        If[QuitAfterSorting === 1,
            AbortFromQuitAfterSorting = True;
            Abort[];
        ];
        If[QuitAfterSorting === 2,
            Cleanup[];
            Quit[];
        ];
        Substitute[BackList,False];
        If[Length[BackList]>1,Print["Substituting ",Length[BackList]," values: ",timecounter," seconds."]];
        Print["Total time: ",MyTimeUsed[]-totaltimecounter," seconds"];
        Print["Memory: ",MemoryInUse[]];
        Print["Total integrals involved: ",Length[BackList]+TotalIntegralsInvolved];
        Print["Imaginary: ",NegativeNumber];
        SaveTables[file,list];
        ClearTables[]
    ,
        If[Not[AbortFromQuitAfterSorting],
            Print["Internal error."];
            INTERNALERROR=True;
            Abort[];
        ];
    ]
]


(*--------------------------------------------------------*)
(*the next function is one of the main parts of the algorithm
being submitted a list of needed integrals it takes them one by
one and tries to obtain a proper expression for each of those
(without the use of the Laporta algorithm)
The integrals that appear in proper expressions are again added to
the list of integrals that have to be considered.
There are different functions that are executed in attempt
to obtain proper expressions:
TryRules - an attmpt to apply manually inserted rules
TryRestrictions - boundary conditions
TrySymmetries - use of symmetries
Another function, MakeBackList is similar to EvaluateList,
but it does not create any expressions. Instead, it takes
the input integrals and simply forms a list of integrals,
that appear in the already existing expressions of those
(again, going down recursively). In has one more parameter,
a corner point of a sector. It means that the algorithm
creates expressions only in this sector and does not go lower.
This is needed in the Laporta algorithm, where we get a new IBP
and have to substitute all that we know into it
(but the tails are kept masked)
*)

CurrentListAdd[x_,new_]:=Module[{i}, (*run by EvaluateList or
            MakeBackList to add an integral to the
            list of integrals that have to be considered*)
    If[new,stepcounter++];
    If[Head[Met[##]]===Met,
        Met[##]=True;
        needed++;
        Elements[needed]=##;
    ]&/@x;
]

BackListAdd[x_]:=Module[{temp}, (*run by EvaluateList or
            MakeBackList to put the integral
            to the list of integrals that will requre a substitution in the end*)
    tosubstitute++;
    BackElements[tosubstitute]=x;
]

ELAdd[x_,new_]:=Module[{n},
    If[new,stepcounter++];
    If[Head[ELMet[##]]===ELMet,
        ELMet[##]=True;
        n=RealSectorNumber[##];
        ELLength[n]=ELLength[n]+1;
        EL[n,ELLength[n]]=##;
    ]&/@x;
]

LaportaConditions[xx_, options:OptionsPattern[Global`FIRE]]:=Module[{pn,x,ssector,r,temp,min},
    If[Not[OptionValue["UsingIBP"]],Return[False]];
    {pn,x}=xx;
    ssector=SSector[pn,x];
    r=MaxRegion[pn,ssector];
    If[r>0,
        If[SBasisL[pn, SBasisM[pn][[r]]] > 0, Return[False]]
        ,
        If[And[Head[SBasisN[pn, ssector]] === List,Not[SBasisN[pn, ssector]==={}]], Return[False]];
        If[SBasisL[pn, ssector] > 0, Return[False]];
        If[SBasisR[pn, ssector], Return[False]];
        If[Head[LRules[pn, ssector]]===List, Return[False]];
        temp=DoubleOrbit[{pn,ssector}];
        min=LowestNumber[ObtainNN[##[[1]]]&/@temp];
        If[Not[GetII[min]==={pn,ssector}],Return[False]];
    ];
    Return[True];
]

RealSector[{pn_, x_}] := Module[{s, r},
    s = SSector[pn, x];
    If[SBasisR[pn, s], Return[{Infinity, {}}]];
    r = MaxRegion[pn, s];
    If[And[
            Or[SBasisL[pn, SBasisM[pn][[r]]] === 0,
            Head[SBasisL[pn, SBasisM[pn][[r]]]] === SBasisL]
        ],
        Return[{pn, s}],
        Return[{pn, (SBasisM[pn][[r]]) /. {0->1}}]
    ]
];

EnumerateRealSectors[] := Module[{tem, temp2, temp},
   temp = DefinedFor[SBasisR];
   temp = RealSector /@ temp;
   temp = Union[temp];
   temp = Complement[temp, {{Infinity, {}}}];
   temp = Sort[temp, HigherPair];
   RealSectors = Length[temp];
   Clear[RealSector2Number, Number2RealSector];
   temp = Transpose[{temp, Range[RealSectors]}];
   temp2 = {RealSector2Number[##[[1]]], ##[[2]]} & /@ temp;
   Apply[Set, temp2, {1}];
   temp2 = {Number2RealSector[##[[2]]], ##[[1]]} & /@ temp;
   Apply[Set, temp2, {1}];
   RealSector2Number[{Infinity, {}}] = Infinity;
];

RealSectorNumber[x_] := RealSector2Number[RealSector[GetII[x]]]

WorkInRealSector[SN_, options:OptionsPattern[Global`FIRE]]:=Module[{temp,i,y,timecounter,BackList,ttt,tbd,LaportaSector,integral},
    timecounter=MyTimeUsed[];
    Clear[Met,IrList];
    If[ELLength[SN]==0,Return[]];
    If[SN<Infinity,
        ttt=Number2RealSector[SN];
        For[i=1,i<=Length[SBasisM[ttt[[1]]]],i++,
            If[ttt[[2]]===(SBasisM[ttt[[1]]][[i]]/.(0->1)),
                ttt[[2]]=(SBasisM[ttt[[1]]][[i]]);
                Break[]
            ];
        ];
        Print["Working in sector ",SN,"/",RealSectors,": ",StringReplace[ToString[ttt]," "->""]]
    ];
    LaportaSector=If[SN<Infinity,If[Times@@ttt[[2]]===0,False,LaportaConditions[Number2RealSector[SN], options]],False];
    ELcounter=1;
    If[LaportaSector,
        Laporta[SN, options];
        ELcounter=1;
        While[ELcounter<=ELLength[SN],
            y=EL[SN,ELcounter];
            tbd=GetTableD[y];
            ELAdd[tbd,False]; (*THIS IS IMPORTANT!*)
            ELcounter++;
        ];
        Print["Sector complete"];
        If[And[EvaluateAndSaveQ,SN<Infinity],
            SPointLocal=ObtainNN[{Number2RealSector[SN][[1]],SPoint[Number2RealSector[SN][[2]]]}];
            timecounter=MyTimeUsed[];
            temp=Complement[(##[[1]]) & /@ GetDefinedTableD[],
                Union[{SPointLocal},Table[EL[SN,i],{i,ELLength[SN]}]]];
            i=0;
            (If[InThisSector[##,SPointLocal],i++;ClearTable[##]])&/@temp;
            timecounter=MyTimeUsed[]-timecounter;
            Clear[TableIBP];
            TotalIntegralsInvolved=TotalIntegralsInvolved+i;
            If[i>0,Print["CLEARING ",i," INTEGRALS: ",timecounter," seconds."]];
        ];
    ,
        While[ELcounter<=ELLength[SN],
            y=EL[SN,ELcounter];
            integral=GetII[y];
            If[Head[ExampleDimension[integral[[1]]]]===ExampleDimension,
                Print["No start file loaded for problem ",integral[[1]]];
                Abort[]
            ];
            tbd=GetTableD[y];
            If[Not[Head[tbd]===TableD],
                If[tbd=!={y},
                    ELAdd[tbd,False];
                ];
                ELcounter++;Continue[];
            ];
            If[TryRestrictions[integral],
                ELcounter++;Continue[];
            ];
            If[Or[TrySymmetries[integral],TryLRules[integral, options]],
                tbd=GetTableD[y];
                ELAdd[tbd,True];
                ELcounter++;Continue[];
            ];
            MakeIrreducible[y, options];
            ELcounter++;
        ];
        If[SN<Infinity,Print[ELLength[SN]," new relations produced: ",MyTimeUsed[]-timecounter," seconds"]];
    ];
]

InThisSector[x_,y_]:=Module[{temp,xx,yy,pn},
    xx=GetII[x];
    yy=GetII[y];
    If[xx[[1]]===yy[[1]],pn=xx[[1]];SSector[pn,xx[[2]]]===SSector[pn,yy[[2]]],False]
]

EvaluateList[list_, SNStart_, options:OptionsPattern[Global`FIRE]]:=Module[{temp,i,y,timecounter,BackList,c,SN},
    Clear[ELMet,EL,ELLength];
    For[i=1,i<=RealSectors,i++,ELLength[i]=0];
    ELLength[Infinity]=0;
    stepcounter=0;needed=0;calculated=0;tosubstitute=0;
    timecounter=MyTimeUsed[];
    ELAdd[list,False];
    For[SN=SNStart,SN<=RealSectors,SN++,
        WorkInRealSector[SN, options];
    ];
    WorkInRealSector[Infinity, options];
    timecounter=MyTimeUsed[]-timecounter;
    If[stepcounter>0,Print["GENERATING ",stepcounter," NEW RELATIONS: ",timecounter," seconds."]];
    Return[(EL @@ ##) & /@ DeleteCases[DefinedFor[EL], {Infinity, x_}]];
]

MakeBackList[list_,SPoint_]:=Module[{temp,i,y,timecounter,BackList,tbd},
    IPoint=SPoint;
    Clear[Met,Elements,BackElements];
    stepcounter=0;needed=0;calculated=0;tosubstitute=0;
    timecounter=MyTimeUsed[];
    CurrentListAdd[list,False];
    While[calculated<needed,
        ClearSystemCache[];
        calculated++;
        y=Elements[calculated];
        If[y<0,Continue[]];
        tbd=GetTableD[y];
        If[Or[tbd==={y},Head[tbd]===TableD],
            If[HigherNumber[y,IPoint],IPoint=y]
        ,
            If[HigherNumber[y,SPoint],
                CurrentListAdd[tbd,False];
                BackListAdd[y];
            ];
        ];
    ];
    BackList=Table[BackElements[i],{i,tosubstitute}];
    Clear[Met,Elements,BackElements];
    BackList=Sort[BackList,HigherNumber];
    timecounter=MyTimeUsed[]-timecounter;
    Return[BackList];
]


(*-------------------------------------------------------*)
(*the following functions have been described before the
EvaluateList function. There all are aiming to produce proper
expressions for a given integral*)

TryRestrictions[yy_]:=Module[{temp,y,pn},
    {pn,y}=yy;
    If[SBasisR[pn,SSector[pn,y]]===True,
        MakeZeroTable[ObtainNN[yy]];
        Return[True]
    ,
        Return[False]
    ];
]

SymmetryTransformation[xx_]:=SymmetryTransformation[xx,False]

SymmetryTransformation[xx_,OnlyThisSector_]:=Module[{temp,min,i},
    temp=DoubleOrbit[xx];
    If[OnlyThisSector,temp=Select[temp,((SSector@@(##[[1]]))===(SSector@@xx))&]];
    temp={ObtainNN[##[[1]]],##[[2]]}&/@temp;
    temp=Union[temp];
    min=LowestNumber[##[[1]]&/@temp];
    i=1;
    While[i<=Length[temp],
        If[temp[[i]][[1]]==min,Return[{GetII[min],(Times @@ ((temp[[i]][[2]])^(xx[[2]])))}]];
        i++
    ];
    Print["SymmetryTransformationError"];
    Abort[];
]

TrySymmetries[yy_]:=TrySymmetries[yy,False]

TrySymmetries[yy_,OnlyThisSector_]:=Module[{temp,y,nn,tbd},
    tbd=GetTableD[ObtainNN[yy]];
    If[And[Head[tbd]===List,Length[tbd]>1],Return[True]];
    temp=SymmetryTransformation[yy,OnlyThisSector];
    If[Not[temp[[1]]===yy],
        Clear[Coeff];
        nn=ObtainNN[temp[[1]]];
        Coeff[nn]=MyToString[temp[[2]],InputForm];
        MakeTable[ObtainNN[yy],{nn}];
        Return[True]
    ,
        Return[False]
    ];
]

RulesTransformation[xx_, options:OptionsPattern[Global`FIRE]]:=Module[{sector,GG,i,el,dd,c,pn,x,yy,temp,tempelement},
    {pn,x}=xx;
    GG=OptionValue["ResultVar"][pn,x];
    If[Head[NewRules[pn]]===NewRules,Return[xx]];
    temp=GG/.NewRules[pn];
    If[temp===GG,Return[xx]];
    Clear[tempCoeff];
    If[temp===0,Return[{}]];
    tempelement=Union[Cases[temp, OptionValue["ResultVar"][yy__], {0, Infinity}]];
    temp={#,Coefficient[temp,#]}&/@tempelement;
    temp=temp/.OptionValue["ResultVar"]->List;
    tempelement=tempelement/.OptionValue["ResultVar"]->List;
    temp = {tempCoeff[#[[1]]], #[[2]]/.CFT->Identity} & /@ temp;
    Apply[Set, temp, {1}];
    Return[tempelement];
]

NewLeeOrdering[sector_] := Module[{temp, n, ones, neg, hasneg, pos, haspos, i},
    n = Length[sector];
    temp = {};
    ones = Table[1, {n}];
    AppendTo[temp, ones];
    hasneg = False; haspos = False;
    neg = If[## === -1, hasneg = True; 1, 0] & /@ sector;
    pos = If[## === 1, haspos = True; 1, 0] & /@ sector;
    If[And[hasneg, haspos], AppendTo[temp, neg]];
    If[haspos,
        For[i = 1, i <= n, i++,
            If[pos[[i]] === 1,
                pos[[i]] = 0;
                AppendTo[temp, pos];
            ];
        ];
    ];
    If[hasneg,
        For[i = 1, i <= n, i++,
            If[neg[[i]] === 1,
                neg[[i]] = 0;
                AppendTo[temp, neg];
            ];
        ];
    ];
    temp = DeleteCases[temp, Table[0, {n}]];
    temp
]

LoadLRules[directory_String, pn_Integer, options:OptionsPattern[Global`FIRE]] := Module[{temp, files, i, sector,heads},
    If[Burning,Print["FIRE is burning, can't load more rules"];Abort[]];
    (Set @@ {SBasisN @@ ##, {}}) & /@ DefinedFor[SBasisL];
    SetDirectory[directory];

    files = Select[
        FileNames[],
        And[FileType[##] === File, StringLength[##] >= 11, StringTake[##, 11] === "ZeroSectors"] &
    ];
    temp = Get[files[[1]]];
    Set[SBasisR[pn,Replace[List@@Drop[##,1],0->-1,{0,Infinity}]],True]&/@temp;

    files = Select[
        FileNames[],
        And[FileType[##] === File, StringLength[##] >= 6, StringTake[##, 6] === "jRules"] &
    ];
    For[i = 1, i <= Length[files], i++,
        temp = Get[files[[i]]];
        sector = If[## === 1, 1, -1] & /@ Drop[List @@ ToExpression[files[[i]]], 1];
        If[Head[temp] =!= List,
            temp={temp};
        ];
        heads=Head/@temp;
        If[Length[Union[heads]]=!=1,
            Print["Bad rule mixture"];
            Print[files[[i]]];
            Abort[];
        ];
        If[And[heads[[1]]===RuleDelayed,Length[heads]>1],
            Print["Too many delayed rules"];
            Print[files[[i]]];
            Abort[];
        ];
        If[heads[[1]]===RuleDelayed,  (*symmetry rule*)
            SBasisN[pn, sector] =.;
        ,
            SBasisO[pn,sector]=NewLeeOrdering[sector];
        ];
        LRules[pn, sector] = temp /. LiteRed`j[a__] :> OptionValue["ResultVar"][pn, Drop[{a}, 1]];
    ];
    ResetDirectory[];
]

LRulesTransformation[xx_, options:OptionsPattern[Global`FIRE]] := Module[{pn, x, sector, temp, tempelement,lrules},
    Clear[tempCoeff];
    {pn, x} = xx;
    sector = SSector[pn, x];
    lrules=LRules[pn,sector];
    If[Head[lrules]===LRules, Return[xx]];
    temp = OptionValue["ResultVar"][pn, x] /. lrules ;
    temp = temp //. {
        OptionValue["ResultVar"][a__] OptionValue["ResultVar"][b__] :> OptionValue["ResultVar"][{a}[[1]], {a}[[2]] + {b}[[2]]],
        Power[OptionValue["ResultVar"][a__], b_Integer] :> OptionValue["ResultVar"][{a}[[1]], b {a}[[2]]]
    };
    If[temp === OptionValue["ResultVar"][pn, x], Return[xx]];
    If[temp === 0, Return[{}]];
    tempelement = Union[Cases[temp, OptionValue["ResultVar"][yy__], {0, Infinity}]];
    temp = {#, Coefficient[temp, #]} & /@ tempelement;
    temp = temp /. OptionValue["ResultVar"] -> List;
    tempelement = tempelement /. OptionValue["ResultVar"] -> List;
    temp = {tempCoeff[#[[1]]], #[[2]] /. CFT -> Identity} & /@ temp;
    Apply[Set, temp, {1}];
    Return[tempelement];
]

TryLRules[y_, options:OptionsPattern[Global`FIRE]] := Module[{sector, nnn, temp},
    temp = LRulesTransformation[y, options];
    If[Not[temp === y],
        If[temp === {}, MakeZeroTable[ObtainNN[y]]; Return[True]];
        nnn = ObtainNN /@ temp;
        If[
            HigherNumber[HighestNumber[nnn], ObtainNN[y]],
            Print["Bad rule for ", y]; Print[GetII[HighestNumber[nnn]]];
            Abort[]
        ];
        (Coeff[ObtainNN[##]] = MyToString[tempCoeff[##], InputForm]) & /@ temp;
        MakeTable[ObtainNN[y], nnn];
        Return[True]
    ,
        Return[False]
    ];
]

TryRules[y_, options:OptionsPattern[Global`FIRE]] := Module[{sector,nnn,temp},
    temp=RulesTransformation[y, options];
    If[Not[temp===y],
        If[temp==={},MakeZeroTable[ObtainNN[y]];Return[True]];
        nnn=ObtainNN/@temp;
        If[HigherNumber[HighestNumber[nnn],ObtainNN[y]],Print["Bad rule for ",y];Abort[]];
        (Coeff[ObtainNN[##]]=MyToString[tempCoeff[##],InputForm])&/@temp;
        MakeTable[ObtainNN[y],nnn];
        Return[True]
    ,
        Return[False]
    ];
]

(*the functions producing proper expressions have been described*)
(*--------------------------------------------------------------------------------*)
(*following are the functions performing substitutions
SubstituteOne evaluates the sum of integrals of list with some
coefficients; in case, when the second parameter is
Null, the coefficients are taken from the variable EqCoeff
(this is the case when the list comes from an IBP)
Otherwise, the coefficients come from TableC[point],
meaning that we are substituting integrals
into a proper expression of point.
The third parameter defines whether we keep negative
numbers not substituted. Is it turned on in the
calls from the Laporta algorithm, since the tail-masking is done
there.
You shoulk keep in mind that the coefficients are stored as
strings (memory-economy), so we first construct an expression
and only then evaluate it, either by making it an expression,
running Together and turning back into a string,
or by an external evaluation call
*)
(*Substitute performs consequent substitutions
of integrals starting from the end of the list.
Again, it has the OnlyPositive parametr for tail masking
*)

SowMany[x_,y_]:=Sow["("<>x<>")*("<>##[[2]]<>")",##[[1]]]&/@y
StringSum[x_] := "0" <> StringJoin @@ (("+" <> ##) & /@ x)

SubstituteOne[list_,point_,OnlyPositive_]:=Module[{temp, Coeff2},
    ClearSystemCache[];
    Clear[Coeff];
    If[point===Null,
        Coeff2=EqCoeff
    ,
        Clear[Coeff2];
        temp={Coeff2[##[[1]]],##[[2]]}&/@(GetTableC[point]);
        Apply[Set,temp,{1}]
    ];
    temp=Reap[(SowMany[Coeff2[##],GetTableC[##]];)&/@list,_,List][[2]];
    temp={##[[1]], StringSum[##[[2]]]} & /@ temp;
    temp={##[[1]],MyToString[Together[ToExpression[##[[2]]]],InputForm]}&/@temp;
    temp=Delete[temp,Position[(##[[2]])&/@temp,"0"]];
    (Coeff[##[[1]]]=##[[2]])&/@temp;
    Return[(##[[1]])&/@temp];
]

Substitute[list_,OnlyPositive_]:=Module[{i,j,k,y,newlist,l,temp,temp2,temp3,tbd,counter,NeedToSubstitute},
    Loaded=Length[list]+1;
    For[counter=Length[list],counter>0,counter--,
        y=list[[counter]];
        tbd=GetTableD[y];
        If[Or[Head[tbd]===TableD,tbd==={y},tbd==={},And[y<0,OnlyPositive]],Continue[]];
        NeedToSubstitute=Or@@((Not[temp=GetTableD[##];Or[Head[temp]===TableD,temp==={##},And[##<0,OnlyPositive]]])&/@tbd);
        If[Not[NeedToSubstitute],Continue[]];
        newlist=SubstituteOne[tbd,y,OnlyPositive];
        If[OnlyPositive,MakeTable2[y,newlist],MakeTable[y,newlist]];
    ];
]

(*substitution functions have been described*)
(*---------------------------------------------------------------------------*)
(*following is the Laporta algorithm
it takes a list of integrals that have to be evaluated as input
and works with them consequently
for a given integrals it calculates its level (LLevel function),
that is normally a pair - the number of dots and the degree of
irreducible nominators. In the cases with regularized lines it
is a triple, with the degree on that line at the third position.
For a level it calls the function NeededLevel, that estimates
the needed level of IBPs, that have to be constructed.
Further, it calls the function UnderLevels, that lists the levels
lower than the needed level, grouped in blocks (we will be
generating IBPs for a whole block afterwards).
Now for each block of levels we call the LevelPoints function,
that lists the points corresponding to this level.
Now we have a set of points, where we have to generate IBPs,
if we haven't done it in the past (the information is in TableIBP).
Thus is done by the MakeRelation function.
The relations are sorted and we start calling the ReduceRelation
function. In should be noted that the process will stop normally
if all the relations have been considered.
But it can also stop if we have obtained proper expressions for
all points in pointslist - a list containing the required integral
and a number of low-level points if we are working with the lowest
block of relations. The reason that those low points are added is
that otherwise we might produce extra masters.
Now about the ReduceRelation function.
It takes the relation as input and runs the MakeBackList function
and then Substitute in order to substitute all existing values
into the relation. Tail-masking is being performed, so we also
pass the corner of the sector as a second argument to avoid
reducing lower. Afterwards, when everything has been substituted
it calls the UseRelation function to produce a proper expression
for the highest remaining term and put it into tables.
*)

UnderLLevels[{x_,y_}]:=Flatten[Outer[List,Range[1,x],Range[1,y]],1]

AddZerosAndReg[MaxReg_,llevel_]:=Module[{level=llevel},
    If[level[[1]]==1,
        If[level[[2]]==1,
            level={{0,0},{1,0},{0,1},{1,1}}
        ,
            level={{0,level[[2]]},{1,level[[2]]}}
        ]
    ,
        If[level[[2]]==1,
            level={{level[[1]],0},{level[[1]],1}}
        ,
            level={level}
        ]
    ];
    If[MaxReg>0,level=AppendDifferent[level,Range[-MaxReg,MaxReg]]];
    Return[level];
]

CheckPoints[SN_,AddNew_,Levels_, options:OptionsPattern[Global`FIRE]]:=Module[{y,tbd,lev1,lev,temp},
    While[ELcounter<=ELLength[SN],
        y=EL[SN,ELcounter];
        If[y<0,ELcounter++;Continue[]];
        tbd=GetTableD[y];
        If[Head[tbd]===TableD,
            If[NewPoint,
                temp=GetII[y];
                lev1=Take[LLevel@@temp,2];
                lev={If[lev1[[1]]===0,1,lev1[[1]]],lev1[[2]]+1};
                If[UsedIBPs[temp[[1]],SSector@@temp,lev],
                    MakeIrreducible[y, options];
                    ELcounter++;
                    Continue[]
                ];
                NewPoint=False;
                If[AddNew,
                    If[Not[MemberQ[Levels,lev]],
                        Print["New level of integrals appeared: ",lev1];
                        temp=Complement[UnderLLevels[lev],Levels];
                        temp=Sort[temp,(If[#1[[1]]+#1[[2]]<#2[[1]]+#2[[2]],True,
                        If[#1[[1]]+#1[[2]]>#2[[1]]+#2[[2]],False,
                            #1[[1]]<#2[[1]]
                         ]
                       ])&];
                        Levels=Join[Levels,temp];
                    ]
                ];
            ];
            Return[False]
        ,
            If[tbd=!={y},ELAdd[tbd,False]];
            ELcounter++;
            NewPoint=True;
        ];
    ];
    Return[True];
]

Laporta[SN_, options:OptionsPattern[Global`FIRE]] := Module[{list, xx, x, d, i, j,k,l,iii,timecounter,ppp,temp,end,pn,ssector,RealLevel,level,MaxReg,ro,rlist,RelationNumber,Levels,levelr,GoodRelations,aa},
    NewPoint=True;
    If[CheckPoints[SN,False,Levels,options],
        Return[];
    ];
    {pn,ssector}=Number2RealSector[SN];
    Print["LAPORTA STARTED: ", ELLength[SN]," integrals for evaluation"];
    If[Head[IBPOrdering[pn,ssector]]===IBPOrdering,
        temp=HighestNumber[MakeRelation[##,{pn,5*ssector}]]&/@Range[SBasis0L[pn]];
        IBPOrdering[pn,ssector]=Ordering[temp,All,(HigherNumber[#1,#2])&];
        (IBPShift2[pn,ssector,##]=    (GetII[temp[[##]]][[2]]-5*ssector))    &/@Range[SBasis0L[pn]];
        (IBPShift[pn,ssector,##]=   (Max[##,0]&/@ ((GetII[temp[[##]]][[2]]-5*ssector)*ssector))*ssector )    &/@Range[SBasis0L[pn]];
    ];

    temp=(GetII[##])&/@Table[EL[SN,i],{i,ELLength[SN]}];

    TrySymmetries/@temp;

    temp=(##[[2]])&/@temp;
    temp=LLevel[pn,##]&/@temp;
    If[Length[temp[[1]]]>2,
        MaxReg=Max@@(Abs[##[[3]]]&/@temp);
        temp=Drop[##,-1]&/@temp
        ,
        MaxReg=0
    ];
    temp=Union[temp];
    Print["Maximal levels: ",DoubleMaxPoints[temp]];

    temp=UnderLLevels[{Max[##[[1]],1],##[[2]]+1}]&/@temp;
    temp=Flatten[temp,1];
    temp=Union[temp];
    temp=Sort[temp,
        (If[#1[[1]]+#1[[2]]<#2[[1]]+#2[[2]],True,
        If[#1[[1]]+#1[[2]]>#2[[1]]+#2[[2]],False,
        #1[[1]]<#2[[1]]
        ]])&
    ];
    Levels=temp;

    For[levelr=1,levelr<=Length[Levels],levelr++,

        RealLevel=Levels[[levelr]];
        If[UsedIBPs[pn,ssector,RealLevel],Continue[]];

        Print[RealLevel];
        timecounter=MyTimeUsed[];

        level=Join[
            AddZerosAndReg[MaxReg,RealLevel+{1,1}],
            If[RealLevel[[2]]===1,AddZerosAndReg[MaxReg,RealLevel+{1,0}],{}],
            If[RealLevel[[1]]===1,AddZerosAndReg[MaxReg,RealLevel],{}]
        ];
        list = ObtainNN/@(Union[Flatten[LevelPoints[pn,##,ssector]&/@level,1]]);
        TrySymmetries[GetII[##],True]&/@list;
        (*where to generate*)
        level=AddZerosAndReg[MaxReg,RealLevel];
        list = ObtainNN/@(Union[Flatten[LevelPoints[pn,##,ssector]&/@level,1]]);
        list=Union[LowestNumber[NOrbit[##]]&/@list];
        RelationNumber = 1;
        Clear[EqCoeff,RelationList,IBPPointer,HML];
        (*generating equations*)
        (
            If[Head[TableIBP[##]] === TableIBP,
                TableIBP[##] = Table[0, {SBasis0L[GetII[##][[1]]]}]
            ];
            If[Head[TableIBP[##]] === List,
                If[OptionValue["LeeIdeas"],
                    For[j=1,j<=SBasis0L[pn],j++,
                        If[MultiMore[pn,ssector*(GetII[##][[2]]),SPoint[ssector]+ssector*IBPShift[pn,ssector,IBPOrdering[pn,ssector][[j]]]],
                            For[k=j+1,k<=SBasis0L[pn],k++,
                                TableIBP[##]=ReplacePart[TableIBP[##],1,IBPOrdering[pn,ssector][[k]]];
                            ];
                            Break[]
                        ]
                    ];
                ];
                For[j = 1, j <= SBasis0L[pn], j++,
                    If[TableIBP[##][[j]] === 1, Continue[]];
                    aa={ObtainNN[{pn,GetII[##][[2]]+IBPShift2[pn,ssector,j]}]};
                    If[Length[aa]>0,
                        HML[RelationNumber]=aa[[1]];
                        IBPPointer[RelationNumber] = {##,j};
                        RelationNumber++;
                    ];
                    Clear[EqCoeff];
                ];
            ];
            (*and back*)
            If[TableIBP[##] === Table[0,{pn}],
                TableIBP[##]=.;
            ];
        )&/@list;
        If[RelationNumber==1,Continue[]];
        ro = Ordering[Range[RelationNumber - 1],All, (HigherNumber[HML[#1], HML[#2]]) &];
        Clear[RO,HML];
        temp=Transpose[{Range[Length[ro]],ro}];
        temp={RO[##[[1]]],##[[2]]}&/@temp;
        Apply[Set,temp,{1}];
        Clear[ro];

        Print["Preparing points, symmetries and ",RelationNumber-1," IBP's: ",MyTimeUsed[]-timecounter," seconds."];
        GoodRelations=0;
        timecounter=MyTimeUsed[];
        Loaded=RelationNumber;
        For[thiscounter = RelationNumber-1, thiscounter > 0, thiscounter--,
            If[CheckPoints[SN,True,Levels,options],
                Print[GoodRelations," new relations produced: ",MyTimeUsed[]-timecounter," seconds."];
                Goto[end]
            ];
            Clear[EqCoeff];
            UsedIBP[IBPPointer[RO[thiscounter]],SBasis0L[pn]];
            rlist=MakeRelation[IBPPointer[RO[thiscounter]][[2]],GetII[IBPPointer[RO[thiscounter]][[1]]]];
            If[ReduceRelation[rlist,ObtainNN[{pn,SPoint[ssector]}]],
                GoodRelations++
            ];
        ];
        Print[GoodRelations," new relations produced: ",MyTimeUsed[]-timecounter," seconds."];
        UsedIBPs[pn,ssector,RealLevel]=True;
        NewPoint=True;
        If[CheckPoints[SN,True,Levels,options],
            Goto[end];
        ];
    ]; (*for*)
    Label[end];
    Clear[EqCoeff,RelationList,IBPPointer];
]

LLevel[pn_,x_]:=If[SBasisRL[pn]>0, (*the level of a point*)
    {Total[If[##>=1,##-1,0]&/@(Delete[x,SBasisRL[pn]])],Total[If[##>=1,0,-##]&/@(Delete[x,SBasisRL[pn]])],x[[SBasisRL[pn]]]-1}
,
    {Total[If[##>=1,##-1,0]&/@(x)],Total[If[##>=1,0,-##]&/@(x)]}
]

NeededLevel[l_]:=  (*the minimal needed level for IBPs*)
    If[Length[l]===2,
        {If[l[[1]]<1,1,l[[1]]],If[l[[2]]<2,2,l[[2]]]}
        ,
        {If[l[[1]]<1,1,l[[1]]],If[l[[2]]<2,2,l[[2]]],Max[Abs[l[[3]]],1]+1}
    ]

AppendOne[x_, y_] := Append[##, y] & /@ x;
AppendDifferent[x_, y_] := Join @@ (AppendOne[x, ##] & /@ y);
(*some technical stuff*)

UnderLevels[l_]:=Module[{i,j,result,temp}, (*the levels lower than
                            the given level grouped in blocks*)
    If[Length[l]===3,
        Return[AppendDifferent[##,Range[-l[[3]],l[[3]]]]&/@UnderLevels[Take[l,2]]];
    ];

    result={{{0,0},{1,0},{0,1},{1,1},{0,2},{1,2}}}; (*starting block*)
    temp={};
    For[j=3,j<=l[[2]],j++,
        AppendTo[temp,{0,j}]
    ];
    If[l[[1]]>1,
        For[j=3,j<=l[[2]],j++,
            AppendTo[temp,{1,j}]
        ];
    ];
    For[i=2,i<l[[1]],i++,
        For[j=0,j<=l[[2]],j++,
            AppendTo[temp,{i,j}]
        ]
    ];
    If[Not[temp==={}],AppendTo[result,temp];temp={}]; (*main block*)
    If[l[[1]]>1,
        For[j=0,j<=l[[2]],j++,
            AppendTo[temp,{l[[1]],j}]
        ],
        For[j=3,j<=l[[2]],j++,
            AppendTo[temp,{l[[1]],j}]
        ]
    ];
    If[Not[temp==={}],AppendTo[result,temp];temp={}]; (*same dot level*)
    result
]

LevelPoints[pn_, level_, ssector_] := Module[{i, j, temp, temp1, temp2, d, pos, sector, temp3},
                (*all points of a given level*)
    If[SBasisRL[pn]>0,sector=ReplacePart[ssector,0,SBasisRL[pn]],sector=ssector];
    (sector=ReplacePart[sector,2,##])&/@HPI[pn];
    If[Length[Cases[sector, 1]] > 0,
        temp1 = MyCompositions[level[[1]], Length[Cases[sector, 1]]];
        pos = Flatten[Position[sector, 1]];
        temp1 = PutAtPositions[pos, ##, Length[sector]] & /@ temp1;
    ,
        temp1 = {Table[0, {Length[sector]}]}
    ];
    If[Length[Cases[sector, -1]] > 0,
        temp2 = MyCompositions[level[[2]], Length[Cases[sector, -1]]];
        pos = Flatten[Position[sector, -1]];
        temp2 = PutAtPositions[pos, ##, Length[sector]] & /@ temp2;
    ,
        temp2 = {Table[0, {Length[sector]}]}
    ];
    If[Length[Cases[sector, 0]] > 0,
        temp3 = (level[[3]])*Delta[SBasisRL[pn],Length[sector]];
    ,
        temp3 = Table[0, {Length[sector]}]
    ];
    temp = Flatten[Table[
        temp1[[i]] + temp2[[j]], {i, 1, Length[temp1]},
        {j, 1, Length[temp2]}], 1
    ];

    temp = {pn, temp3+Degree2Point[##, sector/.{2->1}]} & /@ temp;
    temp
]


MakeRelation[n_,shift_]:=Module[{i,j,temp,Coe,p,pos,ssector},
                                          (*produces an IBP*)
    tempelement=Reap[
        (temp={shift[[1]],##+shift[[2]]};
        Coe=Expand[OldCoeffForm[SBasis0C[shift[[1]],n,##]]/.AVRulesD[shift[[2]]]];
        If[Not[Coe===0],EqCoeff[Sow[ObtainNN[temp]]]=MyToString[Coe,InputForm]];
        )&/@SBasis0D[shift[[1]],n];
    ][[2]];
    If[Length[tempelement]===0,Return[{}],tempelement=tempelement[[1]]];
    Return[tempelement];
]

ReduceRelation[list_,point_]:=Module[{temp,i,xx,BackList,timecounter,j,l,result},
    BackList=MakeBackList[list,point];
    If[And[Length[BackList]>0,HigherNumber[point,BackList[[1]]],Not[point===BackList[[1]]]],Return[False]];
    Substitute[BackList,True];
    result=SubstituteOne[list,Null,True];
    result=UseRelation[result,point];
    Return[result];
]

UseRelation[list_,point_]:=Module[{temp,xx,ccc,iii,j,tbd},
                    (*is called after everything has been
                    substituted, makes a new proper expression*)
   If[Length[list]>0,
        j=HighestNumberPosition[list];
        xx=list[[j]];
        tbd=GetTableD[xx];
        If[Not[Head[tbd]===TableD],Return[False]];
        If[And[HigherNumber[point,xx],Not[point===xx]],Return[False]];
        ccc=Coeff[xx];
        (Coeff[##]="-("<>Coeff[##]<>")/("<>ccc<>")")&/@list;
        Coeff[xx]=.;
        MakeTable2[xx,Delete[list,j]];
        Return[True]
    ,
        Return[False]
    ];
]

SProjection[x_,ssector_]:=Module[{i},      (*the positive part of a vector is a sector*)
    Table[If[x[[i]]*ssector[[i]]>0,x[[i]],0],{i,1,Length[x]}]
]


(*produces the IBPs in a sector and sorts the elements in a way
that the elements will be for a general point of a sector;
Is used to determine the highest member of an IBP when possible*)
IBPShifts[pn_, ssector_,i_] := IBPShifts[pn,ssector,i] = Module[{spoint,temp},
    spoint = SPoint[ssector];
    (GetII[##][[2]] - spoint - ssector)&/@
        Sort[Evaluate[ObtainNN[{pn, ## + spoint + ssector}] & /@ SBasis0D[pn, i]],HigherNumber]
]

UsedIBP[x_,y_]:=Module[{temp},
    If[TableIBP[x[[1]]],Return[]];
    If[Head[TableIBP[x[[1]]]]===TableIBP,TableIBP[x[[1]]]=Table[0,{y}]];
    (TableIBP[x[[1]]]=ReplacePart[TableIBP[x[[1]]],1,x[[2]]]);
    If[Times@@TableIBP[x[[1]]]===1,TableIBP[x[[1]]]=True];
]
(*writes into tables that an IBP has been used*)


(*--------------------------------------------------------------*)
(*The following functions are used to load start files, rules and s-bases.
The basic idea is that you can use the LoadSBases and LoadStart commands
in two ways - either simply naming a file or also naming a number,
that will be the problem number for the start or basis being loaded.
The bases or start files are stored without a problem number
specified. If you load them without a number, then the problem
number is assumed (that can be used for fast tests, but in real
problems you will require multiple problems at the same time).
So if the bases or tables are loaded with a number, then
first the 0 bases or start are cleared with the ClearSBases or
ClearStart(!!!) function. Then the problems are assigned with
the CopySBases or CopyStart(!!!) functions.
*)


CreateProblem[pn_,n_]:=Module[{temp,sectors},
    ExampleDimension[pn]=n;
    SBasis0L[pn]=0;
    HPI[pn]={};
    SBasisM[pn]={};
    SBasisRL[pn]=0;
    SBasisS[pn]={{Range[n],Table[1,{n}],Table[0,{n}]}}; (*symmetries*)
    sectors=Flatten[Outer @@ Prepend[Table[{-1, 1}, {n}], List], n-1];
    temp={SBasisR[pn,##],False}&/@sectors;
    Apply[Set,temp,{1}];
    temp={SBasisL[pn,##],0}&/@sectors;
    Apply[Set,temp,{1}];
]

LoadSBases[x_]:=Module[{temp,FILES},
    If[Burning,Print["FIRE is burning, can't load more sbases"];Abort[]];
    FILES=x;
    ClearSBases[0];
    Get[FILES <> ".sbases"];
    If[Head[SBasisM[0]]==SBasisM,SBasisM[0]={}];
    If[Head[HPI[0]]===HPI,HPI[0]={}];
    If[And[Not[Head[SBasis0L[0]]===SBasis0L],Not[NumberQ[Head[SBasis0L[0]]]]],
        Print["SBases loaded"];
        ProblemFileName[0]=FILES;
    ,
        Print["SBases not loaded - probably an old file format"];
    ]
]

LoadSBases[x_,number_] := Module[{temp,FILES},
    If[Burning,Print["FIRE is burning, can't load more start files"];Abort[]];
    If[number==0,Print["Problem number should not be equal to zero"];Return[]];
    FILES=x;
    ClearSBases[0];
    Get[FILES <> ".sbases"];
    If[Head[SBasisM[0]]==SBasisM,SBasisM[0]={}];
    If[Head[HPI[0]]===HPI,HPI[0]={}];
    If[And[Not[Head[SBasis0L[0]]===SBasis0L],Not[NumberQ[Head[SBasis0L[0]]]]],

        If[Length[SBasisS[0][[1]]]===2,SBasisS[0]={##[[1]],##[[2]],Table[0,{Length[##[[1]]]}]}&/@SBasisS[0]];

        Print["SBases loaded"];
        ClearSBases[number];
        CopySBases[0,number];
        ClearSBases[0];
        ProblemFileName[number]=FILES;
        SetSBasisM[number];
    ,
        Print["SBases not loaded - probably an old file format"];
    ]
]

LoadStart[FILES_]:=LoadStart[FILES,0];

LoadStart[FILES_,pn_]:=Module[{temp},
    If[Burning,Print["FIRE is burning, can't load more start files"];Abort[]];
    ProblemNumber=0;
    ClearStart[0];
    Get[FILES <> ".start"];

    If[And[Not[Head[SBasis0L[0]]===SBasis0L],Not[NumberQ[Head[SBasis0L[0]]]]],

        If[Length[SBasisS[0][[1]]]===2,SBasisS[0]={##[[1]],##[[2]],Table[0,{Length[##[[1]]]}]}&/@SBasisS[0]];
        If[Head[HPI[0]]===HPI,HPI[0]={}];
        Print["Initial data loaded"];
        If[Not[pn===0],ProblemNumber=pn;CopyStart[0,ProblemNumber];ClearStart[0]];
        ,
        Print["Failed"];
        Clear[SBasisL,ExampleDimension,SBasisR,SBasisRL,SBasisS,SBasis0L,SBasis0D,SBasis0C,SBasisM];
        Return[]
    ];
    If[Head[SBasisRL[ProblemNumber]]===Symbol,SBasisRL[ProblemNumber]=0];
    If[Head[HPI[0]]===HPI,HPI[0]={}];
    If[ProblemNumber>0,SetSBasisM[ProblemNumber]];
];

ClearStart[n_]:=Module[{temp},
    temp={ExampleDimension,SBasis0L,SBasis0D,SBasis0C,SBasisL,SBasisS,SBasisR,SBasisRL,SBasisM,HPI};
    ClearForFirst[##,n]&/@temp;
]

CopyStart[value1_,value2_]:=Module[{temp},
    temp={ExampleDimension,SBasis0L,SBasis0D,SBasis0C,SBasisL,SBasisS,SBasisR,SBasisRL,SBasisM,HPI};
    CopyWithFirst[##,value1,value2]&/@temp;
]

ClearSBases[n_]:=Module[{temp},
    temp={ExampleDimension,SBasis0L,SBasis0D,SBasis0C,SBasisL,SBasisD,SBasisA,SBasisH,SBasisO,SBasisC,SBasisS,SBasisR,SBasisRL,SBasisM,HPI,SBasisN,LRules};
    ClearForFirst[##,n]&/@temp;
]

CopySBases[value1_,value2_]:=Module[{temp},
    temp={ExampleDimension,SBasis0L,SBasis0D,SBasis0C,SBasisL,SBasisD,SBasisA,SBasisH,SBasisO,SBasisC,SBasisS,SBasisR,SBasisRL,SBasisM,HPI,SBasisN,LRules};
    CopyWithFirst[##,value1,value2]&/@temp;
]

SetSBasisM[number_]:=Module[{temp},
    If[And[Head[SBasisM[number]]===List,Length[SBasisM[number]]>0],Return[]];
    If[Head[SBasisM[number]]===SBasisM,SBasisM[number]={}];
    temp={};
    temp=Select[temp,(##[[1]]===number)&];
    If[And[Times@@(##[[2]])===0,Not[MemberQ[SBasisM[number],##[[2]]]]],
        AppendTo[SBasisM[number],##[[2]]]
    ]&/@temp;
    SBasisM[number]=Sort[SBasisM[number],
        If[Position[#1,0]===Position[#2,0],
                And@@((##>=0)&/@(#1-#2))
            ,
            True
        ]&
    ];
]

ClearForFirst[name_,value_]:=Module[{temp,i},
    temp=DefinedFor[name];
    temp=Select[temp,(##[[1]]===value)&];
    Apply[(name[##]=.)&,temp,1];
]

CopyWithFirst[name_,value1_,value2_]:=Module[{temp,i,yyy},
    temp=DefinedFor[name];
    temp=Select[temp,(##[[1]]===value1)&];
    For[i=1,i<=Length[temp],i++,
        yyy=name@@ReplacePart[temp[[i]],value2,1];
        Evaluate[yyy]=name@@temp[[i]]
    ]
]


SaveData[x_] := Module[{temp},
    Put[Null,x];
    Save[
        x
    ,
        {ExampleDimension, SBasis0L, SBasis0D, SBasis0C, SBasisL, SBasisD,
        SBasisA, SBasisH, SBasisO, SBasisC, SBasisS, SBasisR,
        SBasisRL, SBasisM, Burning, MaxDimension, SectorNumber, MaxRegion,
        RealRegion,RealSectors,RealSector2Number,Number2RealSector,HPI,SBasisN,LRules}
    ];
]


DumpSaveData[x_] := Module[{temp},
    Put[Null,x];
    DumpSave[
        x
    ,
        {ExampleDimension, SBasis0L, SBasis0D, SBasis0C, SBasisL, SBasisD,
        SBasisA, SBasisH, SBasisO, SBasisC, SBasisS, SBasisR,
        SBasisRL, SBasisM, Burning, MaxDimension, SectorNumber, MaxRegion,
        RealRegion,RealSectors,RealSector2Number,Number2RealSector,HPI,SBasisN,LRules}
    ];
]

LoadData[x_] := Module[{temp},
    If[Burning,
        Print["Data already loaded"];
        Return[];
    ];
    Clear[ExampleDimension, SBasis0L, SBasis0D, SBasis0C, SBasisL, SBasisD,
        SBasisA, SBasisH, SBasisO, SBasisC, SBasisS, SBasisR, SBasisRL,
        SBasisM, Burning, MaxDimension, SectorNumber, MaxRegion, RealRegion,HPI,SBasisN,LRules
    ];
    Get[x];
    If[Head[HPI[##]]===HPI,HPI[##]={}]&/@AllProblems[];
    If[Head[RealSectors]===Symbol,
        Print["Data file of an old version loaded"];
        Print["Performing additional preparations"];
        Print["Consider reconstructing the data file to avoid those every time you load it"];
        EnumerateRealSectors[];
        Print["Done"];
    ];
    TrueQ[Burning]
]

(*-------------------------------------------------------------------------------*)
(*
Let us now explain how to construct start files. Some notations
don't look really nice, but they appeared at the moment I did not
expect the algorithm to become something really functional, and
currently they have been used in many files, so I am not changing
them any longer.

To produce a start file you have to run the Prepare[] function,
but first give values to a list of variables.

First of all, you
set "startinglist" to be a list of IBPs written in terms of shift
and multiplication operators. This is the same format with what the IBP.m code
produces as output.

Then you have to define boundary conditions.
It is done by setting the "RESTRICTIONS" equal to a list of list,
each of those of length equal to the number of indices $n$ in this
problem. If "RESTRICTIONS" contain a list like ${a_1,\ldots,a_n}$,
where all $a_i$ should be $-1$, $0$ or $1$, then it means that the
integrals vanish if the indices corresponding to $-1$ are
non-positive, the ones corresponding to $1$ are positive and the
remaining ones are abritrary.

The symmetries of the diagram are defined by setting one of the
two variables, "SYMMETRIES" or "ODDSYMMETRIES". If all your
symmetries preserve the sign, the you can use the first one and
simply provide a list of possible permutations of indices (no need
to include the identical one). And if sign might be changed, you
set the second one providing a list of pairs --- a permutation and
a set of 1s and -1s ${s_1,\ldots,s_n}$. In this case a point ${a_1,\ldots,a_n}$,
being mapped to a symmetric one will be multiplied by a product
$s_1^{a_1}*\ldots*s_n^{a_n}$.

If there is a regularized line you need to set "RegLine" equal to
the number of the line. The standart shift is assumed to be $((4 - d)/2)$,
but you can use any other one by setting the "RegLineShift"
variable.

Now you can just run Prepare[] and all this data will be
transformed into an internal format. The result can be saved in a
start file by the SaveStart[file_without_extension] command.

The following functions are not commented for they are one of the
oldest parts of the algorithm, that is not really well written and
might be improved later.
*)


SaveStart:=Module[{temp},
    If[Length[{##}]>0,FILES={##}[[1]]];
    If[ValueQ[FILES]==False,
        Print["File not defined"];
    ,
        If[Not[Head[ExampleDimension[ProblemNumber]]===ExampleDimension],
            Print["Saving initial data"];
            Put[Null, FILES <> ".start"];
            Save[FILES <> ".start", {ExampleDimension,ProblemNumber,SBasisL, SBasis0L,SBasis0D, SBasis0C, SBasisO, SBasisS, SBasisR, SBasisRL,HPI,SBasisN}];
        ,
            Print["Initial data not ready"]
        ];
    ];
]&;

SaveSBases:=Module[{temp,FILES},
    If[Length[{##}]>0,FILES={##}[[1]]];
    If[ValueQ[FILES]==False,
        Print["Define the FILES variable first"];
    ,
        If[Not[Head[ExampleDimension[ProblemNumber]]===ExampleDimension],
            Print["Saving the bases"];
            Put[Null, FILES <> ".sbases"];
            Save[FILES <> ".sbases", {ProblemNumber,ExampleDimension,SBasis0L,SBasis0C,SBasis0D,SBasisL, SBasisD, SBasisA, SBasisH, SBasisO, SBasisC, SBasisS, SBasisR, SBasisRL,SBasisM,HPI,SBasisN}]
        ,
            Print["Bases not ready"]
        ]
    ];
]&;


AllDirections[maxind_, maxpos_] := Module[{i, temp, result},
      result = Join[##, Table[-1, {maxind-maxpos}]] &/@ Tuples[{-1,1},maxpos];
      Sort[result, (Total[#1] > Total[#2])&]
];

KillDenominator[x_] := Expand[Together[PolynomialLCM @@ Denominator /@ (List @@ x)*x]]

DoubleMore[x_, y_] := Module[{result, i}, result = True; i = 1;
    While[i <= ExampleDimension[ProblemNumber], result = And[result, x[[i]] >= y[[i]]]; i++];
    result
]

RestrictionsPossible[x_]:=Module[{jj},
    jj = 1;
    While[jj <= Length[RESTRICTIONS],
        If[DoubleMore[x*RESTRICTIONS[[jj]], Table[0, {iii, 1, ExampleDimension[ProblemNumber]}]],
            Return[True]
        ];
        jj++
    ];
    False
]

Unprotect[NonCommutativeMultiply];
x_ ** y_ := Map[
    (##*(y /. a[here_] :> a[here] + Exponent[##, Y[here]] - Exponent[##, Ym[here]]))&,
    Expand[x],
    If[Head[Expand[x]] === Plus, {1}, {0}]
] /; And[
    Not[MemberQ[y, NonCommutativeMultiply, {0, Depth[y]}, Heads -> True]],
    Not[MemberQ[x, NonCommutativeMultiply, {0, Depth[x]}, Heads -> True]]
]
Protect[NonCommutativeMultiply];

Pol2List[x_, options:OptionsPattern[Global`FIRE]]:=Module[{temp,i,el,d,c,tempelement},
    If[x === 0, Return[{}]];
    temp=Expand[x];
    temp = Map[((## /. Join[Table[Y[here]->1,{here,1,ExampleDimension[ProblemNumber]}],Table[Ym[here]->1,{here,1,ExampleDimension[ProblemNumber]}]])*
    OptionValue["ResultVar"][(Table[Exponent[##, Y[here]]-Exponent[##, Ym[here]], {here, 1, ExampleDimension[ProblemNumber]}])]) &, temp,{If[Head[temp]===Plus,1,0]}];
    tempelement={};
    Clear[tempCoeff];
    For[i=1,i<=Length[temp],i++,
        el=temp[[i]];
        If[Head[el]===OptionValue["ResultVar"],
            c=1;d=el[[1]],
            c=el/.OptionValue["ResultVar"][y__]->1;d=Select[el,(Head[##] === OptionValue["ResultVar"]) &][[1]]
        ];
        If[Head[tempCoeff[1,d]]===tempCoeff,
            tempCoeff[1,d]=c;
            AppendTo[tempelement,d],
            tempCoeff[1,d]+=c;
        ];
    ];
    Return[tempelement];

] (*returns a list of degrees of an initial element, changes tempCoeff*)



(*-------------------------------------------------------------------------------------------------*)



MyFileInfo[x_]:=If[ToString[FileType[x]]==="File",{FileByteCount[x],FileDate[x]},{0,0}]

EnumerateSectors[pn_] := Module[{temp,Done},
    If[Head[SBasisM[pn]]==SBasisM,SBasisM[pn]={}];
    temp = DefinedFor[SBasisR];
    temp = Select[temp, And[##[[1]] === pn, Or[SBasisRL[pn] === 0, ##[[2]][[SBasisRL[pn]]] === 1]] &];
    MaxRegion & /@ temp;
    RealRegion[pn, ##] & /@ Range[Length[SBasisM[pn]]];
    If[Head[SBasisO[##[[1]], ##[[2]]]] === SBasisO,
        SBasisO[##[[1]], ##[[2]]] = R3HO[SBasisRL[##[[1]]], Flatten[Position[##[[2]], 1]], Length[##[[2]]]]
    ] & /@ temp;
    temp = Sort[temp, HigherPair];
    temp = Transpose[{temp, Range[Length[temp]]}];
    temp = {SectorNumber[##[[1]]], ToDigits[1000000 - ##[[2]], 6]} & /@ temp;
    Apply[Set, temp, {1}];
]
AllProblems[] := (##[[1]]) & /@ DefinedFor[SBasisS]

Burn[] := Module[{temp},
    If[Burning,Print["FIRE already burning"];Retun[False]];
    EnumerateSectors /@ AllProblems[];
    MaxDimension[];
    EnumerateRealSectors[];
    Burning=True
]

MaxDimension[] := MaxDimension[] = Max @@ ((ExampleDimension[##[[1]]]) & /@ DefinedFor[ExampleDimension]);

RealRegion[pn_, r_] := RealRegion[pn, r] = If[
    And[r > 0,
        Or[
            SBasisL[pn, SBasisM[pn][[r]]] === 0,
            Head[SBasisL[pn, SBasisM[pn][[r]]]] === SBasisL]
        ],
    0,
    r
]

SavedPairNumber[x_]:=SavedPairNumber[x]=PairNumber[x]

NewToDigits[x_,y_]:=Module[{temp},
    If[x<0,
        temp=NewToDigits[-x, y];
        Return[ReplacePart[temp,temp[[1]]+5,1]];
    ];
    IntegerDigits[x,10,y]
]

NewZerosString[x_]:=Table[0,{x}]

ZerosString[0] = "";

ZerosString[y_] := ZerosString[y] = ZerosString[y - 1] <> "0";

FivePlus[x_]:=If[x==="0","5",If[x==="1","6",If[x==="2","7",If[x==="3","8",If[x==="4","9",Print["FivePlus error ,",x];Abort[]]]]]];

ToDigits[x_, y_] := Module[{temp,result},
    If[x < 0,
        temp=ToDigits[-x, y];
        Return[FivePlus[StringTake[temp,1]] <> StringDrop[temp,1]]
    ];
    temp = ToString[x];
    If[StringLength[temp] > y, Print["ToDigits error: ", x, " ,", y];
      Abort[]];
    result=ZerosString[y - StringLength[temp]] <> temp;
    result
]

PairNumber[x_] := Module[{temp, pn, ssector, r, ordering, sn, dd, i,l,result,o1,o2},
    result=Reap[
        pn = x[[1]];
        ssector = SSector[pn, x[[2]]];
        r = MaxRegion[pn, ssector];
        Sow[NewToDigits[If[pn===0,1,100000 - pn], 5]];
        Sow[NewToDigits[99-r, 2]];
        dd = Pair2Degree[{pn, x[[2]]}];
        r = RealRegion[pn, r];
        If[r > 0,
            sn = SBasisM[pn][[r]];
            l=Length[Position[sn,0]];
            ordering = SBasisO[pn, sn];
            o1=Take[ordering,l];
            o2=Drop[ordering,l];
            Sow[NewToDigits[##, 2] & /@ (o1 . dd)];
            Sow[NewToDigits[ToExpression[SectorNumber[{pn, ssector}]],6]];
            Sow[NewToDigits[##, 2] & /@ (o2 . dd)];
        ,
            ordering = SBasisO[pn, ssector];
            Sow[NewToDigits[ToExpression[SectorNumber[{pn, ssector}]],6]];
            Sow[NewToDigits[##, 2] & /@ (ordering . dd)];
        ];
        Sow[NewZerosString[2(MaxDimension[] - Length[x[[2]]])]];
    ][[2]][[1]];
    ToString[FromDigits[Flatten[result]]]
]

DoubleMaxPoints[x_]:=Module[{temp,temp2,i,j,min,restart1},
    temp=x;
    Label[restart1];
    For[i=1,i<=Length[temp],i++,
        For[j=1,j<=Length[temp],j++,
            If[j==i,Continue[]];
            If[And[temp[[j]][[1]]>=temp[[i]][[1]],temp[[j]][[2]]>=temp[[i]][[2]]],
                temp=Delete[temp,i];
                Goto[restart1];
            ];
        ]
    ];
    temp
]

(* the following functions come from SBases --- used for preparation and auto construction *)
(* Prepare, SomeOrdering, AVRules, ASRules, InSectorOrLower, Orbit, tempfunction, SubSectors, Info, MaxDegrees, FindOrdering, TestSectorZero*)

Prepare[options:OptionsPattern[Global`FIRE]]:=Module[{temp,temp2,i,j,dirs,s0,s1,s2,s3,startinglist2,k},
    ProblemNumber=0;
    If[Not[ValueQ[Replacements]],Replacements={}];
    If[Not[ValueQ[startinglist]],
        startinglist = Flatten[Outer[(IBP[#1, #2, options] //. Replacements) &, Internal, Join[Internal, External]], 1];
        If[OptionValue["LI"],
            startinglist = Join[startinglist,
                Flatten[
                    Table[
                        Table[
                            LII[External[[i]], External[[j]]] //. Replacements,
                            {j, i+1, Length[External]}
                        ],
                        {i, 1, Length[External] - 1}
                    ], 1
                ]
            ];
        ]
    ];
    temp = Select[Variables[startinglist], (Head[##] === Symbol)&];
    If[ToLowerCase[ToString[temp]] =!= ToString[temp],
        Print["WARNING!!!! Fermat cannot handle capital letters!!!"];
        Print[temp];
    ];
    ExampleDimension[ProblemNumber]=Max @@ Apply[## &,Union[Cases[startinglist, Y[y_], {0, Infinity}],Cases[startinglist, Ym[y_], {0, Infinity}], Cases[startinglist, a[y_], {0, Infinity}]], {1}];
    Print["Dimension set to ",ExampleDimension[ProblemNumber]];
    If[OptionValue["PositiveIndices"] === Automatic,
        dirs = AllDirections[ExampleDimension[ProblemNumber], ExampleDimension[ProblemNumber]];
    ,
        dirs = AllDirections[ExampleDimension[ProblemNumber], OptionValue["PositiveIndices"]];
    ];
    Clear[SBasisL, SBasis0D, SBasis0C, SBasis0L, SBasisA, SBasisD, SBasisC, SBasisO, SBasisS, SBasisR, SBasisRL,SBasisM];
    If[Head[RegLine]===Symbol,SBasisRL[ProblemNumber]=0,SBasisRL[ProblemNumber]=RegLine];
    startinglist2 = Map[KillDenominator, startinglist, {1}];
    If[Head[HeavyPoints]===Symbol,HPI[ProblemNumber]={},HPI[ProblemNumber]=HeavyPoints];
    If[Head[RegLineShift]===Symbol,RegLineShift=((4 - OptionValue["DVar"])/2)];
    If[SBasisRL[ProblemNumber]>0,startinglist2=Expand[startinglist2 /. (a[RegLine] -> a[RegLine] + RegLineShift)]];
    If[And[Head[SYMMETRIES]===Symbol,Head[ODDSYMMETRIES]===Symbol,Head[CONDITIONALSYMMETRIES]===Symbol],Print["No symmetries"]];
    s0={{Range[ExampleDimension[ProblemNumber]],Table[1, {ExampleDimension[ProblemNumber]}],Table[0, {ExampleDimension[ProblemNumber]}]}};
    If[Head[SYMMETRIES]===Symbol,s1={},s1={##, Table[1, {ExampleDimension[ProblemNumber]}],Table[0, {ExampleDimension[ProblemNumber]}]} & /@(SymmetryGroup[SYMMETRIES])];
    If[Head[ODDSYMMETRIES]===Symbol,s2={},s2={##[[1]],##[[2]],Table[0, {ExampleDimension[ProblemNumber]}]} & /@ODDSYMMETRIES];
    If[Head[CONDITIONALSYMMETRIES]===Symbol,s3={},s3={##[[1]],Table[1, {ExampleDimension[ProblemNumber]}],##[[2]]} & /@CONDITIONALSYMMETRIES];
    SBasisS[ProblemNumber]=Join[s0,s1,s2,s3];

    If[Or[OptionValue["Parallel"] === True, IntegerQ[OptionValue["Parallel"]]],
        If[OptionValue["Parallel"] === True,
            LaunchKernels[];
        ,
            LaunchKernels[OptionValue["Parallel"]];
        ];
        DistributeDefinitions["FIRE`"];
        temp2=ParallelMap[(
            temp=If[OptionValue["AutoDetectRestrictions"] === True,
                Or[RestrictionsPossible[SSector[0,##]],TestSectorZero[##, options]],
                RestrictionsPossible[SSector[0,##]]
            ];
            {SBasisR[ProblemNumber,##],temp}
        )&,dirs,{1}];
        (
            SBasisL[ProblemNumber,##] = 0;
        )&/@dirs;
        Apply[Set,temp2,{1}];
    ,
        (
            SBasisR[ProblemNumber,##]=If[OptionValue["AutoDetectRestrictions"] === True,
                Or[RestrictionsPossible[SSector[0,##]],TestSectorZero[##, options]],
                RestrictionsPossible[SSector[0,##]]
            ];
            SBasisL[ProblemNumber,##] = 0;
        )&/@dirs;
    ];

    SBasis0L[ProblemNumber]=Length[startinglist2];
    For[j = 1, j <= Length[startinglist2], j++,
        temp = Pol2List[startinglist2[[j]], options];
        SBasis0D[ProblemNumber,j] = temp;
        For[k = 1, k <= Length[SBasis0D[ProblemNumber,j]], k++,
            SBasis0C[ProblemNumber,j, SBasis0D[ProblemNumber,j][[k]]] = NewCoeffForm[tempCoeff[1,SBasis0D[ProblemNumber,j][[k]]]];
        ]
    ]
]

AVRules[x_]:=Table[a[here]->x[[here]],{here,1,ExampleDimension[ProblemNumber]}]
(* a substitution for a fixed point *)

ASRules[x_]:=Table[a[here]->a[here]+x[[here]],{here,1,ExampleDimension[ProblemNumber]}]
(*a shift*)

InSectorOrLower[x_,Sector_]:=And@@Table[If[Sector[[here]]===1,True,x[[here]]<=0],{here,ExampleDimension[ProblemNumber]}]

Orbit[x_] := Union[Map[If[SatisfiesCondition[x,##[[3]]],UseSymmetry[##[[1]], x],x]&,SBasisS[ProblemNumber],{1}]]

SubSectors[x_]:=Module[{points,i,j,point,Found},
    points={x};
    i=1;
    While[i<=Length[points],
        j=1;
        point=points[[i]];
        Found=False;
        While[j<=ExampleDimension[ProblemNumber],
            If[point[[j]]==0,
                points=FlattenAt[ReplacePart[points,{ReplacePart[point,1,j],ReplacePart[point,-1,j]},i],i];
                Found=True;
                Break[],
                j++
            ]
        ];
        If[Not[Found],i++]
    ];
    Return[points]
]

Info[x_]:=Info[x,False]

Info[x_,z_]:=Module[{temp,i,j,T,points,Minuses,tempfunction},
    If[Or[Not[VectorQ[x,(Or[##===1,##===0,##===-1])&]],Not[Length[x] === ExampleDimension[ProblemNumber]]],
        Print["Error in the direction"]; Return[]
    ];
    If[Head[SBasisM[ProblemNumber]]==SBasisM,SBasisM[ProblemNumber]={}];
    points=SubSectors[x];

    Print["Sectors in the area :",Length[points]];
    points=Union[Orbit[##]]&/@points;
    For[i=1,i<=Length[points],i++,If[Or@@(SBasisR[ProblemNumber,##]&/@points[[i]]),points=Delete[points,i];i--]];
    Print["Non-trivial sectors in the area :",Length[points]];
    points=Union[points];
    Print["Non-trivial sectors up to a symmetry in the area :",Length[points]];
    i=Length[points];
    tempfunction[xx_]:=(Plus@@(SBasisL[ProblemNumber,If[MaxRegion[ProblemNumber,##]>0,SBasisM[ProblemNumber][[MaxRegion[ProblemNumber,##]]],##]]&/@xx));
    points=DeleteCases[(If[tempfunction[##]===0,##,T])&/@points,T];
    Print["Bases built in ",i-Length[points]," sectors"];
    i=Length[points];
    Print["Nothing in ",Length[points]," sectors"];
    points=Sort[points,(Total[#1[[1]]]>=Total[#2[[1]]])&];
    Minuses=0;
    If[z,
        Do[If[Total[points[[i]][[1]]]<Total[x/.(0->1)]-2Minuses,
            While[Total[points[[i]][[1]]]<Total[x/.(0->1)]-2Minuses,Minuses++];
            If[Minuses==1,
                Print["1 additional minus"],
                Print[Minuses," additional minuses"]
                ];
            ];
            Print[points[[i]]],
        {i,Length[points]}];
    ]
]

MaxDegrees[x_,Sector_]:=Module[{temp,temp2,i,j,min,restart1,rank,coeffs,restart},
    temp=(Sector*##)&/@x;
    Label[restart1];
    For[i=1,i<=Length[temp],i++,
        For[j=1,j<=Length[temp],j++,
            If[j==i,Continue[]];
            If[DoubleMore[temp[[j]],temp[[i]]],
                temp=Delete[temp,i];
                Goto[restart1];
            ];
        ]
    ];
    If[Length[temp]==1,Return[{Sector*temp[[1]]}]];
    min=Min/@Transpose[temp];
    temp=(##-min)&/@temp;
    Label[restart];
    For[i=1,i<=Length[temp],i++,
        rank=MatrixRank[Delete[temp,i]];
        temp2=MyKSubsets[Delete[temp,i],rank];
        For[j=1,j<=Length[temp2],j++,
            If[And[MatrixRank[temp2[[j]]]==rank,MatrixRank[Append[temp2[[j]],temp[[i]]]]==rank],
                coeffs=LinearSolve[Transpose[temp2[[j]]],temp[[i]]];
                If[And[Total[coeffs]<=1,And@@((##>=0)&/@coeffs)],temp=Delete[temp,i];Goto[restart]];
            ]
        ];
    ];
    (Sector*(##+min))&/@temp
]

SomeOrdering[x_,n_,Sector_]:=Module[{temp,i,ordering,left,max,Found},
    ordering={};
    temp=x;
    For[i=1,i<=ExampleDimension[ProblemNumber],i++,left[i]=True];
    While[Length[temp]>1,
        Found=False;
        For[i=1,i<=ExampleDimension[ProblemNumber],i++,
            If[Not[left[i]],Continue[]];
            max=Max@@((##[[i]]*Sector[[i]])&/@temp);
            If[x[[n]][[i]]*Sector[[i]]==max,
                temp=DeleteCases[(If[##[[i]]*Sector[[i]]===max,##,TTT])&/@temp,TTT];
                left[i]=False;
                AppendTo[ordering,Delta[i,ExampleDimension[ProblemNumber]]];   (* here we made a change from Delta[i]  *)
                Found=True;
                Break[]
            ]
        ];
        If[Not[Found],Print["No ordering found"];Return[False]];
    ];
    For[i=1,i<=ExampleDimension[ProblemNumber],i++,If[left[i],AppendTo[ordering,Delta[i,ExampleDimension[ProblemNumber]]]]];
    ordering
]

FindOrdering[Sector_]:=Module[{temp,i,j,k,tempelement,Found,degrees},
    For[i=1,i<=SBasis0L[ProblemNumber],i++,
        tempelement=SBasis0D[ProblemNumber,i];
        temp=MaxDegrees[tempelement,Sector];
        For[j=1,j<=Length[temp],j++,
            If[Not[(OldCoeffForm[SBasis0C[ProblemNumber,i,temp[[j]]]]/.AVRules[SPoint[Sector]-temp[[j]]])===0],
                Found=True;
                degrees=(##+SPoint[Sector]-temp[[j]])&/@tempelement;
                For[k=1,k<=Length[degrees],k++,
                    If[And[Not[InSectorOrLower[degrees[[k]],Sector]],
                        Not[SBasisR[ProblemNumber,SSector[ProblemNumber,degrees[[k]]]]],
                        Not[Expand[(OldCoeffForm[SBasis0C[ProblemNumber,i,tempelement[[k]]]]/.AVRules[SPoint[Sector]-temp[[j]]])]===0]],
                        Found=False;Break[]
                    ]
                ];
                If[Found,
                    (*TheOnlyElement=i;
                    TheOnlyShift=SPoint[Sector]-temp[[j]];*)
                    Return[SomeOrdering[temp,j,Sector]]
                ];
            ];
        ]
    ];
    False
]

TestSectorZero[sector_, options:OptionsPattern[Global`FIRE]] := Module[{dim, temp, here, func, mat, vars, i, startinglist2,ttt,rule},
    dim = Max @@ Apply[
        ## &,
        Union[
            Cases[startinglist, Y[y_], {0, Infinity}],
            Cases[startinglist, Ym[y_], {0, Infinity}],
            Cases[startinglist, a[y_], {0, Infinity}]
        ],
        {1}
    ];
    startinglist2 = Map[KillDenominator, startinglist, {1}];
    If[Head[RegLineShift] === Symbol, RegLineShift = ((4 - OptionValue["DVar"])/2)];
    If[Head[RegLine] =!= Symbol,
    startinglist2 = Expand[startinglist2 /. (a[RegLine] -> a[RegLine] + RegLineShift)]];
    temp = Map[(
        (## /. Join[Table[Y[here] -> 1, {here, 1, dim}], Table[Ym[here] -> 1, {here, 1, dim}]]) *
        OptionValue["ResultVar"][(Table[Exponent[##, Y[here]] - Exponent[##, Ym[here]], {here, 1, dim}])]) &,
        ##,
        {If[Head[##] === Plus, 1, 0]}
    ] & /@ startinglist2;
    temp = temp /. Apply[Rule, Transpose[{Array[a, Length[sector]], SPoint[sector]}], {1}];
    temp = temp /. (OptionValue["ResultVar"][aaa_] :> OptionValue["ResultVar"][aaa + SPoint[sector]]);
    ttt = temp;
    vars = Cases[Variables[temp], OptionValue["ResultVar"][aaa__]];
    vars = Prepend[DeleteCases[vars, OptionValue["ResultVar"][SPoint[sector]]], OptionValue["ResultVar"][SPoint[sector]]];
    mat = Outer[Coefficient, Append[temp, OptionValue["ResultVar"][SPoint[sector]]], vars];
    Off[LinearSolve::"nosol"];
    rule = LinearSolve[mat, Append[Table[0, {Length[mat] - 1}], 1]];
    On[LinearSolve::"nosol"];
    If[Head[rule] === LinearSolve,
        Return[True]
    ];
    rule = Apply[Rule, Transpose[{vars, rule}], {1}];
    Return[False];
]

(* and from IBP ----------------------------------------------------*)

Off[General::spell1];
Off[General::spell];

MakeList[x_] := If[Head[x] === Plus, Apply[List, x, {0}], x]

NumCoeff[x_] := Module[{ii},
    x /. Join[
        Table[Internal[[ii]] -> 1, {ii, 1, Length[Internal]}],
        Table[External[[ii]] -> 1, {ii, 1, Length[External]}]
    ]
]
KillInt[x_] := Module[{ii},
    x /. Table[Internal[[ii]] -> 0, {ii, 1, Length[Internal]}]
]

SquaresEv[] := Module[{ii, jj, kk},
    DeleteCases[
        Map[
            (If[KillInt[##] === 0, ##, 0]) &
        ,
            Union[
                Map[
                    (##/NumCoeff[##]) &,
                    Union[
                        Flatten[
                            Map[MakeList,
                                Union[
                                    DeleteCases[
                                        Flatten[
                                            Join[
                                                Table[
                                                    Expand[D[Propagators[[jj]], Internal[[ii]]]*External[[kk]]],
                                                    {ii, 1, Length[Internal]}, {jj, 1, Length[Propagators]}, {kk, 1, Length[External]}
                                                ]
                                            ,
                                                Table[Expand[D[Propagators[[jj]], Internal[[ii]]]*Internal[[kk]]],
                                                    {ii, 1, Length[Internal]}, {jj, 1, Length[Propagators]}, {kk, 1, Length[Internal]}
                                                ]
                                            ]
                                        ]
                                    , 0]
                                ]
                            , {1}]
                        ]
                    ]
                , {1}]
            ]
        , {1}]
    ,
        0
    ]
]

ClearIBP[] := Module[{temp},
    Unprotect[Internal, External, Propagators, PrepareIBPd, BackMatrix, Squares];
    Internal = {};
    External = {};
    Propagators = {};
    Squares = {};
    BackMatrix = {};
    PrepareIBPd = False;
]

PrepareIBP[] := PrepareIBP[True];

PrepareIBP[verbose_:True] := Module[{M1, V1, FullMatrix},
    If[PrepareIBPd,
        Print["Already prepared"];
        Return[False]
    ];
    Propagators = Map[Expand, Propagators, {1}];
    Squares = SquaresEv[];
    If[Length[Squares] < Length[Propagators],
        If[verbose,
            Print["Linearly dependant propagators. Perform reduction first"];
        ];
        Return[False]
    ];
    If[Length[Squares] > Length[Propagators],
        If[verbose,
            Print["Not enough propagators. Add irreducible nominators"];
        ];
        Return[False]
    ];
    M1 = Table[
        Coefficient[Propagators[[ii]], Squares[[jj]]],
        {ii, 1, Length[Propagators]}, {jj, 1, Length[Squares]}
    ];
    V1 = Propagators - M1 . Squares;
    FullMatrix = Append[
        Table[Append[M1[[ii]], V1[[ii]]], {ii, 1, Length[M1]}],
        Table[If[ii === Length[M1[[1]]] + 1, 1, 0], {ii, 1, Length[M1[[1]]] + 1}]
    ];
    BackMatrix = Inverse[FullMatrix];
    PrepareIBPd = True;
    If[verbose,
        Print["Prepared"];
    ];
    Protect[Internal, External, Propagators, PrepareIBPd, BackMatrix, Squares];
    Return[True];
]

SquaresCoeffs[x_] := Module[{ii},
    If[Not[PrepareIBPd], Print["Use PrepareIBP[] first"]; Return[]];
    Table[Coefficient[x, Squares[[ii]]], {ii, 1, Length[Squares]}]
]

YRepr[x_] := Module[{temp},
    If[Not[PrepareIBPd], Print["Use PrepareIBP[] first"]; Return[]];
    If[x==0,Return[0]];
    temp = SquaresCoeffs[x];
    temp = Append[temp, Expand[x - temp . Squares]];
    temp = temp . BackMatrix;
    Sum[temp[[ii]]*Ym[ii], {ii, 1, Length[temp] - 1}] + Last[temp]
]

IBP[x_, y_, options:OptionsPattern[Global`FIRE]] := Module[{kk},
    If[Not[PrepareIBPd], Print["Use PrepareIBP[] first"]; Return[]];
    (Expand[
        Sum[
            If[D[Propagators[[kk]], x] === 0, 0, -a[kk]YRepr[D[Propagators[[kk]], x]*y]*Y[kk]],
            {kk, 1, Length[Propagators]}
        ]
    ] /. Table[Y[kk]*Ym[kk] -> 1, {kk, 1, Length[Propagators]}]) + D[y, x]*OptionValue["DVar"]
]

LII[q1_, q2_] := Module[{i, k},
    If[Not[PrepareIBPd], Print["Use PrepareIBP[] first"]; Return[]];
    Expand[
        Sum[
            YRepr[q2*External[[i]]]*a[k]*Y[k]*YRepr[q1*D[Propagators[[k]], External[[i]]]] -
            YRepr[q1*External[[i]]]*a[k]*Y[k]*YRepr[q2*D[Propagators[[k]], External[[i]]]],
            {i, 1, Length[External]}, {k, 1, Length[Propagators]}
        ] //. Replacements
    ] //. Table[Y[k]*Ym[k] -> 1, {k, 1, Length[Propagators]}]
]

On[General::spell1];
On[General::spell];

(* from tsort ------------------------------------------------------   *)

ClearAll[UF];
Options[UF] := { Variables -> Table[x[i],{i,100}] };
UF[ks_,ds_,cs_,opt___Rule] := Module[{degree,coeff,i,t2,t1,t0,zz,v,vs,cz},
    vs = Take[Variables /. {opt} /. Options[UF], Length[ds]];
    cz = Map[Rationalize[##,0]&, cs, {0,Infinity}];
    degree = - Sum[ds[[i]] * vs[[i]], {i,1,Length[ds]}];
    coeff = 1;
    For[i = 1, i <= Length[ks], i++,
        t2 = Coefficient[degree, ks[[i]], 2];
        t1 = Coefficient[degree, ks[[i]], 1];
        t0 = Coefficient[degree, ks[[i]], 0];
        coeff = coeff * t2;
        If[t2 === 0, Return[{0,0,{}}]];
        degree = Together[t0 - ((t1^2)/(4*t2))]
    ];
    degree = ExpandAll[Together[- coeff * degree] //. cz] //. cz;
    coeff = Together[coeff] //. cz;
    {coeff,Expand[degree],vs}
]

(*******************************************************************************)
(* p: polynomial, return orderings of variables so that p is in canonical form *)

PolynomialOrderings[pn_, vs_List:{}, n_Integer:-1] := Module[
    {vt, crs, gcd, cmx, cns, cas, cps, cvs, ord, max},
    (* check: variables *)
    vt = vs;
    If[vt === {}, vt = Variables[pn]];
    (* -- (1) -- *)
    (* polynomial -> coefficient rules *)
    crs = CoefficientRules[pn, vt];
    (* possible common factor *)
    gcd = PolynomialGCD @@ (Last /@ crs);
    (* rules -> matrix of exponents, coefficients *)
    cmx = Append[First[#], Simplify[Last[#]/gcd]] & /@ crs;
    (* operate on the transposed *)
    cmx = Transpose[Sort[cmx]];
    (* -- (2) -- *)
    (* initialize list of column numbers, permutations *)
    cns = Range[Length[vt]];
    cas = {{}};
    (* iterate until all variables ordered *)
    While[
        Length[First[cas]] < Length[vt],
        (* -- (3) -- *)
        (* extended permutations *)
        cps = Join @@ (Function[ca, Append[ca, #] & /@ Complement[cns, ca]] /@ cas);
        (* -- (4) -- *)
        (* candidate vectors *)
        cvs = (cmx[[Prepend[#, -1]]]  (* coefficients, swap rows *)
            // Transpose           (* -> columns *)
            // Sort                (* sort rows *)
            // Transpose           (* -> columns *)
            // Last) & /@ cps;     (* extract vector *)
        (* -- (5) -- *)
        (* lexicographical ordering *)
        ord = Ordering[cvs];
        (* maximum vector *)
        max = cvs[[Last[ord]]];
        (* -- (6) -- *)
        (* select (maximum number of) candidate permutations *)
        cas = Part[cps, Select[ord, cvs[[#]] === max & ]];
        cas = If[n >= 0 && n < Length[cas], Take[cas, n], cas]
    ];
    (* -- (7) -- *)
    (* result: canonical orderings *)
    cas
];

MyInversePermutation[x_] := Table[Position[x, i][[1]][[1]], {i, Length[x]}]

FindEquivalents[listt_, options:OptionsPattern[Global`FIRE]] := Module[
    {corners, functions, up, fp, vs, upc, fpc, op, H, temp, pn, vector, result, rep, dummy, parts, startTime, mapFunction}
    ,
    If[Head[Problems]===Symbol,
        If[Head[Propagators]===Symbol,Print["Please define propagators"];Return[{}]];
        If[Head[Replacements]===Symbol,Replacements={}]
    ,
        (
            If[Head[Propagators[##]]===Propagators,Print["Please define propagators ",##];Abort[]];
            If[Head[Replacements[##]]===Replacements,Replacements[##]={}];
        )&/@Problems
    ];
    If[listt === All,
        corners = {Number2RealSector[##][[1]],
        SPoint[Number2RealSector[##][[2]]]} & /@ Range[RealSectors]
    ,
        corners = listt
    ];
    If[OptionValue["ProgressReport"] === True,
        startTime = AbsoluteTime[];
        parts = 10;
    ,
        parts = 1;
    ];
    (* Split corners list into "parts" sub-lists, so we can report on progress if ProgressReport is True *)
    (* Otherwise we have set parts to 1, and work on this single part. *)
    corners = DeleteCases[ ArrayReshape[dummy@@@corners,{parts,Ceiling[Length[corners]/parts]},Null], Null, 2]/.dummy->List;
    If[Or[OptionValue["Parallel"] === True, IntegerQ[OptionValue["Parallel"]]],
        If[OptionValue["Parallel"] === True,
            LaunchKernels[];
        ,
            LaunchKernels[OptionValue["Parallel"]];
        ];
        DistributeDefinitions["FIRE`"];
        DistributeDefinitions[Problems];
        DistributeDefinitions[Propagators];
        DistributeDefinitions[External];
        DistributeDefinitions[Internal];
        DistributeDefinitions[Replacements];
        mapFunction=ParallelMap;
    ,
        mapFunction=Map;
    ];
    (* Compute the "parts" sub-lists one after another, printing progress if required. Flatten result *)
    functions = Table[
        If[OptionValue["ProgressReport"] === True,
            Print["FindEquivalents: start part ", part, "/", parts, " (", Round[AbsoluteTime[]-startTime],"s)"];
        ];
        mapFunction[(
            {
                (temp = ##;
                temp = {temp[[1]], If[## == 0, 0, 1] & /@ (temp[[2]])};
                pn = temp[[1]];
                vector=temp[[2]];
                If[Head[Problems]===Symbol,
                    {up, fp, vs} = UF[Internal, Propagators * vector, Replacements];
                ,
                    {up, fp, vs} = UF[Internal[pn], Propagators[pn] * vector, Replacements[pn]];
                ];
                vs=Array[x,Max@@(First/@vs)];
                rep=(x[ind_]:>If[##[[2]][[ind]]===1,x[ind],AAA[##[[2]][[ind]]]*x[ind]]);
                If[Or[vs==={},up*fp===0],
                    Print["Zero integral: ",temp];
                    H[0,0,0]
                ,
                    op = PolynomialOrderings[Expand[(up*fp)/.rep], vs, 1];
                    {upc, fpc} = {up, fp} /. Table[vs[[op[[1, i]]]]->vs[[i]], {i, Length[vs]}];
                    temp = op[[1]];
                    H[Expand[upc],Expand[fpc],Table[##[[2]][[temp[[i]]]], {i, Length[vs]}]]
                ]
                )
                , ##
            })&
            ,corners[[part]]
        ]
    ,{part,1,Length[corners]}] // Flatten[#,1]& ;

    result=  Reap[Sow[##[[2]], ##[[1]]] & /@ functions, _, If[({##}[[1]])===H[0,0,0],Append[({##}[[2]]),OptionValue["ResultVar"][Infinity]],({##}[[2]])] &][[2]];
    Print["Input: ",Length[listt],", output: ",Length[DeleteCases[result,{__,OptionValue["ResultVar"][Infinity]}]]];
    result
]

FindRules[listt_, options:OptionsPattern[Global`FIRE]] := Module[{temp},
    temp = FindEquivalents[listt, options];
    temp = Select[temp, (Length[##] > 1) &];
    temp = Sort[##, HigherPair] & /@ temp;
    temp = {Drop[##, -1], Table[Last[##], {Length[##] - 1}]} & /@ temp;
    temp = Transpose /@ temp;
    temp = Flatten[temp, 1];
    temp = Apply[Rule, temp, {1}];
    temp = Apply[OptionValue["ResultVar"], temp, {2}];
    Replace[temp,OptionValue["ResultVar"][Infinity]->0,{2}]
]

RulesForm[list_, options:OptionsPattern[Global`FIRE]] := Module[{temp,OldForm=False},
    Rule[##[[1]],
        If[##[[2]]===0,
            {},
            temp = Expand[Collect[##[[2]], OptionValue["ResultVar"][__], Hold] /. (OptionValue["ResultVar"][a__] Hold[b__] :> Hold[{b, OptionValue["ResultVar"][a]}])];
            If[Head[temp] === Plus, temp = Apply[List, temp, {0}],temp={temp}];
            temp = ReleaseHold[temp];
            If[OldForm,temp=temp[[1]][[2]]];
            temp
        ]
    ]
] & /@ list

SaveRulesToFile[rules_,file_, options:OptionsPattern[Global`FIRE]]:=Module[{str,temp},
    Print["Saving rules"];
    temp = RulesForm[rules, options];
    str = OpenWrite[file <> ".rules", BinaryFormat -> True];
    (
        BinaryWrite[str, ToString[##, InputForm]];
        BinaryWrite[str, ";"];
        Write[str];
        Write[str];
    ) & /@ temp;
    Close[str];
]

WriteRules[listt_, file_, options:OptionsPattern[Global`FIRE]] := Module[{temp, str},
    temp = FindRules[listt, options];
    SaveRulesToFile[temp,file, options];
]

ApplyRulesToSelf[list_]:=Rule[##[[1]], ##[[2]] //. list] & /@ list;

LoadRules[file_,pn_, options:OptionsPattern[Global`FIRE]] := Module[{temp},
    InitializeValues[];
    temp = ToExpression[StringReplace[##, ";" -> ""]] & /@
    Select[Import[file <> ".rules","List"], (StringLength[##] > 5) &];
    temp = Apply[List, temp, {1}];
    temp = Transpose[temp];
    temp[[2]] = Apply[Times, temp[[2]], {2}];
    temp[[2]] = Apply[Plus, temp[[2]], {1}];
    temp = Transpose[temp];
    temp = Apply[Rule, temp, {1}];
    NewRules[pn]=temp;
    TryRules[List@@(##[[1]]), options]&/@temp;
]

Unprotect[Times, Power];
LiteRed`j[t_, a__]*LiteRed`j[t_, b__] := LiteRed`j @@ Prepend[{a} + {b}, t];
Power[LiteRed`j[t_, a__], n_Integer] /; n > 1 := LiteRed`j @@ Prepend[n {a}, t];
Protect[Times, Power];

AnalyzePattern[pattern_] := Module[{temp},  (*pattern for indices*)
    If[pattern === v, Return[v]];
    If[Head[pattern] === PatternTest,
        If[pattern[[2]] === Positive, Return[1]];
        If[pattern[[2]] === NonPositive, Return[-1]];
    ];
    Print["Incorrect pattern: ", pattern];
    Abort[];
]

AnalyzeEquation[equation_,n_Integer] := Module[{temp,vars,coeffs},  (*one equation or non-equality for indices*)
    temp = False;
    If[Head[equation] === Equal, temp = {equation[[1]] - equation[[2]], 1}];
    If[Head[equation] === Unequal, temp = {equation[[1]] - equation[[2]], 0}];
    If[equation === True, temp = {0, 1}];
    If[equation === False, temp = {0, 0}];
    If[temp === False,
        Print["Incorrect equation: ", equation];
        Abort[]
    ];
    vars=ToExpression["n"<>ToString[##]]&/@Range[n];
    coeffs=Coefficient[temp[[1]],##]&/@vars;
    {coeffs,Expand[temp[[1]]-Inner[Times,coeffs,vars,Plus]],temp[[2]]}
]

AnalyzeCondition[condition_,n_Integer] := Module[{temp},  (*condition for rule to be applied*)
    If[Head[condition] === Or,
        Print["Incorrect condition: ", condition];
        Abort[]
    ];
    If[Head[condition] === And, temp = List @@ condition, temp = {condition}];
    AnalyzeEquation[##,n]& /@ temp
]

AnalyzeTerm[term_,n_Integer]:=Module[{temp,vars,coeffs,temp2},     (*one term on the right-hand side of a rule*)
    temp={term/.{LiteRed`j[__]->1},Cases[term,LiteRed`j[__],{0,Infinity}]};
    If[Length[temp[[2]]]=!=1,
        Print["Incorrect term: ", term];
        Abort[]
    ];
    temp={ToString[temp[[1]],InputForm],Drop[List@@(temp[[2]][[1]]),1]};
    vars=Global`xxx/@Range[n];
    temp[[2]]=(
        temp2=##;
        coeffs=Coefficient[temp2,##]&/@vars;
        {coeffs,Expand[temp2-Inner[Times,coeffs,vars,Plus]]}
    )&/@temp[[2]];
    temp
]

NormalizePattern[rule : (_Rule | _RuleDelayed), newvars_] := (
    rule /. (Thread[# -> Take[newvars, Length@#]]) &[
        Cases[
            First[rule],
            HoldPattern[x_Pattern] :> First[x],
            {0, \[Infinity]}
        ]
    ]
)

(* the sector without SBasisN is higher; we can set SBasisN for sectors without symmetry rules *)

AnalyzeDelayedRule[part_] := Module[{temp, main, vars, n},
    n = Length[Cases[part, LiteRed`j[__], {0, Infinity}][[1]]] - 1;
    vars = Table[ToExpression["n" <> ToString[i]], {i, n}];
    temp = CoefficientRules[PowerExpand[Log[part]], vars];
    temp = {
        If[##[[1]] === Table[0, {Length[vars]}],
            1,
            vars[[Position[##[[1]], 1][[1]][[1]]]]
        ]
        , ##[[2]]
    } & /@ temp;
    temp = {##[[1]], 1/Exp[##[[2]]]} & /@ temp;
    main = Cases[temp, {1, _}];
    temp = ExpandAll[Complement[temp, main]];
    If[Length[main] =!= 1, Abort[]];
    main = 1/main[[1]][[2]];
    If[Head[main] =!= LiteRed`j,
        Print["error it the right part of delayed rule 2"];
        Print[part];
        Abort[]
    ];
    temp = {##[[2]], ##[[1]]} & /@ temp;
    If[temp =!= {},
        temp = Transpose[temp];
        If[Not[MemberQ[vars, ##]],
            Print["error it the right part of delayed rule 5"];
            Print[part];
            Print[vars];
            Print[##];
            Abort[];
        ] & /@ temp[[2]];
        temp[[2]] = Position[vars, ##][[1]][[1]] & /@ temp[[2]];
        temp[[1]] = If[Head[##] === Plus, List @@ ##, {##}] & /@ temp[[1]];
        temp[[1]] = Map[
            If[NumberQ[##] === True, ##*LiteRed`j @@ Prepend[Table[0, {Length[main] - 1}], main[[1]]], ##] &,
            temp[[1]],
            {2}
        ];
        temp[[1]] = Map[If[Head[##] === LiteRed`j, {1, ##}, ##] &, temp[[1]], {2}];
        temp[[1]] = Apply[List, temp[[1]], {2}];
        temp[[1]] = Map[{Times @@ DeleteCases[##, LiteRed`j[__]], Cases[##, LiteRed`j[__]][[1]]}&,temp[[1]],{2}];
        temp[[1]] = Map[{ToString[##[[1]], InputForm], List @@ Drop[##[[2]], 1]} &, temp[[1]], {2}];
        temp = Transpose[temp];
    ];
    main = {If[## === 0, 0, Position[vars, ##][[1]][[1]]] & /@ List @@ Drop[main, 1], temp};
    (*some check*)
    temp = Join[DeleteCases[main[[1]], 0], ##[[2]] & /@ main[[2]]];
    If[Length[temp] =!= Length[vars],
        Print["error it the right part of delayed rule 6"];
        Print[part];
        Abort[]
    ];
    If[Length[Union[temp]] =!= Length[vars],
        Print["error it the right part of delayed rule 7"];
        Print[part];
        Abort[]
    ];
    main
]

NewLeeOrdering[sector_] := Module[{temp, n, ones, neg, hasneg, pos, haspos, i},
    n = Length[sector];
    temp = {};
    ones = Table[1, {n}];
    AppendTo[temp, ones];
    hasneg = False; haspos = False;
    neg = If[## === -1, hasneg = True; 1, 0] & /@ sector;
    pos = If[## === 1, haspos = True; 1, 0] & /@ sector;
    If[And[hasneg, haspos], AppendTo[temp, neg]];
    If[haspos,
        For[i = 1, i <= n, i++,
            If[pos[[i]] === 1,
                pos[[i]] = 0;
                AppendTo[temp, pos];
            ];
        ];
    ];
    If[hasneg,
        For[i = 1, i <= n, i++,
            If[neg[[i]] === 1,
                neg[[i]] = 0;
                AppendTo[temp, neg];
            ];
        ];
    ];
    temp = DeleteCases[temp, Table[0, {n}]];
    temp
]

AnalyzeRule2[rule2_, name2_,pn_Integer] := Module[{rule,expand,temp,temp2,condition,name},
    name=List@@name2;
    rule=rule2;
    If[Head[rule]===List,
        If[Length[rule]>1,
            Print["rule has too many members"]
        ];
        rule = rule[[1]];
    ];
    rule=NormalizePattern[rule,Table[ToExpression["n"<>ToString[i]],{i,Length[name]-1}]];
    If[Head[rule]===List,rule=rule[[1]]];
    If[Head[rule]===Rule,
        temp=If[##===1,1,-1]&/@Drop[name,1];
        SBasisO[0,temp]=NewLeeOrdering[temp];
        Return[{##,"rule"}&/@AnalyzeRule[rule, name,pn]]
    ];
    If[Head[rule]===RuleDelayed,
        temp=If[##===1,1,-1]&/@Drop[name,1];
        If[ToString[Head[name2]]==="jRules",
            SBasisN[0,temp]=.;
        ];
        If[Head[(rule //. Expand -> expand)[[2]]]=!=expand,
            Print["Impossible rule"];
            Print[rule2];
            Abort[];
        ];
        temp=AnalyzeDelayedRule[rule[[2]]];
        Return[{{Prepend[temp,{pn,If[##===1,1,-1]&/@Drop[name,1]}],"delayedrule"}}];
    ];
    Print["Impossible rule"];
    Print[rule2];
    Abort[];
]

AnalyzeRule[rule_Rule, name_List,pn_Integer] := Module[{temp, left, right,i},
    (*one rule from some file*)
    (* now returns a list since a rule may result in OR over all*)
    temp = rule[[1]];
    If[Head[temp] === Condition,
        temp = List @@ temp,
        temp = {temp, True}
    ];
    If[Head[temp[[1]]] =!= LiteRed`j,
        Print["Incorrect rule: ", temp[[1]]];
        Abort[];
    ];
    temp[[1]] = List @@ (AnalyzePattern /@ Drop[(temp[[1]]),1]);
    If[If[##===1,1,0]&/@(temp[[1]]) =!= Drop[name,1],
        Print["Incorrect rule for this name: ", temp[[1]], " , ", name];
        Abort[];
    ];
    temp[[1]] = {pn,temp[[1]]};
    temp[[2]] = LogicalExpand[temp[[2]]];
    If[Head[temp[[2]]]===Or,
        temp[[2]]=List@@temp[[2]];
        temp=AnalyzeRule[Rule[Condition[rule[[1]][[1]],##],rule[[2]]],name,pn]&/@temp[[2]];
        Return[Flatten[temp,1]]
    ];
    temp[[2]] = AnalyzeCondition[temp[[2]],Length[name]-1];
    left = temp;
    right=Collect[rule[[2]]//.(Rule[ToExpression["n"<>ToString[##]],Global`xxx[##]]&/@Range[Length[name]-1]),LiteRed`j[__]];
    If[Head[right]===Plus,
        right=List@@right,
        If[right===0,right={},
            right={right}
        ]
    ];
    right=AnalyzeTerm[##,Length[name]-1]&/@right;
    {Append[left,right]}
]

ToOurOrdering[sector_, matrix_] := Module[{temp, i, j, min, result},
    temp = (sector*##) & /@ matrix;
    If[temp[[1]] =!= Table[1, {Length[sector]}],
        Print["Strange ordering in file"];
        Abort[];
    ];
    For[i = 2, i <= Length[temp], i++,
        min = Min @@ (temp[[i]]);
        If[min < 0,
            temp[[i]] -= (min*temp[[1]])
        ]
    ]; (* getting rid of minus*)
    For[i = 2, i <= Length[temp], i++,
        For[j = 1, j < i, j++,
            While[
                And[
                    (Min @@ (temp[[i]] - temp[[j]])) >= 0,
                    temp[[j]] =!= Table[0, {Length[sector]}]
                ]
                ,
                temp[[i]] -= temp[[j]];
            ]
        ];
    ];
    temp = DeleteCases[temp, Table[0, {Length[sector]}]];
    result = {temp[[1]]};
    For[i = 2, i <= Length[temp], i++,
        If[MatrixRank[result] =!= MatrixRank[Append[result, temp[[i]]]],
            AppendTo[result, temp[[i]]];
        ];
    ];
    If[Length[result] =!= Length[sector],
        Print["Strange ordering in file"];
        Print[result];
        Abort[];
    ];
    If[Det[result] == 0,
        Print["Strange ordering in file"];
        Print[result];
        Abort[];
    ];
    result
]

AnalyzeRules[file_String,pn_Integer] := Module[{name, temp, temp1,temp2,sector,matrix={}},  (*a set of rules in a file*)
    name = ToExpression[file];
    Block[{Last},
        temp = Get[file];
        If[Head[temp]===Last,
            matrix = temp[[1,1]];
            temp = temp[[1,2]];
        ]
    ];
    sector=List@@(If[##===1,1,-1]&/@Drop[name,1]);
    If[SBasisR[0,sector],
        Print["File corresponds to a zero sector: ",name];
        Return[{{},{}}]
    ];
    If[SBasisL[0,sector]>0,
        Print["Already got a basis - skipping: ",name];
        Return[{{},{}}]
    ];
    If[matrix=!={},
        matrix = ToOurOrdering[sector,matrix];
        SBasisO[0,sector] = matrix;
    ];
    If[Head[temp]=!=List,temp={temp}];
    temp = AnalyzeRule2[##, name, pn] & /@ temp;  (*temp comes as a list of pairs*)
    temp=Flatten[temp,1];
    temp1=First/@Cases[temp,{_,"rule"}];
    temp2=First/@Cases[temp,{_,"delayedrule"}];
    If[ToString[Head[name]]==="jRules",
        If[Or[Length[temp2]>1,And[Length[temp1]>0,Length[temp2]>0]],Print["Too many delayed rules"];Print[file];Abort[]];
    ];
    If[ToString[Head[name]]==="jSymmetries",
        If[Length[temp1]>0,Print["Improper symmetries"];Print[file];Abort[]];
    ];
    Return[{temp1,temp2}];
] (* returning on first place for normal rules and on second for delayed*)

TransformRules[directory_String,output_String,pn_Integer] := Module[{temp,temp2,files,i,n}, (*transforms all rules into one file*)
    SetDirectory[directory];
    (Set @@ {SBasisN @@ ##, {}}) & /@ DefinedFor[SBasisL];
    files = Select[
        FileNames[],
        And[FileType[##] === File, StringLength[##] >= 11, StringTake[##, 11] === "ZeroSectors"] &
    ];
    temp = Get[files[[1]]];
    Set[SBasisR[0,Replace[List@@Drop[##,1],0->-1,{0,Infinity}]],True]&/@temp;
    files=Select[FileNames[],And[FileType[##]===File,StringLength[##]>=6,StringTake[##,6]==="jRules"]&];
    temp=Table[{},{Length[files]}];
    For[i=1,i<=Length[files],i++,
        Print[i,": ",files[[i]]];
        temp[[i]]=AnalyzeRules[files[[i]],pn];
    ];
    (*temp comes as a list of pairs*)
    If[temp==={},
        temp={{},{}};
    ,
        temp=Transpose[temp];
        temp=Flatten[##,1]&/@temp;
    ];
    If[FileExistsQ["ExtraOrderings.m"],
        Get["ExtraOrderings.m"];
    ];
    (* now jSymmetries *)
    files=Select[FileNames[],And[FileType[##]===File,StringLength[##]>=11,StringTake[##,11]==="jSymmetries"]&];
    temp2=Table[{},{Length[files]}];
    For[i=1,i<=Length[files],i++,
        Print[i,": ",files[[i]]];
        temp2[[i]]=AnalyzeRules[files[[i]],pn];
    ];
    If[temp2=!={},
        temp2=Last/@temp2;
        temp2 = Flatten[temp2,1];
        If[Length[temp2]>0,
            n = Length[temp2[[1]][[2]]];
            temp2 = DeleteCases[temp2,{_,Range[n],{}}];
        ];
    ];
    AppendTo[temp,temp2]; (*now 3 members *)
    ResetDirectory[];
    Put[temp,output];
    Return[temp];
]

(*structure of rules: a pair:
a>
 list of individual rules:
each one is a tripple
1: a pair of a problem number and a list indicating a sector (1 or -1)
2: a list of conditions being a list of tripples
  2.1: a list of coefficients you should multiply indices by
  2.2: free term
  2.3: a number indicating whether it should be equal to zero (1) or not (0)
3: a list of terms in the result being a list of pairs depending on xxx[i]
  3.1 coefficient (string)
  3.2 indices (being a list of pairs - coefficient and free term)

b>
list of individual delayed rules
each one is a tripple
1: a pair of a problem number and a list indicating a sector (1 or -1)
2: a permutation with zeros
3: a list of terms that have to be multiplied being list of pairs
  3.1 a list of summed terms - coefficient and list of indices
  3.2 power meaning a variable number
*)

ApplyNewRule[point_, rule_] := Module[{temp, sector, i,failure}, (*tries to apply one rule to a point, False on failure*)
    sector = If[## > 0, 1, -1] & /@ (point[[2]]);
    If[rule[[1]][[2]] =!= sector, Return[False]];
    If[rule[[1]][[1]] =!= point[[1]], Return[False]];
    failure=False;
    For[i = 1, i <= Length[rule[[2]]],
        temp = Inner[Times, point[[2]], rule[[2]][[i]][[1]], Plus] + rule[[2]][[i]][[2]];
        If[rule[[2]][[i]][[3]] === 1,
            If[temp =!= 0,failure=True];
        ,
            If[temp === 0,failure=True];
        ];
        i++;
    ];
    If[failure,Return[False]];
    temp = {ToExpression[##[[1]]],((##[[1]])&/@(##[[2]])) . point[[2]]+((##[[2]])&/@(##[[2]]))}&/@(rule[[3]]);
    temp = Replace[temp,(Rule[Global`xxx[##], point[[2]][[##]]] & /@ Range[Length[point[[2]]]]),{0,Infinity}];
    temp=DeleteCases[temp,{0,_}];
    Return[temp];
]

ApplyNewDelayedRule[point_, rule_] :=Module[{temp,main},
    main=j@@Prepend[Table[If[rule[[2]][[i]]===0,0,point[[2]][[rule[[2]][[i]]]]],{i,Length[point[[2]]]}],v];
    temp=Power[Plus@@((ToExpression[##[[1]]]*j@@Prepend[##[[2]],v])&/@##[[1]]),point[[2]][[-##[[2]]]]]&/@rule[[3]];
    Expand[Times@@Prepend[temp,main]]
]

ApplyNewRules[point_, rules_] := Module[{temp, hrules, i}, (*tries all rules; output is a list of pairs - coefficients and indices*)
    temp = False;
    hrules=Cases[rules[[1]],{{point[[1]],If[##>0,1,-1]&/@(point[[2]])},_,_}];
    For[i = 1, i <= Length[hrules],
        temp = ApplyNewRule[point, hrules[[i]]];
        If[temp =!= False, Break[]];
        i++;
    ];
    If[temp===False,
        hrules=Cases[rules[[2]],{{point[[1]],If[##>0,1,-1]&/@(point[[2]])},_,_}];
        If[Length[hrules]===1,
            Return[ApplyNewDelayedRule[point,hrules[[1]]]]
        ];
        Return[ {{1, point[[2]]}}]
    ];
    Return[temp];
]

TargetSectors[point_, rules_] := Module[{temp, sector}, (* finds possible sector mappings after rules usage*)
    temp = ApplyNewRules[point, rules];
    temp = (##[[2]]) & /@ temp;
    temp = Map[If[## > 0, 1, -1] &, temp, {2}];
    temp = Union[temp];
    sector = If[## > 0, 1, -1] & /@ point;
    temp = DeleteCases[temp, sector];
    temp = Rule[sector, ##] & /@ temp;
    temp
]

SymmetryProduct[s1_, s2_] := Table[s1[[s2[[i]]]], {i, Length[s2]}];
SymmetryGroup[symmetries_] := Module[{temp, temp2},
    temp = symmetries;
    While[True,
        temp2 = Tuples[temp, 2];
        temp2 = SymmetryProduct @@@ temp2;
        temp2 = Union[temp,temp2];
        If[temp2 === temp, Break[]];
        temp = temp2;
    ];
    temp
]

NewCoeffForm[x_] := Module[{temp, h},
    If[Head[x]===List,Return[x]];
    temp = Collect[x, a[_], h];
    temp = ExpandAll[temp];
    temp = If[Head[temp] === Plus, List @@ temp, {temp}];
    temp = If[Head[##] === h, ##*a[0], ##] & /@ temp;
    temp = {Cases[##, h[_]], Cases[##, a[_]]} & /@ temp;
    temp = Apply[First, temp, {2}];
    temp
]

OldCoeffForm[x_] := Module[{temp},
    If[Head[x] =!= List, Return[x]];
    temp = {##[[1]], a[##[[2]]] /. a[0] -> 1} & /@ x;
    Plus @@ Times @@@ temp
]

ConvertStart[oldfile_, newfile_] := Module[{temp},
    Clear[
        ProblemNumber, ExampleDimension, SBasis0L, SBasis0C,
        SBasis0D, SBasisL, SBasisD, SBasisA, SBasisH, SBasisO, SBasisC,
        SBasisS, SBasisR, SBasisRL, SBasisM, HPI, SBasisN
    ];
    Get[oldfile];
    Print["Old file loaded"];
    temp = DefinedFor[SBasis0C];
    temp = {##, SBasis0C @@ ##} & /@ temp;
    temp = {##[[1]], NewCoeffForm[##[[2]]]} & /@ temp;
    Clear[SBasis0C];
    temp = {SBasis0C @@ ##[[1]], ##[[2]]} & /@ temp;
    Set @@@ temp;
    Print["Convertion over"];
    Put[Null, newfile];
    Save[newfile,
        {ProblemNumber, ExampleDimension, SBasis0L, SBasis0C,
        SBasis0D, SBasisL, SBasisD, SBasisA, SBasisH, SBasisO, SBasisC,
        SBasisS, SBasisR, SBasisRL, SBasisM, HPI, SBasisN}
    ];
    Print["New file saved"];
]

CompareTables[filename1_,filename2_] := Module[{tables},
    tables = {Get[filename1], Get[filename2]};
    tables = First /@ tables;
    tables = Transpose[tables];
    tables = Transpose /@ tables;
    tables = Last /@ tables;
    tables = Transpose /@ tables;
    tables = Flatten[tables, 1];
    tables = Transpose /@ tables;
    tables = Last /@ tables;
    tables = Map[ToExpression, tables, {2}];
    tables = Together[First[##] - Last[##]] & /@ tables;
    Union[tables]
]

Tables2Rules[filename_, Func_: Identity, JoinTerms_: True, options:OptionsPattern[Global`FIRE]] := Module[{temp, GGG, data},
    data = Get[filename];
    temp = {GGG[##[[1]]], {GGG[##[[1]]], ##[[2]]} & /@ ##[[2]]} & /@ data[[1]];
    Set[GGG[##[[1]]], OptionValue["ResultVar"][##[[2, 1]], ##[[2, 2]]]] & /@ data[[2]];
    temp = temp;
    Clear[GGG];
    temp = DeleteCases[temp, {a_, {{a_, "1"}}}];
    temp = {##[[1]], {##[[1]], ToExpression[##[[2]]]} & /@ ##[[2]]} & /@ temp;
    temp = {##[[1]], {##[[1]], Func[##[[2]]]} & /@ ##[[2]]} & /@ temp;
    If[JoinTerms,
        temp = {##[[1]], Times @@@ ##[[2]]} & /@ temp;
        temp = {##[[1]], Plus @@ ##[[2]]} & /@ temp;
    ];
    Rule @@@ temp
 ]

Tables2Masters[filename_] := Module[{data,temp},
    data = Get[filename];
    temp = Select[data[[1]],And[Length[##[[2]]]==1,##[[2,1,1]]==##[[1]]]&];
    temp = First/@temp;
    Cases[data[[2]],{##,_}][[1,2]]&/@temp
]

CombineTables[filename_, numbers_List] := Module[{temp,tables,GGG},
    temp = StringReplace[filename,".tables"->""];
    temp = (temp<>"_"<>If[TrueQ[NumberQ[##]],ToString[##]<>"-"<>ToString[##],ToString[##[[1]]]<>"-"<>ToString[##[[2]]]]<>".tables")&/@numbers; (*get all file names*)
    tables = Get /@ temp;
    temp = Union[Flatten[Last/@tables,1]]; (* list of all possible correspondances of numbers to integrals*)
    temp = Reap[Sow[##[[1]],GGG@@##[[2]]]&/@temp,_,Flatten[#2,1]&][[2]]; (*collect by integrals *)
    temp = Select[temp,(Length[##]>1)&]; (* search for having more than one equivalent*)
    temp = Table[{GGG[##[[i]]],GGG[Last[##]]},{i,1,Length[##]-1}]&/@temp;
    temp = Flatten[temp,1]; (* replacement pairs *)
    Set@@@temp;
    tables = {{GGG[##[[1]]],{GGG[##[[1]]],##[[2]]}&/@(##[[2]])}&/@(##[[1]]), {GGG[##[[1]]],##[[2]]}&/@(##[[2]])}&/@tables; (* put GG at all places *)
    GGG=Identity;
    tables = tables;
    tables = ReplacePart[tables, Rule[Position[tables, "-(1)/(-1)"], "1"] & /@ Position[tables, "-(1)/(-1)"]]; (* to make unique; this is related to master integrals *)
    tables = {Union[##[[1]]],Union[##[[2]]]}&/@tables;
    temp = Flatten[First/@tables,1]; (* collect all first parts*)
    temp = Reap[Sow[##[[2]],##[[1]]]&/@temp,_,{#1,Flatten[#2,1]}&][[2]]; (* first part, we collected all by integrals and joined *)
    temp = {temp,Union[Flatten[Last/@tables,1]]}; (* add list of different integrals *)
    Put[temp,filename];
]

End[];
EndPackage[];

CreateNewBasis::usage = "CreateNewBasis[name, path] converts FIRE settings into LiteRed commands and calls the NewBasis LiteRed command";

CreateNewBasis[name_, path_] := Module[{temp, SetTemporary},
    (*dimension*)
    SetDim[d];
    (*vectors*)
    If[Complement[Variables[{Propagators,Last/@Replacements}],Join[Internal, External]]==={},
        temp={Join[Internal, External],Vector};
    ,
        temp={Join[Internal, External],Vector,Complement[Variables[{Propagators,Last/@Replacements}],Join[Internal, External]],Number};
    ];
    Print["Declare: ", temp];
    Declare@@temp;
    (*kynematic invariants*)
    temp = If[
        Complement[Variables[##[[1]]], Join[Internal, External]] === {},
        If[Head[##[[1]]] === Power,
            SetTemporary[sp[##[[1]][[1]], ##[[1]][[1]]], ##[[2]]],
            SetTemporary[sp @@ (##[[1]]), ##[[2]]]
        ],
        SetTemporary @@ ##
    ] & /@ Replacements;
    Set @@@ temp;
    (*basis*)
    temp = ReplaceRepeated[
        Propagators,
        {
            Power[a_, 2] :> sp[a, a] /; And[Complement[Variables[a],Join[Internal, External]]==={},Not[NumberQ[a]]],
            Times[a_, b_] :> sp[a, b] /; And[Complement[Variables[{a,b}],Join[Internal, External]]==={},Not[NumberQ[a]],Not[NumberQ[b]]]
        }
    ];
    Print["Lee propagators: ",temp];
    NewBasis[name, temp, Internal, path]
]

Get[FileNameJoin[DeleteCases[{DirectoryName[$InputFileName], "mm","Reconstruction.m"},""]]];
