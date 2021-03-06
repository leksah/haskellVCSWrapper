#!/bin/bash -ex

echo $PATH
export LC_ALL=C.UTF-8

if [[ -d .cabal && -d .ghc ]]; then
    cp -a .cabal .ghc /root
fi

cabal update
cd vcswrapper
cabal new-build

# update the cache
rm -rf .cabal
cp -a /root/.cabal ./
rm -rf .ghc
cp -a /root/.ghc ./
