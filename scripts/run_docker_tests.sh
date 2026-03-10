#!/bin/sh

set -e

docker build -t qsys-plugin-bmd-videohub -f Dockerfile.test .
docker run --rm -it qsys-plugin-bmd-videohub
