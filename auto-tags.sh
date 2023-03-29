#!/bin/bash

set -e
git ls-files | sed "/\.cpp$/!d" > cscope.files
git ls-files | sed "/\.c$/!d" >> cscope.files
git ls-files | sed "/\.h$/!d" >> cscope.files
git ls-files | sed "/\.py$/!d" >> cscope.files
git ls-files | sed "/\.pl$/!d" >> cscope.files

ctags -L cscope.files
