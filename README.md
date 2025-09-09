# LoopS

This package includes the following third-party modules or interfaces:

- **FIRE**
- **MultivariateApart**
- **OPITeR**

All these modules are licensed under GPL-v3.

Additionally, some functions are copied and modified from the CalcLoop package, which is licensed under the MIT License.

## License Statement

- This package (LoopS) and its included FIRE, MultivariateApart, and OPITeR related code are licensed under GPL-v3.
- By using this package, you agree to comply with the GPL-3.0 terms.
- Original contributions from CalcLoop (MIT) are acknowledged, but the modified
versions included here are redistributed under GPL-3.0.

## Acknowledgements

Special thanks to the FIRE, MultivariateApart, OPITeR, and CalcLoop projects for their open source contributions.

---

For details about the licenses of each module, please refer to their official documentation or the LICENSE file in their source code.

## Dependencies

- **FeynCalc**: Required for LoopS. Please install FeynCalc and ensure it can be loaded in Mathematica using ``<<FeynCalc` ``.
- **Form**: Required for OPITeR. Please install FORM separately if you intend to use OPITeR features.

LoopS can be used without OPITeR, but the efficiency of Passarino–Veltman reduction will be significantly reduced in complex cases if OPITeR is not available.