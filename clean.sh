#!/bin/bash

WORKDIR=${WORKDIR:-$(pwd)/build}
DISTDIR=${DISTDIR:-$(pwd)/dist}
BUILDLOG="$DISTDIR/build.log"
source common-source.sh

rm -rf build dist emsdk

echo -e "\n${BLUE}🧹 Cleaned up build and dist directories${NC}"
