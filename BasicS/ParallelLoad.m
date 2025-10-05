(* ParallelLoad[] := Module[{loadlist},
  loadlist = Union@Flatten@DownValuesArguments@ParallelLoad;
  ParallelLoad /@ loadlist] *)
(*unused*)
ClearAll[ParallelLoad];
ParallelLoad[body_]:=Parallel`Protected`AddInitCode[
 Parallel`Client`HoldCompound[
  body
  ]]