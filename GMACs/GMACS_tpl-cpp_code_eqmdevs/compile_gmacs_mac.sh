#!/bin/zsh
# ============================================================================
# compile_gmacs_mac.sh -- build gmacs on macOS (arm64, ADMB 13.2 + clang)
#
# Differs from compile_gmacs.sh in ONE respect: the auxiliary sources are
# compiled ONE DIRECTORY DOWN (in src_mac/) rather than copied to the top
# level. They select their headers by platform --
#     #if defined __APPLE__ || defined __linux
#     #include "../include/nloglike.h"
#     #if defined _WIN32 || defined _WIN64
#     #include "include\nloglike.h"
# -- so the Windows form resolves from the top level (what make_win.bat does)
# but the Apple form needs to sit one level below include/. Copying them up, as
# compile_gmacs.sh does, makes every one of them fail with
# "'../include/nloglike.h' file not found".
#
# We stage into src_mac/ rather than building in src/ because the distributed
# src/ and include/ are mode 555, so clang cannot write src/*.obj there.
#
# PREREQUISITE: the ADMB install must carry the platform-suffixed contrib
# library name that the `admb` driver looks for. The macOS installer ships it
# unsuffixed, which silently drops -I include/contrib and makes every vector
# dnorm() call in gmacs.cpp fail to resolve. Fix once, per machine:
#     ln -sf /usr/local/admb/lib/libadmb-contrib.a \
#            /usr/local/admb/lib/libadmb-contrib-arm64-macos-clang.a
#
# Output: ./gmacs (Mach-O arm64). GMACS Version comes from gmacsbase.TPL:100.
# ============================================================================

set -e

ADMB_LIB_DIR=/usr/local/admb/lib
CONTRIB_SUFFIXED="$ADMB_LIB_DIR/libadmb-contrib-arm64-macos-clang.a"

AUX_NAMES=(tailcompression.cpp nloglike.cpp spr.cpp multinomial.cpp \
           robust_multi.cpp equilibrium.cpp dirichlet.cpp)

# --------------------------------------------------------------------------
# 1. Preflight
# --------------------------------------------------------------------------
if [ ! -e "$CONTRIB_SUFFIXED" ]; then
  echo "ERROR: $CONTRIB_SUFFIXED not found."
  echo "       Without it admb omits -I/usr/local/admb/include/contrib and the"
  echo "       dnorm() overloads in statsLib.h go undeclared. See header above."
  exit 1
fi

mkdir -p build src_mac
rm -f gmacs admb.log

# --------------------------------------------------------------------------
# 2. Stage auxiliary sources, concatenate templates, build
# --------------------------------------------------------------------------
AUX_SRC=()
for f in "${AUX_NAMES[@]}"; do
  cp -f "src/$f" "src_mac/$f"
  AUX_SRC+=("src_mac/$f")
done

# -g matches the flags make_win.bat used for the reference Windows exe.
cat gmacsbase.TPL personal.TPL > gmacs.tpl

admb -g gmacs.tpl "${AUX_SRC[@]}" || { echo "ADMB compilation failed"; exit 1; }

if [ ! -f gmacs ]; then
  echo "ERROR: gmacs binary not found after a successful-looking admb run."
  exit 1
fi

# --------------------------------------------------------------------------
# 3. Distribute and clean up
# --------------------------------------------------------------------------
for d in AIGKC BBRKC SMBKC NSRKC snow_crab snow_crabV2 BBRKCV2 Tanner; do
  [ -d "build/$d" ] && cp gmacs "build/$d/"
done

rm -f *.obj(N) *.o(N) *.htp(N)
rm -rf src_mac

echo
echo "Built: $(pwd)/gmacs"
grep -m1 "GMACS Version" gmacsbase.TPL
