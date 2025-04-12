#!/bin/sh

docker build . -t icu4c-builder && docker run icu4c-builder:latest
