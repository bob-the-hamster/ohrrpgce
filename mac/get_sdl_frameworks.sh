#!/bin/sh

cd $(dirname $0)
mkdir -p "mac_sdl_framework_downloads"
cd "mac_sdl_framework_downloads"

if [ ! -e "SDL_mixer-1.2.12.dmg" ] ; then
  curl -k -O "https://www.libsdl.org/projects/SDL_mixer/release/SDL_mixer-1.2.12.dmg"
fi

if [ ! -e "SDL2_mixer-2.6.3.dmg" ] ; then
  curl -k -O "https://www.libsdl.org/projects/SDL_mixer/release/SDL2_mixer-2.6.3.dmg"
fi

if [ ! -e "SDL-1.2.15.dmg" ] ; then
  curl -k -O "https://www.libsdl.org/release/SDL-1.2.15.dmg"
fi

if [ ! -e "SDL2-2.28.3.dmg" ] ; then
  curl -k -O "https://www.libsdl.org/release/SDL2-2.28.3.dmg"
fi
