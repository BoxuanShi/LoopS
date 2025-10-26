Here are instructions for using FIRE's Docker image with Apptainer, which is a Docker-compatible container tool widely used for HPC.

# Installation

## option 1: pulling from Docker Hub
The Docker image can be directly pulled by Apptainer.
```bash
apptainer pull docker://asmirnov80/fire
```
This results in a `fire_latest.sif` container image file.

## option 2: manual conversion
If you manually re-build a custom Docker image, e.g. after modifying FIRE code, you can convert it to the Apptainer format manually. First, export the docker image to a tar archive
```bash
docker save -o fire.tar fire # assume fire is the docker image name
```

Then build an apptainer image (.sif file):
```bash
apptainer build fire_latest.sif docker-archive://fire.tar
```

# Running the Apptainer image

```bash
apptainer exec /path/to/fire_latest.sif /app/FIRE7/bin/FIRE7 --help
```
The Apptainer container is sandboxed but is given read/write access to the current working directory by default, so you need to keep the config file, integral file, output file directory etc. all under the current working directory or sub-directories.
