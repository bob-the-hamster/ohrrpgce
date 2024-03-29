'OHRRPGCE RELUMP - RPG File relumping utility
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
'
' Compile with 'scons relump'

#include "config.bi"
#include "util.bi"
#include "const.bi"
#include "lumpfile.bi"
#include "common_base.bi"

DIM olddir as string = curdir

IF COMMAND = "" THEN
 PRINT "O.H.R.RPG.C.E. lumping utility"
 PRINT ""
 PRINT "syntax:"
 PRINT " relump folder [filename]"
 PRINT ""
 PRINT "A utility to package the contents of a folder into an OHRRPGCE"
 PRINT "lumpfile, such as an .rpg or .hs file"
 PRINT ""
 PRINT "You can drag-and-drop a rpgdir folder onto this program"
 PRINT "to relump it."
 PRINT ""
 PRINT "[Press a Key]"
 readkey
 fatalerror ""
END IF


DIM src as string = COMMAND(1)
DIM dest as string = COMMAND(2)

src = trim_trailing_slashes(src)

IF NOT isdir(src) THEN
  IF isfile(src) THEN fatalerror src + "' is a file, not a folder"
  fatalerror "source folder `" + src + "' was not found"
END IF

IF dest = "" THEN
 IF ends_with(src, ".rpgdir") THEN
  dest = trimextension(src) + ".rpg"
 ELSE
  fatalerror "please specify an output filename"
 END IF
END IF

PRINT "From " + src + " to " + dest

IF isdir(dest) THEN
 fatalerror "destination file " + dest + " already exists as a folder."
ELSEIF isfile(dest) THEN
 PRINT "destination file " + dest + " already exists. Replace it? (y/n)"
 DIM w as string
 w = readkey
 IF w <> "Y" AND w <> "y" THEN SYSTEM
END IF

'--build the list of files to lump
REDIM filelist() as string
findfiles src, ALLFILES, fileTypefile, NO, filelist()
fixlumporder filelist()
'---relump data into lumpfile package---
DIM errmsg as string = lumpfiles(filelist(), dest, src + SLASH)
IF LEN(errmsg) THEN
 PRINT "FAILED to relump: " & errmsg
 SYSTEM 1
END IF
