(*the option Verbose is set as False by default to preserve the print from \
FIRE.
the exception is /.G->F for CXX reduction, print from the FIRE is reserved to \
check whether all reduction is done by terminal.
*)
ClearAll[FIRETemplate];
FIRETemplate = <|
   "Start" -> StringTemplate["Get[`FIRE`];
Internal = `Internal`; 
External = `External`; 
Propagators = `Propagators`; 
Replacements = `Replacements`; 
PrepareIBP[];
Prepare[AutoDetectRestrictions\[Rule]True,LI\[Rule]True];
SaveStart[ToString[`family`]];
Pause[1];
Quit[];
"],
   
   "Config" -> "#compressor `compressor`
#threads `tThreads`
#clean_databases
#fthreads `fThreads`
#sthreads `sThreads`
#variables d, `variables`
#start
#folder `folder`
#problem `problem` `familyName`.start
#integrals `familyName`.m
#output `output`"
   |>;