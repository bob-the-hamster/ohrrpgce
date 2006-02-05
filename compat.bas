'OHRRPGCE GAME - Compatibility functions, FreeBasic version
'(C) Copyright 1997-2005 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
option explicit

#include compat.bi
#include allmodex.bi
#include fontdata.bi
#include gfx.bi

'Can do this in FB but not in QB - need another solution
common shared workingdir$, version$, game$

dim shared seg as integer ptr
'bit of a waste, just stores the rpg name from the command line
dim shared storecmd as string

DECLARE SUB fatalerror (e$)
DECLARE FUNCTION small% (n1%, n2%)

SUB dummyclear(arg1%,arg2%,arg3%) 'dummy sub for compatibility
END SUB

SUB getdefaultfont(font() as integer)
	dim i as integer
	
	for i = 0 to 1023
		font(i) = font_data(i)
	next
END SUB

SUB xbload (f$, array(), e$)

	IF isfile(f$) THEN
		DIM ff%, byt as UByte, seg AS Short, offset AS Short, length AS Short
		dim ilength as integer
		dim i as integer

		ff = FreeFile
		OPEN f$ FOR BINARY AS #ff
		GET #ff,, byt 'Magic number, always 253
		IF byt <> 253 THEN fatalerror e$
		GET #ff,, seg 'Segment, no use anymore
		GET #ff,, offset 'Offset into the array, not used now
		GET #ff,, length 'Length
		'length is in bytes, so divide by 2, and subtract 1 because 0-based
		ilength = (length / 2) - 1
		
		dim buf(ilength) as short
		
		GET #ff,, buf()
		CLOSE #ff

		for i = 0 to small(ilength, ubound(array))
			array(i) = buf(i)	
		next i
		
		ELSE
		fatalerror e$
	END IF

END SUB

SUB xbsave (f$, array%(), bsize%)

	DIM ff%, byt as UByte, seg AS uShort, offset AS Short, length AS Short
	dim ilength as integer
	dim i as integer

	seg = &h9999
	offset = 0
	ilength = (bsize \ 2) - 1
	length = bsize	'bsize is in bytes
	byt = 253
	
	'copy array to shorts
	DIM buf(ilength) as short
	for i = 0 to small(ilength, ubound(array))
		buf(i) = array(i)
	next		
	
	ff = FreeFile
	OPEN f$ FOR BINARY AS #ff
	PUT #ff, , byt				'Magic number
	PUT #ff, , seg				'segment - obsolete
	PUT #ff, , offset			'offset - obsolete
	PUT #ff, , length			'size in bytes
	
	PUT #ff,, buf()
	CLOSE #ff
		
END SUB

SUB crashexplain()
	PRINT "Please report this exact error message to ohrrpgce@HamsterRepublic.com"
	PRINT "Be sure to describe in detail what you were doing when it happened"
	PRINT
	PRINT version$
	PRINT "Memory Info:"; FRE(0)
	PRINT "Executable: "; exepath + command(0)
'	PRINT "RPG file: "; sourcerpg$
END SUB

'replacements for def seg and peek, use seg shared ptr 
'assumes def seg will always be used to point to an integer and
'that integers are only holding 2 bytes of data
sub defseg(byref var as integer)
	seg = @var
end sub

function xpeek(byval idx as integer) as integer
	dim as ubyte bval
	dim as integer hilow
	
	hilow = idx mod 2
	idx = idx \ 2
	
	if hilow = 0 then
		bval = seg[idx] and &hff
	else
		bval = (seg[idx] and &hff00) shr 8
	end if
	xpeek = bval
end function

sub xpoke(byval idx as integer, byval v as integer)
	dim as integer bval
	dim as integer hilow
	dim as integer newval
	
	hilow = idx mod 2
	idx = idx \ 2
	
	bval = v and &hff
	if hilow = 0 then
		newval = seg[idx] and &hff00
		seg[idx] = newval or bval
	else
		newval = seg[idx] and &hff
		seg[idx] = newval or (bval shl 8)
	end if
end sub

sub togglewindowed()
	gfx_togglewindowed
end sub

sub storecommandline
'a thinly veiled excuse to get some commandline stuff into FB
	dim i as integer = 1
	dim temp as string
	
	while command(i) <> ""
		temp = left$(command(i), 1)
		'/ should not be a flag under linux
		if temp = "-" or temp = "/" then
			'option
			temp = mid$(command(i), 2)
			if temp = "w" or temp = "windowed" then
				gfx_setwindowed(1)
			elseif temp = "f" or temp = "fullscreen" then
				gfx_setwindowed(0)
			end if
		else
			'only keep one non-flag argument, hopefully the file
			storecmd = command(i)
		end if
		i = i + 1
	wend
end sub

function getcommandline() as string
	getcommandline = storecmd
end function

FUNCTION canplay (file$)
	'dummy, you should be able to play anything passed in (unless this sub finds uses elsewhere)
	canplay = 1
END FUNCTION

SUB playsongnum (songnum%)
	DIM as string songbase, songfile, numtext
	
	numtext = LTRIM$(STR$(songnum))
	songbase = workingdir$ + "\song" + numtext
	songfile = ""
	if isfile(songbase + ".mid") then
		'is there a midi?
		songfile = songbase + ".mid"
	else
		'no, get bam name
		IF isfile(songbase + ".bam") THEN
			songfile = songbase + ".bam"
		ELSE
			IF isfile(game$ + "." + numtext) THEN 
				songfile = game$ + "." + numtext
			end if
		END IF
	end if
	IF songfile <> "" THEN loadsong songfile
END SUB
