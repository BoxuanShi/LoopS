# README #

FIRE stands for Feynman Integral REduction

### Articles ###

* [FIRE3](http://arxiv.org/abs/0807.3243)
* [FIRE4](http://arxiv.org/abs/1302.5885)
* [FIRE5](http://arxiv.org/abs/1408.2372)
* [FIRE6](http://arxiv.org/abs/1901.07808)
* [FIRE7](https://arxiv.org/abs/2510.07150)

### Installation ###

* git clone https://gitlab.srcc.msu.ru/feynmanintegrals/fire.git
* cd fire/FIRE7
* ./configure
* Now read the options provided by ./configure and reconfigure with desired options, for example
* ./configure --enable_zlib --enable_snappy --enable_tcmalloc --enable_zstd
* make dep
* make

On Mac Os X you need the brew-installed llvm
* brew install automake
* brew install llvm
* brew install libomp

There are problems with llvm16 w-functions (not related to our project), so provide a path to llvm17, for example PATH=/usr/local/Cellar/llvm/17.0.6_1/bin:$PATH3/bin:$PATH)

Important notice! We ship LiteRed 1.8.3 with FIRE. It is a separate package created by R.N.Lee, and in case it is used, a paper on LiteRed should be cited together with FIRE.
FIRE is supposed to work with LiteRed 2, but it should be downloaded separately.

In case of changes in ./configure options it is recommended to have a clean rebuild

* make cleandep
* make clean
* make dep
* make

FIRE is known to work at different Linux distributions and also under Windows with the new WSL2.
Building under Mac OS X requires some tricks, however the docker approach can be used (see below).
FIRE works under Windows inside the WSL, version 2 (Windows subsystem for Linux). Just get WSL with an Ubuntu installation.

## Docker ##

An alternative installation method is to use docker.

The FIRE image can be obtained from Docker Hub with

* docker pull asmirnov80/fire:latest

A version or some commit hashes can be specified, for example,

* docker pull asmirnov80/fire:7.0

Now one can launch FIRE from the container like

* docker run --rm asmirnov80/fire /app/FIRE7/bin/FIRE7 --help

As Docker containers are sandboxed, any host folder needs to be explicitly mounted as a volume to be accessed by FIRE inside the container. For example, the following command mounts the current directory as the host folder in the container and makes it the working directory when launching FIRE:

* docker run --rm -v $PWD:/host -w /host fire7 /app/FIRE7/bin/FIRE7 --help

For advanced users who want to re-build the Docker image after local modification to the FIRE code, here are the instructions.
First, make a new clean clone of FIRE, change directory to the outer fire folder and run

* docker build -t fire7 .

to build the image. Warning: trying to build a docker image within a folder where FIRE has been already built might lead to build errors or unexpected behavior. Each time this command is issued, the contents of the FIRE7 folder is copied into the container and rebuilt. Then the image can be used with

* docker run --rm fire7 /app/FIRE7/bin/FIRE7 --help

### Usage ###

* make test
* Follow the instructions in the articles
* There are some examples in the examples folder

### Alternative usage with docker ###

* cd fire
* docker build -t fire .
* docker run -it --rm -v <PATH_TO_YOUR_FOLDER_WITH_DATA>:/data fire sh -c "bin/FIRE7 -c /data/<CONFIG_FILE_NAME>"

### Documentation ###

Doxygen is used to create documentation for FIRE.
You need to have _doxygen_ installed to generate documentation.

To generate docs run

* make doc

This will create _html/_ and _latex/_ subfolders in _FIRE7/documentation/_
_html/_ contains complete docs, _latex/_ contains latex sources.

To generate .pdf from latex sources, run

* make doc_pdf

You will need to have appropriate tools installed, like _pdflatex_.
This will generate _refman.pdf_ and place it directly in _FIRE7/documentation/_

To view docs after creation, either

* open _FIRE7/documentation/html/index.html_ in your Web Browser
* open _FIRE7/documentation/refman.pdf_ (after generating it)

To delete documentation run

* make cleandoc

### More information ###

* For the package structure see FIRE7/README
* For examples listing see FIRE7/examples/README
* For information about documentation see FIRE7/documentation/README

### External packages ###

* Most of the packages that FIRE uses are open-source, so they are included in the FIRE distribution
* FIRE relies on the [Fermat](https://home.bway.net/lewis/) program by Robert Lewis. Fermat is free-ware, but has some restrictions for organizations. Fermat is shipped in the FIRE package, however it is the user responsibility to check, whether his use of Fermat is legal. If one does not accept the Fermat license, he should not use the C++ FIRE as well.
* Suggested usage is together with [LiteRed](http://www.inp.nsk.su/~lee/programs/LiteRed/). Do not forget to include a reference to https://arxiv.org/abs/1310.1145 in this case.
