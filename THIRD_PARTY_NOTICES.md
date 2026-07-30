# Third-Party Notices

LoopS is distributed under GPL-3.0 and uses the following third-party software. Each component
retains its own copyright and license notices.

## FeynCalc

- Version reported by the package: 10.1.0
- Project: <https://github.com/FeynCalc/feyncalc>
- License: GPL-3.0
- Included license text: `LoadDependencies/Dependencies/FeynCalc/COPYING`

## MultivariateApart

- Version reported by the package: 2021-01-18
- Project: <https://gitlab.msu.edu/vmante/multivariateapart>
- License: GPL-3.0, as recorded in the published program summary
  (<https://doi.org/10.1016/j.cpc.2021.108174>)

## OPITeR

- Bundled source revision: `70c35809d5b496c8dd257990f54e4c562886d90f`
- Project: <https://bitbucket.org/jaegoode/opiter>
- License: GPL-3.0-or-later
- Included license text: `LoadDependencies/Dependencies/opiter/COPYING.md`

## FIRE

- Version reported by the bundled Mathematica package: 7.1
- Source submodule revision: `b038d5de256ff881c32f6e7345de39a2edcab836` (tag `7.1`)
- Project: <https://gitlab.srcc.msu.ru/feynmanintegrals/fire>
- Included files: `FIRE7.m`, `mm/LeeRule.m`, `mm/Reconstruction.m`, and the upstream README
- License notices: `FIRE7.m` and `Reconstruction.m` state GPL version 2; the accompanying README
  states GPL version 3 or, at the user's option, a later version. These upstream notices are
  preserved verbatim and are not replaced by the LoopS license.
- The LoopS repository does not include FIRE's compiled binaries, Fermat, build dependencies,
  benchmarks, or third-party `extra/` tree.

## CalcLoop-derived code

Some LoopS functions are modified from <https://gitlab.com/multiloop-pku/calcloop>. The original
MIT license and copyright notice are retained in the affected source file, including
`EquivalentIntegrals/loopSymmetryNoPS.m`.
