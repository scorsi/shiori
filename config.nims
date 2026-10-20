# Outside Nix builds, the dev shell lists the lock.json sources in SHIORI_NIM_PATHS
# (buildNimPackage passes them as --path flags itself).
import std/strutils
for p in getEnv("SHIORI_NIM_PATHS").split(':'):
  if p != "": switch("path", p)
