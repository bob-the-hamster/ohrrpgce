#!/bin/sh
#
# Build and package builds for linux

# Number of threads to use
NJOBS=-j2

if [ ! -f distrib.sh ] ; then
  echo You should only run this script from the ohrrpgce directory.
  exit 1
fi

echo "Building relump"
scons $NJOBS debug=0 relump || exit 1

echo "Lumping Vikings of Midgard"
if [ -f vikings.rpg ] ; then
  rm vikings.rpg
fi
./relump vikings/vikings.rpgdir ./vikings.rpg || exit 1

echo "Downloading import media"
if [ -f import.zip ] ; then
  rm import.zip
fi
if [ -d "import/Music" ] ; then
  rm -Rf "import/Music"
fi
if [ -d "import/Sound Effects" ] ; then
  rm -Rf "import/Sound Effects"
fi
wget -q http://rpg.hamsterrepublic.com/ohrimport/import.zip || exit 1
unzip -q -d import/ import.zip || exit 1
rm import.zip

echo "Erasing contents of temporary directory"
mkdir -p tmp
mkdir -p distrib
rm -Rf tmp/*

echo Erasing old distribution files
rm -f distrib/ohrrpgce-linux-*.tar.bz2
rm -f distrib/ohrrpgce-player-*.zip
rm -f distrib/*.deb

package_for_arch() {
  ARCH=$1

  echo "Building $ARCH binaries"
  scons $NJOBS debug=0 arch=$ARCH game custom hspeak unlump relump || return 1

  echo "Packaging $ARCH binary distribution of CUSTOM"

  echo "  Including binaries"
  cp -p ohrrpgce-game tmp &&
  cp -p ohrrpgce-custom tmp &&
  cp -p unlump tmp &&
  cp -p relump tmp || return 1

  echo "  Including hspeak"
  cp -p hspeak tmp || return 1

  echo "  Including support files"
  cp -p plotscr.hsd tmp &&
  cp -p scancode.hsi tmp || return 1

  echo "  Including readmes"
  cp -p README-game.txt tmp &&
  cp -p README-custom.txt tmp &&
  cp -p IMPORTANT-nightly.txt tmp &&
  cp -p LICENSE.txt tmp &&
  cp -p LICENSE-binary.txt tmp &&
  cp -p whatsnew.txt tmp || return 1

  echo "  Including Vikings of Midgard"
  cp -p vikings.rpg tmp &&
  cp -pr "vikings/Vikings script files" tmp &&
  cp -p "vikings/README-vikings.txt" tmp || return 1

  echo "  Including data files"
  mkdir -p tmp/data &&
  cp -pr data/* tmp/data || return 1

  echo "  Including import"
  mkdir -p tmp/import &&
  cp -pr import/* tmp/import || return 1

  echo "  Including docs"
  mkdir -p tmp/docs &&
  cp -p docs/*.html tmp/docs &&
  cp -p docs/plotdict.xml tmp/docs &&
  cp -p docs/htmlplot.xsl tmp/docs &&
  cp -p docs/more-docs.txt tmp/docs || return 1

  echo "  Including help files"
  cp -pr ohrhelp tmp || return 1

  echo "tarring and bzip2ing $ARCH distribution"
  TODAY=`date "+%Y-%m-%d"`
  CODE=`cat codename.txt | grep -v "^#" | head -1 | tr -d "\r"`
  mv tmp ohrrpgce
  tar -jcf distrib/ohrrpgce-linux-$TODAY-$CODE-$ARCH.tar.bz2 ./ohrrpgce --exclude .svn || return 1
  mv ohrrpgce tmp

  echo "Erasing contents of temporary directory"
  rm -Rf tmp/*

  echo "Prepare minimal $ARCH player zip"
  cp ohrrpgce-game tmp/
  strip tmp/ohrrpgce-game
  zip -j distrib/ohrrpgce-player-linux-bin-minimal-$TODAY-$CODE-$ARCH.zip tmp/ohrrpgce-game LICENSE-binary.txt README-linux-bin-minimal.txt
  rm tmp/ohrrpgce-game
}

package_for_arch x86 &&
if which dpkg > /dev/null; then
  echo "Building x86 Debian/Ubuntu packages"
  cd linux
  if [ -f *.deb ] ; then
    rm *.deb
  fi
  ./all.sh || exit 1
  cd ..
  mv linux/*.deb distrib
fi

package_for_arch x86_64
