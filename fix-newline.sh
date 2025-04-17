#!/bin/bash

find . -type f -name "*.*" ! -path "*/.git/*" -exec sed -i 's/\r$//' {} \;
