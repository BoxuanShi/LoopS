# README #

FIRE stands for Feynman Integral REduction

### Articles ###

* [FIRE3](http://arxiv.org/abs/0807.3243)
* [FIRE4](http://arxiv.org/abs/1302.5885)
* [FIRE5](http://arxiv.org/abs/1408.2372)
* [FIRE6](http://arxiv.org/abs/1901.07808)
* [FIRE6.5](http://arxiv.org/abs/2311.02370)

### Installation ###

Either download a binary package, or

* git clone https://gitlab.com/feynmanIntegrals/fire.git
* cd fire/FIRE6
* ./configure
* Now read the options provided by ./configure and reconfigure with desired options, for example
* ./configure --enable_tcmalloc --enable_zstd --enable-debug
* make dep
* make

Add the following configure options to enable support of new simplifiers
* --enable-flint --enable-symbolica

FIRE works under various Linux distributions.
FIRE works under Windows inside the WSL, version 2 (Windows subsystem for Linux). Just get WSL with an Ubuntu installation.

Important notice! We ship LiteRed 1.8.3 with FIRE. It is a separate package created by R.N.Lee, and in case it is used, a paper on LiteRed should be cited together with FIRE.

In case of changes in ./configure options it is recommended to have a clean rebuild

* make cleandep
* make clean
* make dep
* make

### Usage ###

* make test
* Follow the instructions in the article [FIRE6](http://arxiv.org/abs/1901.07808) and additional instructions on using different simplifier backends in [FIRE6.5](http://arxiv.org/abs/2311.02370).
* There are some examples in the examples folder
* You can run bin/FIRE6 without options to see possible options. Note the syntax was changed between 6.5 and 6.5.1 - we updated the syntax to the classical linux style with "short options" (like -c) and their "long option" analogues (like --config)
* a new option (--calc-options) can be used to pass options to FUEL
* see CHANGELOG.md for changes between versions

For details of installation under OSX we recommend to use brew-installed llvm.
* brew install automake
* brew install llvm

Also see [the following issue](https://gitlab.com/feynmanintegrals/fire/-/issues/10) thanks to Sudeepan Datta

### Documentation ###

Doxygen is used to create documentation for FIRE.
You need to have _doxygen_ installed to generate documentation.

To generate docs run

* make doc

This will create _html/_ and _latex/_ subfolders in _FIRE6/documentation/_
_html/_ contains complete docs, _latex/_ contains latex sources.

To generate .pdf from latex sources, run

* make doc_pdf

You will need to have appropriate tools installed, like _pdflatex_.
This will generate _refman.pdf_ and place it directly in _FIRE6/documentation/_

To view docs after creation, either

* open _FIRE6/documentation/html/index.html_ in your Web Browser
* open _FIRE6/documentation/refman.pdf_ (after generating it)

To delete documentation run

* make cleandoc

### More information ###

* For the package structure see FIRE6/README
* For examples listing see FIRE6/examples/README
* For information about documentation see FIRE6/documentation/README

### External packages ###

* Most of the packages that FIRE uses are open-source, so they are included in the FIRE distribution
* FIRE relies on the [Fermat](https://home.bway.net/lewis/) program by Robert Lewis. Fermat is free-ware, but has some restrictions for organizations. Fermat is shipped in the FIRE package, however it is the user responsibility to check, whether his use of Fermat is legal. If one does not accept the Fermat license, he should not use the fermat as well.
* An alternative variant to Fermat is to enable new simplifiers, Flint or Symbolica. Flint is open-source and free, Symbolica has restrictions.
* Suggested usage is together with [LiteRed](http://www.inp.nsk.su/~lee/programs/LiteRed/). Do not forget to include a reference to https://arxiv.org/abs/1310.1145 in this case.
