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
## [FIRE7] - 2025-10-08
A major public release bringing many new featues. For details refer to the article
### Features
- New tools for working with tables without Wolfram Mathematics including different recosntruction methods
- Two-stage Gaussian elimination pre-solve before seeding sampling points;
- Configurable integral orderings (like in Kira)
- Multiprime modular mode for parallel reconstruction allowing to run reduction in multiple prime points at the same time;
- Split-master reduction and table combination workflow;
- Extended support for {\tt LiteRed2} integration.
## [FIRE6.9] - 2023-07-29
### Features
- Added upgraded communication with fuel allowing symbolica usage
- Added possibility for MPI wrapper to run all reconstruction properly between runs
### Maintenance
- Added support of older gcc versions
- Added some configuration options such as static libstdc++ usage
## [FIRE6.8] - 2023-05-10
### Features
- Added rational, Thiele, Newton and balanced reconstruction in c++
- Added table comparisson in c++
- Switched to fuel library for simplification of expressions (https://bitbucket.org/feynmanIntegrals/fuel). It can use multiple simplifiers now
- Added odd/even option to use only a half of IBPs
### Maintenance
- Upgrated Litered version to get things working with Mathematica 13
- Upgraded code style and possible issues to work clean with newer compilers
### Removed
- Removed python usage
## [FIRE6.7] - 2022-05-15
### Features
- Added the CocoaLib simplifier
- Added the Form simplifier
- Added the Maxima simplifier
- Added the clean_database option to automatically clean it all after finishing
- single_sector config file option for tests
- Added a possibility to run rational reconstruction during an MPI run
- Added balanced reconstruction to python scripts, some examples
### Features
- Improved the size of start files
- Added instructions how to run FIRE in docker
### Removed
- Removed the ImproveMasters code, it is a separate project now
### Maintanance
- Upgraded version of LiteRed
- All Mathematica codes are now inside a package
### Fixed
- Fixing build on mac
- Fixing how FIRE works with math13
- Fixed how larger pos_pref works
- Fixed build with newest gcc12
## [FIRE6.6] - 2021-03-08
### Features
- \#one_pass option added pointing to a file with a database allowing to run reduction in one pass. Speeds up the modular reduction.
- \#ginac option and --enable_ginac configure option switching coefficient simplifying library from fermat to ginac.
- ImproveDE code for searching for a good basis for differential eqations.
- ImproveMasters code has a way to construct ep-finite bases.
- \#ordering option to set up ordering type and \#index_ordering option to set up the ordering between indices.
### Maintanance
- Size of virt count in sectors increased to 64 bit
- Mimalloc upgraded to 1.6.7

## [FIRE6.5] - reserved for releases of public FIRE. 6.5 should appear end of October 2023

## [FIRE6.4.9], previously [FIRE6.5.4] - 2020-09-29
The release bring python reconstruction and check, the sector solving function and multiple fixes.
### Features
- New tool - python-based reconstructor, supports rational reconstruction and Thiele reconstruction over single variable.
  Provided as alternative to Mathematica functions, requires python3.5 or higher
- New tool - python-based tables comparator. Serves as default comparison tool in tests if python is enabled.
- For in-depth information about new tools refer to python/README
- Clang compilation support
- Docker installation added
- \#old_presolve and \#full_presolve (default) got an extra optional argument - the number of IBPs that are presolves. Can be used not no mix IBPs and LIs
- New commands in Mathematica to solve sectors without master integrals.
  Use the SolveSectors[diag] function (with a Parallel->True option). Should be used right after the DiskSave[diag] command that creates a Lee bases directory.
### Fixed
- The \#old_presolve option was finally fixed
- Parser fixed for Windows line endings
- Crash for completely zero diagrams fixed
- FTool fixed (was broken on database format change)
### Maintanance
- Versions of zstd and mimalloc upgraded for performance
- Cleared extra spaces at line ends in the code
- Printing requested levels now in all sectors
## [FIRE6.4.8], previously [FIRE6.5.3] - 2020-05-28
The release brings up multiple bugfixes and at the same time provides new Mathematica functions for better masters choice and efficient sector solving
### Features
- ToLeeRule function in Mathematica that gives a possibility to provide hand-made solutions in sectors. Run ?ToLeeRule for details
- Improve masters code in Mathematica. See [the paper](https://arxiv.org/abs/2002.08042) for details
### Maintenance
- Problem number in c++ FIRE was extended from unsigned short to unsigned int
- Equation maximum length extended from unsigned int to unsigned long long
### Fixed
- FIRE does no longer freeze in case of varibles with capital letters, but stops with an error message. Also added a warning in Mathematica
- Small point mode is not always on (fixed the configure script)
- FIRE does not simply crash with too many indices but provides a proper diagnostics
- Doxygen documentation fixed
- Usage of lbases rules fixed in prime mode (could provide incorrect results)
- BalancedNewton reconstruction fixed (could provide wrong results in rare cases)
## [FIRE6.4.7], previously [FIRE6.5.2] - 2020-01-31
This release is focused on performance, upgrade of legacy code and reconstruction methods
### Features
- New configure option --enable-mimalloc turns on the new microsoft memory allocator (performance)
- New configure option --enable-lto turns on link time optimizations for the prime version (performance)
### Improved
- Improved performance with code profiling, assembly instructions and separate branch for equation generation in hint mode
- Balanced Newton reconstruction can work now in case some coefficients turn to zero
- Newton and Thiele reconstruction received an option to reconstruct with any variable name directly.
### Changed
- Changed presolving of IBPS. In known examples it can increase speed a lot but potentially can change the way reduction goes
Old behaviour can be switched on with the \#old_presolve option
### Maintenance
- Print when code creates new hint files
- Upgrade to the c++14 standart, now gcc 5 is required to compile FIRE; upgrade of code style to modern standarts
- Upgrade of the equation class to avoid manual memory allocations and use modern c++ features
## [FIRE6.4.6], previously [FIRE6.5.1] - 2020-01-09
This release adds some important features to have stable massive runs of the prime version with diffirent values of two variables
### Features
- New option (-m) for MPI to have the master-node also run reduction
- New option (-i) for MPI to inverse the order of task seeding giving priority to change of variables. Also this option turns on checks for reconstructed tables
- New option (-d) for MPI to have a random delay after start. This prevents (with a high probability) jobs starting at the same time from working on same tasks
### Improved
- The prime version of FIRE reruns a level subreduction in case hint does not work properly. This prevents extra masters and is crutial for stable running of the prime version
- The rational reconstruction now works if some of the tables are empty
## [FIRE6.4.5], previously [FIRE6.5.0] - 2019-12-29
The current release is aimed on improving performance of the prime version in order to be able to apply modular arithmetics in an efficient way.
### Features
- New syntax for the number of threads (old one also allowed), {n, {l1->n1, ...}}
  here n is the default number of threads, and n1 is used an level l1 (only Laporta part) and similar
### Improved
- Multiple internal code optimizations, especially in prime mode
- Entries from sectors to lower sectors are moved parallely to increase speed
- Internal code renamings for better readability
- Strict compilation options to prevent errors
- Table reconstruction can now succeed whensome of the tables are missing
### Changed
- \#bucket option is changed for consistency. When switching from older versions, please decrease the value by 4 to achieve same result
- Operating system instructions to not cache files are removed for some speedup, as having no real reasoning without disk mode
- Database file 0001.tmp is no longer used for storing integrals, but for storing requests from higher sectors to lower
- Fermat separate mode (fthreads s<number>) does not divide this number by the number of threads
- Options syntax changed to use the standart getopt syntax parsing. Run FIRE with no options to see details
- Variables syntax now uses underscore to separate variables. MPI syntax uses : to specify ranges. This allows passing negative variable values from command line, but changes table namings!
### Deprecated
- disk_db configuration option is removed as never being optimal
- \#nolock option removed as having meaning only for disk databases
- \#keep_all option removed as having no real meaning
- \#port option and work at multiple computers removed
- enable_lthreads configuration option removed, we learned to switch kyoto parallel option without rebuild
- FSB allocator dependancy removed
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
<a name="changed"></a>
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
