#!/bin/sh
#
# Build and package builds for linux

SCONS_ARGS="release=1"

if [ ! -f distrib-linux.sh ] ; then
  echo You should only run this script from the ohrrpgce directory.
  exit 1
fi

echo Erasing old distribution files
mkdir -p distrib
rm -f distrib/ohrrpgce-linux-*.tar.bz2
rm -f distrib/ohrrpgce-player-linux-*.zip
rm -f distrib/*.deb

package_for_arch() {
  ARCH=$1

  echo
  echo "Building $ARCH binaries"
  # lto=1 to reduce unlump/relump size
  scons $SCONS_ARGS arch=$ARCH lto=1 unlump relump || return 1
  scons $SCONS_ARGS arch=$ARCH game custom hspeak || return 1

  echo "Packaging $ARCH binary distribution of CUSTOM"
  ./ohrpackage.py linux full distrib/ohrrpgce-linux-{TODAY}-{BRANCH}-$ARCH.tar.bz2 || return 1

  echo "Prepare minimal $ARCH player zip"
  ./ohrpackage.py linux player distrib/ohrrpgce-player-linux-bin-minimal-{TODAY}-{BRANCH}-$ARCH.zip || return 1
}

if [ -z "${OHR_SKIP_X86}" ] ; then
  package_for_arch x86 || exit 1
fi

if [ -z "${OHR_SKIP_X86_64}" ] ; then
  package_for_arch x86_64 || exit 1
  if which dpkg > /dev/null; then
    echo
    echo "Building x86_64 Debian/Ubuntu packages"
    python linux/ohrrpgce.py distrib || exit 1
  fi
fi
