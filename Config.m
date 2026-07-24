(* $FeynCalcInstallPath = "FeynCalc`"; *)

$FeynCalcInstallPath = FileNameJoin[{DirectoryName @ $InputFileName,
      "LoadDependencies", "Dependencies", "FeynCalc", "FeynCalc.m"
     }];

$MultivariateApartInstallPath = FileNameJoin[{DirectoryName @ $InputFileName,
      "LoadDependencies", "Dependencies", "multivariateapart", "MultivariateApart.wl"
     }];

$FIREInstallPath = FileNameJoin[{DirectoryName @ $InputFileName, "LoadDependencies",
      "Dependencies", "fire", "FIRE7", "FIRE7.m"}];

$KiraExecutable = "kira";
$KiraFermatExecutable = Automatic;

$OPITeRInstallPath = FileNameJoin[{DirectoryName @ $InputFileName, "LoadDependencies",
      "Dependencies", "opiter", "opiter"}];

$AMFlowInstallPath = "AMFlow`";
$BladeInstallPath = "Blade`";
