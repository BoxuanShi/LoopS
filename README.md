# LoopS


## Usage

An example notebook examples.nb is provided in the Examples directory.
You can open this notebook to learn how to use LoopS step by step.


## Dependencies

This package includes the following third-party modules or interfaces:

- **[FeynCalc](https://github.com/FeynCalc/feyncalc)**
- **[FIRE](https://gitlab.com/feynmanintegrals/fire)**
- **[MultivariateApart](https://gitlab.msu.edu/vmante/multivariateapart)**
- **[OPITeR](https://bitbucket.org/jaegoode/opiter/src/main/)** (included as a Git submodule)

All these modules are licensed under GPL-3.0.

Additionally, some functions are modified from the **[CalcLoop](https://gitlab.com/multiloop-pku/calcloop)** package, which is licensed under the MIT License.


**Note:** 
- Users can also customize the paths of dependencies by editing the `Config.m` file
  located in the main LoopS directory. This allows you to specify where external 
  packages (e.g., FeynCalc, FIRE, MultivariateApart, OPITeR) are installed on your system.
- Direct downloads may not include OPITeR. If missing, LoopS will automatically notify you in Mathematica and provide instructions to install it.
- This package has only been tested on **Mathematica 14.0**.
- **[FORM](https://www.nikhef.nl/~form/)** (Source code also available on [GitHub](https://github.com/form-dev/form)): Required for OPITeR. Please install FORM separately if you intend to use OPITeR features.

LoopS can be used without OPITeR, but the efficiency of Passarino–Veltman reduction will be significantly reduced in complex cases if OPITeR is not available.


## License

- This package (LoopS) and its included FIRE, MultivariateApart, and OPITeR related code are licensed under GPL-3.0.
- By using this package, you agree to comply with the GPL-3.0 terms.
- Original contributions from CalcLoop (MIT) are acknowledged, but the modified
versions included here are redistributed under GPL-3.0.


## Usage Notes

- LoopS relies on the current notebook directory (`NotebookDirectory[]`) for certain operations.
  If your notebook has not been saved, `NotebookDirectory[]` will return `$Failed`, and some 
  functions may not work as expected. Please **save your notebook before loading LoopS**.


## Citation

If you use LoopS in your research, please cite it as:
Shi, Bo-Xuan. LoopS: A Mathematica package for Feynman amplitudes reduction. Zenodo, 2025. DOI: [10.5281/zenodo.17383900](https://doi.org/10.5281/zenodo.17383900)