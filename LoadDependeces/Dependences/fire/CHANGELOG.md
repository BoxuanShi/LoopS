# Changelog
All notable changes to this project will be documented in this file.
This changelog uses following notations for sections:
- Features – for new features.
- Improved – for general improvements.
- Changed – for changes in existing functionality.
- Deprecated – for soon-to-be removed features.
- Removed – for removed features.
- Maintenance – for tidying code and internal minor changes.
- Fixed – for any bug fixes.
## [FIRE6.5.2] - 2024-04-01
A few bug fixes and examples

### Features
- Refactored the point structure (and many related functions) to allow for much  smoother changing of MAX_SECTORS and/or MAX_IND (by Alex Edison)

## [FIRE6.5.1] - 2024-02-01

### Fixed
- Usage in Mathematica 13.3
- Some bug fixes in fuel including possible crashes and freezes
- Fixed regression on LiteRed + modular
- Cleaner saving storage files to prevent corrupted data
- Fixed installation of Mac OS X

### Improved
- Performance updates of flint and symbolica and fuel
- Speed of FindRules thanks to Josh Davies

### Features
- An option --calc-options to pass options to fuel, one can try factorize_denominators with symbolica

## [FIRE6.5] - 2023-11-03
### Features
- We add the fuel interface and possibility to use different simplifiers such as flint and symbolica.

## [FIRE6.4.4] - 2023-03-03
Some bug fixes and...
### Features
- Balanced reconstruction is out

## [FIRE6.4.3] - 2022-03-30
This release mostly has bug fixes

### Features
- the clean\_database option for config files  to remove databases after work
- Tests for the Mathematica part added (make testmath)
- ImproveMasters code added (in fact mostly in release 6.4.1)

### Improved
- Mathematica code improved, it is now a package with options

### Fixed
- The build on OS X was fixed, instructions provided
- Litered updated to 1.8.3 to fix behaviour on Mathematica 13
- Got rid of combinatorica package to fix warnings on Mathematica 13
- Some examples fixed
- Fixing loading FIRE from other folders
- Fixing crashes for completely zero diagrams
- Increasing size of problem number to unsigned int to allow bigger numbers
- Crashing, not freezing on capital letters for variables. Warning in Mathematica
- Fixing build for some combination of options

### Removed
- \#port option and work at multiple computers removed

## [FIRE6.4] - 2019-11-20
This release includes:
- Reworkings and optimisations for MPI wrapper and **changes command line interface for it**.
- Changes to configuration files.
- Rational reconstruction optimisations.
- Various bug fixes.

### Features
- This CHANGELOG.md file.
- MPI wrapper can accept arbitrary number of variables now. See [Changed](#changed) for details on interface.
- FIRE6p executable now have option to skip table if it is already calculated (add ! before the output table name).
- Rational reconstruction now have parallel mode, that significantly speeds it up.
- Rational reconstruction can work on ranges of primes when some tables in-between are missing.
  For example, if tables for primes 1-7 and 10-14 are calculated, now RR still tries to reconstruct instead of exiting immediately.
- Verbose output is enabled for worker, if FIRE6_MPI is launched on 2 processes.
- When using `zstd` in config one can specify compression level.
  Use `zstd:%d` for `#compressor`, where `%d` is positive viable value for level.

### Improved
- Optimise MPI wrapper, now it doesn't spend time on checking tables' existence beforehand
  and delegates this to workers. Memory consumption is also optimised.

### Changed
- Completely rework MPI wrapper's command line interface. Now it takes special _variable string_ as argument, instead of
  old fixed positional args.  
  The string must be of following template: `d1-d2;x1-x2;f1-f2;p`, where `d1-d2` is range for variable and `p` is prime numbers limit.
  For example - '`100-110;4-5;1-1;6` is a valid string.  
  Each variable setting can contain a number of comma-separated ranges of fixed variable values as well.
  It should be noted, that any number of variables can now be used, yet their positioning in this variable string should match that of config file.  
  For further information refer to `--help` option of FIRE6_MPI.
- Rename MPI wrapper source file.

### Deprecated
- \#small option in config is now obsolete as it was unsafe for calculations. Use `configure`'s option `--small_point` 
  to make point size 16 bytes instead of 24.
- \#memory option in config is now obsolete as it is default behaviour now. To change this, use `configure`'s option `--disk_database`
  to switch to disk database mode.
- \#clean option in config is now obsolete as we don't use semaphores anymore.

### Fixed
- Fix kyotocabinet bug that resulted in failure at entries over 2^31 (mostly related to wrap mode).
- Fix silent-masters mode combination not stopping on unlisted masters.

### Maintenance
- Remove wrapper thread.
- Update lz4 and zstd compressors.
- Various internal memory optimisations.
- Various code cleanups and transitions to C++11 libs.

## [FIRE6.3.2] - 2019-06-10
Final paper can be found [here](https://doi.org/10.1016/j.cpc.2019.106877), but beware of possible access restrictions.

### Features
- Add -variable option in poly mode.
- Add BalancedNewton reconstruction.
- Write designated handler for various signals, like SYGTERM and SYGABRT.

### Changed
- Switch to eu-addr2line for printing lines on crash.

### Fixed
- Fix semaphores in case when sthreads config value is bigger that threads.

## [FIRE6.3.1] - 2019-05-19

### Maintenance
- Include equation.inl into documentation.

### Fixed
- Fix gateToFermat incorrect behavior in case of numbers longer than 1023 symbols.
- Fix the case when Fermat produces a long line and fgets picks no new line symbol at the end.

## [FIRE6.3] - 2019-05-06
This release focuses on optimisations and tweaks related to IBP.

### Features
- Add IBP presolving (optimization). 
- \#no_presolve option to switch off presolving.

### Improved
- Optimize solving IBPs (performance).

### Changed
- Update `box` and `doublebox` examples with LI identities.

### Maintenance
- IBPs are kept as vectors of pairs.
- COEEF is now a proper class, non struct.
### Fixed
- Fix crash in case of unspecified masters in master mode.
- Fix crash on missing preferred file.

## [FIRE6.2] - 2019-03-04
This release concerns mostly work with master integrals.

### Features
- Add Tables2Master, CombineTables functions to `FIRE6.m`.

### Improved
- Upgrade work with IBPs and symmetries (performance).
- Add various checks when working with master integrals.

### Changed
- Generated table name now includes master integral number.

### Fixed
- Fix crash in case of equal custom IBPs.

## [FIRE6.1.2] - 2019-02-11
**This release is preferred to other 6.1 releases.**

### Fixed
- Fix position preference (pos_pref), also allowing it to be negative.

## [FIRE6.1.1] - 2019-02-11

### Fixed
- Fix tables save.

## [FIRE6.1] - 2019-02-10

### Features
- Always print tables destination.
- Add Table2Rules function to convert tables directly to Mathematica rules.
- Add documentation for all entities in code - see README.md for instructions on generation.
- Add PVS checks.

### Improved
- Fix disparity in output streams for error messages and in messages themselves.

### Changed
- Update LiteRed package.

### Maintenance
- Various code cleanups and transitions to C++11.

## [FIRE6.0.1] - 2019-01-25

### Fixed
- Fix broken (but switched off) joint fermat mode.
- Fix the \#port mode (again) after the fix of the fermat joint mode.

## [FIRE6.0] - 2019‑01‑24
Paper draft can be found [here](http://arxiv.org/abs/1901.07808).
