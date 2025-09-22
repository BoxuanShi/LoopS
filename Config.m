(* $FeynCalcInstallPath = "FeynCalc`"; *)

$FeynCalcInstallPath = FileNameJoin[{DirectoryName @ $InputFileName,
      "LoadDependencies", "Dependencies", "FeynCalc", "FeynCalc.m"
     }];

$MultivariateApartInstallPath = FileNameJoin[{DirectoryName @ $InputFileName,
      "LoadDependencies", "Dependencies", "multivariateapart", "MultivariateApart.wl"
     }];

$FIREInstallPath = FileNameJoin[{DirectoryName @ $InputFileName, "LoadDependencies",
      "Dependencies", "fire", "FIRE6", "FIRE6.m"}];

$OPITeRInstallPath = FileNameJoin[{DirectoryName @ $InputFileName, "LoadDependencies",
      "Dependencies", "opiter", "opiter"}];
