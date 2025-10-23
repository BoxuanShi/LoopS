ParallelLoad[] := Module[{loadlist},
  loadlist = Union @ Flatten @ DownValuesArguments @ ParallelLoad;
  ParallelLoad /@ loadlist]