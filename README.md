# LoopS

This package includes the following third-party modules or interfaces:

- **[FIRE](https://gitlab.com/feynmanintegrals/fire)**
- **[MultivariateApart](https://gitlab.msu.edu/vmante/multivariateapart)**
- **[OPITeR](https://bitbucket.org/jaegoode/opiter/src/main/)** (included as a Git submodule)

All these modules are licensed under GPL-3.0.

Additionally, some functions are copied and modified from the **[CalcLoop](https://gitlab.com/multiloop-pku/calcloop)** package, which is licensed under the MIT License.

**Note:** 
- Direct downloads may not include OPITeR. If missing, LoopS will automatically notify you in Mathematica and provide instructions to install it.
- This package has only been tested on **Mathematica 14.0**.

## License Statement

- This package (LoopS) and its included FIRE, MultivariateApart, and OPITeR related code are licensed under GPL-3.0.
- By using this package, you agree to comply with the GPL-3.0 terms.
- Original contributions from CalcLoop (MIT) are acknowledged, but the modified
versions included here are redistributed under GPL-3.0.

## Acknowledgements

Special thanks to the FIRE, MultivariateApart, OPITeR, and CalcLoop projects for their open source contributions.

---

For details about the licenses of each module, please refer to their official documentation or the LICENSE file in their source code.

## Dependencies

- **[FeynCalc](https://feyncalc.github.io/)**: Required for LoopS. Please install FeynCalc and ensure it can be loaded in Mathematica using ``<<FeynCalc` ``.
- **[FORM](https://www.nikhef.nl/~form/)** (Source code also available on [GitHub](https://github.com/form-dev/form)): Required for OPITeR. Please install FORM separately if you intend to use OPITeR features.

LoopS can be used without OPITeR, but the efficiency of Passarino–Veltman reduction will be significantly reduced in complex cases if OPITeR is not available.