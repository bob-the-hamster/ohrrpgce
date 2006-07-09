'' FBOHR COMPATIBILITY FUNCTIONS
'' GPL and stuff. See LICENSE.txt.
'
#define DEMACRO
#include "compat.bi"
#include "allmodex.bi"
#include "gfx.bi"
#include "music.bi"
#include "bitmap.bi"

option explicit

#define NULL 0
'a few key constants borrowed from fbgfx.bi, they should all be defined
'in a separate .bi file really, but this will do for now
#define SC_CONTROL		&h1D
#define SC_LSHIFT		&h2A
#define SC_RSHIFT		&h36
#define SC_ALT			&h38

type ohrsprite
	w as integer
	h as integer
	image as ubyte ptr
	mask as ubyte ptr
end type

type node 	'only used for floodfill
	x as integer
	y as integer
	nextnode as node ptr
end type

'add page? or assume workpage? (all pages for clip?)
declare SUB drawspritex (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, byval scale as integer=1, BYVAL trans as integer = -1)
declare sub setclip(l as integer=0, t as integer=0, r as integer=319, b as integer=199)
declare sub drawohr(byref spr as ohrsprite, x as integer, y as integer, scale as integer=1)
declare sub grabrect(page as integer, x as integer, y as integer, w as integer, h as integer, ibuf as ubyte ptr)
declare function nearcolor(pal() as integer, byval red as ubyte, byval green as ubyte, byval blue as ubyte) as ubyte
declare SUB loadbmp4(byval bf as integer, byval iw as integer, byval ih as integer, byval maxw as integer, byval maxh as integer, byval sbase as ubyte ptr)
declare SUB loadbmprle4(byval bf as integer, byval iw as integer, byval ih as integer, byval maxw as integer, byval maxh as integer, byval sbase as ubyte ptr)

'used for map and pass
DECLARE SUB setblock (BYVAL x as integer, BYVAL y as integer, BYVAL v as integer, BYVAL mp as integer ptr)
DECLARE FUNCTION readblock (BYVAL x as integer, BYVAL y as integer, BYVAL mp as integer ptr) as integer

declare function matchmask(match as string, mask as string) as integer
declare function calcblock(byval x as integer, byval y as integer, byval t as integer) as integer

'slight hackery to get more versatile read function
declare function fget alias "fb_FileGet" ( byval fnum as integer, byval pos as integer = 0, byval dst as any ptr, byval bytes as uinteger ) as integer
declare function fput alias "fb_FilePut" ( byval fnum as integer, byval pos as integer = 0, byval src as any ptr, byval bytes as uinteger ) as integer

'extern
declare sub debug(s$)
declare sub fatalerror(e$)

declare sub pollingthread()

dim shared path as string
dim shared vispage as integer
dim shared wrkpage as integer
dim shared spage(0 to 3) as ubyte ptr

dim shared bptr as integer ptr	' buffer
dim shared bsize as integer
dim shared bpage as integer

dim shared bordertile as integer
dim shared mptr as integer ptr	' map ptr
dim shared pptr as integer ptr	' pass ptr
dim shared maptop as integer
dim shared maplines as integer
dim shared map_x as integer
dim shared map_y as integer

dim shared anim1 as integer
dim shared anim2 as integer

dim shared waittime as double
dim shared waitset as integer

dim shared keybd(0 to 255) as integer  'keyval array
dim shared keybdstate(127) as integer  '"real"time array
dim shared keysteps(127) as integer

dim shared keybdmutex as integer  'controls access to keybdstate(), mouseflags and mouselastflags
dim shared keybdthread as integer   'id of the polling thread
dim shared endpollthread as integer  'signal the polling thread to quit

dim shared stacktop as ubyte ptr
dim shared stackptr as ubyte ptr
dim shared stacksize as integer

dim shared mouse_xmin as integer
dim shared mouse_xmax as integer
dim shared mouse_ymin as integer
dim shared mouse_ymax as integer
dim shared mouseflags as integer
dim shared mouselastflags as integer

dim shared textfg as integer
dim shared textbg as integer

dim shared fontdata as ubyte ptr

dim shared as integer clipl, clipt, clipr, clipb

dim shared intpal(0 to 255) as integer	'current palette

'global sprite buffer, to allow reuse without allocate/deallocate
dim shared tbuf as ohrsprite ptr = null

sub setmodex()
	dim i as integer

	'initialise software gfx
	for i = 0 to 3
		spage(i) = callocate(320 * 200)
	next
	setclip

	gfx_init
	vispage = 0
	wrkpage = 0

	'init vars
	stacksize = -1
	for i = 0 to 127
		keybd(i) = 0
		keybdstate(i) = 0
 		keysteps(i) = -1
	next
	endpollthread = 0
	mouselastflags = 0
	mouseflags = 0

	keybdmutex = mutexcreate
	keybdthread = threadcreate (@pollingthread)

	io_init
	mouserect(0,319,0,199)
end sub

sub restoremode()
	dim i as integer

	gfx_close
	'clean up io stuff
	endpollthread = 1
	threadwait keybdthread
	mutexdestroy keybdmutex

	'clear up software gfx
	for i = 0 to 3
		deallocate(spage(i))
	next

	'clean up tile buffer
	if tbuf <> null then
		'mask should always be null, but no harm in future-proofing
		if tbuf->mask <> null then	deallocate tbuf->mask
		if tbuf->image <> null then	deallocate tbuf->image
		deallocate tbuf
		tbuf = null
	end if
	releasestack
end sub

SUB copypage (BYVAL page1 as integer, BYVAL page2 as integer)
	dim i as integer

	'inefficient, could be improved with memcpy
	for i = 0 to (320 * 200) - 1
		spage(page2)[i] = spage(page1)[i]
	next
	if page2 = vispage then
		setvispage(vispage)
	end if
end sub

SUB clearpage (BYVAL page as integer)
	dim i as integer

	'inefficient, could be improved with memcpy
	for i = 0 to (320 * 200) - 1
		spage(page)[i] = 0
	next
	wrkpage = page
end SUB

SUB setvispage (BYVAL page as integer)
	gfx_showpage(spage(page))

	vispage = page
end SUB

sub setpal(pal() as integer)
	dim p as integer
	dim i as integer

	p = 0 ' is it actually base 0?
	for i = 0 to 255
		intpal(i) = pal(p) or (pal(p+1) shl 8) or (pal(p+2) shl 16)
		p = p + 3
	next i

	gfx_setpal(intpal())
end sub

SUB fadeto (palbuff() as integer, BYVAL red as integer, BYVAL green as integer, BYVAL blue as integer)
	dim i as integer
	dim j as integer
	dim hue as integer
	dim count as integer = 0

	'palette get using pal 'intpal holds current palette

	'max of 64-1 steps
	for i = 0 to 62
		for j = 0 to 255
			'red
			hue = intpal(j) and &hff
			intpal(j) = intpal(j) and &hffff00 'clear
			if hue > red then
				hue = hue - 1
			end if
			if hue < red then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or hue
			'green
			hue = (intpal(j) and &hff00) shr 8
			intpal(j) = intpal(j) and &hff00ff 'clear
			if hue > green then
				hue = hue - 1
			end if
			if hue < green then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or (hue shl 8)
			'blue
			hue = (intpal(j) and &hff0000) shr 16
			intpal(j) = intpal(j) and &h00ffff 'clear
			if hue > blue then
				hue = hue - 1
			end if
			if hue < blue then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or (hue shl 16)
		next
		if count = 1 then
			gfx_setpal(intpal())
			count = 0
		end if
		count = count + 1
		sleep 10 'how long?
	next

	'I don't think the palette was getting set on the final pass
	'so add this little check
	if count = 1 then
		gfx_setpal(intpal())
	end if
end SUB

SUB fadetopal (pal() as integer, palbuff() as integer)
	dim i as integer
	dim j as integer
	dim hue as integer
	dim p as integer	'index to passed palette, which has separate r, g, b
	dim count as integer = 0

	'max of 64-1 steps
	for i = 0 to 62
		p = 0
		for j = 0 to 255
			'red
			hue = intpal(j) and &hff
			intpal(j) = intpal(j) and &hffff00 'clear
			if hue > pal(p) then
				hue = hue - 1
			end if
			if hue < pal(p) then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or hue
			p = p + 1
			'green
			hue = (intpal(j) and &hff00) shr 8
			intpal(j) = intpal(j) and &hff00ff 'clear
			if hue > pal(p) then
				hue = hue - 1
			end if
			if hue < pal(p) then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or (hue shl 8)
			p = p + 1
			'blue
			hue = (intpal(j) and &hff0000) shr 16
			intpal(j) = intpal(j) and &h00ffff 'clear
			if hue > pal(p) then
				hue = hue - 1
			end if
			if hue < pal(p) then
				hue = hue + 1
			end if
			intpal(j) = intpal(j) or (hue shl 16)
			p = p + 1
		next
		if count = 1 then
			gfx_setpal(intpal())
			count = 0
		end if
		count = count + 1
		sleep 10 'how long?
	next

	if count = 1 then
		gfx_setpal(intpal())
	end if
end SUB

SUB setmapdata (array() as integer, pas() as integer, BYVAL t as integer, BYVAL b as integer)
'I think this is a setup routine like setpicstuf
't and b are top and bottom margins
	map_x = array(0)
	map_y = array(1)
	mptr = @array(2)
	pptr = @pas(2)
	maptop = t
	maplines = 200 - t - b
end SUB

SUB setmapblock (BYVAL x as integer, BYVAL y as integer, BYVAL v as integer)
	setblock(x, y, v, mptr)
end sub

FUNCTION readmapblock (BYVAL x as integer, BYVAL y as integer) as integer
	readmapblock = readblock(x, y, mptr)
end function

SUB setpassblock (BYVAL x as integer, BYVAL y as integer, BYVAL v as integer)
	setblock(x, y, v, pptr)
END SUB

FUNCTION readpassblock (BYVAL x as integer, BYVAL y as integer)
	readpassblock = readblock(x, y, pptr)
END FUNCTION

SUB setblock (BYVAL x as integer, BYVAL y as integer, BYVAL v as integer, BYVAL mp as integer ptr)
	dim index as integer
	dim hilow as integer

	index = (map_x * y) + x	'raw byte offset
	hilow = index mod 2		'which byte in word
	index = index shr 1 	'divide by 2

	if hilow > 0 then
		'delete original value
		mp[index] = mp[index] and &hff
		'set new value
		mp[index] = mp[index] or ((v and &hff) shl 8)
	else
		'delete original value
		mp[index] = mp[index] and &hff00
		'set new value
		mp[index] = mp[index] or (v and &hff)
	end if

end SUB

FUNCTION readblock (BYVAL x as integer, BYVAL y as integer, BYVAL mp as integer ptr) as integer
	dim block as integer
	dim index as integer
	dim hilow as integer

	index = (map_x * y) + x	'raw byte offset
	hilow = index mod 2		'which byte in word
	index = index shr 1 	'divide by 2

	if hilow > 0 then
		block = (mp[index] and &hff00) shr 8
	else
		block = mp[index] and &hff
	end if

	readblock = block
end FUNCTION

SUB drawmap (BYVAL x, BYVAL y as integer, BYVAL t as integer, BYVAL p as integer)
	dim sptr as ubyte ptr
	dim plane as integer

	dim ypos as integer
	dim xpos as integer
	dim xstart as integer
	dim yoff as integer
	dim xoff as integer
	dim calc as integer
	dim ty as integer
	dim tx as integer
	dim tpx as integer
	dim tpy as integer
	dim todraw as integer
	dim tpage as integer
	'this is static to allow optimised reuse
	static lasttile as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	'set viewport to allow for top and bottom bars
	setclip(0, maptop, 319, maptop + maplines - 1)

	'copied from the asm
	ypos = y \ 20
	calc = y mod 20
	if calc < 0 then  	'adjust for negative coords
		calc = calc + 20
		ypos = ypos - 1
	end if
	yoff = -calc

	xpos = x \ 20
	calc = x mod 20
	if calc < 0 then
		calc = calc + 20
		xpos = xpos - 1
	end if
	xoff = -calc
	xstart = xpos

	if tbuf = null then
		'create tile buffer
		tbuf = callocate(sizeof(ohrsprite))
		tbuf->w = 20
		tbuf->h = 20
		tbuf->mask = 0
		tbuf->image = callocate(20 * 20)
	end if
	'force it to be cleared for each redraw
	lasttile = -1

	tpage = 3

	'screen is 16 * 10 tiles, which means we need to draw 17x11
	'to allow for partial tiles
	ty = yoff
	while ty < 200
		tx = xoff
		xpos = xstart
		while tx < 320
			todraw = calcblock(xpos, ypos, t)
			if (todraw >= 160) then
				if (todraw > 207) then
					todraw = todraw - 208 + anim2
				else
					todraw = todraw - 160 + anim1
				end if
			end if

			'get the tile
			if (todraw >= 0) then
				if todraw <> lasttile then
					tpx = (todraw mod 16) * 20
					tpy = (todraw \ 16) * 20
					'page 3 is the tileset page (#define??)
					'get and put don't take a page argument, so I'll
					'have to toggle the work page, not sure that's efficient
					grabrect(3, tpx, tpy, 20, 20, tbuf->image)
				end if

				'draw it on the map
				drawohr(*tbuf, tx, ty)
				lasttile = todraw
			end if

			tx = tx + 20
			xpos = xpos + 1
		wend
		ty = ty + 20
		ypos = ypos + 1
	wend

	'reset viewport
	setclip
end SUB

SUB setanim (BYVAL cycle1 as integer, BYVAL cycle2 as integer)
	anim1 = cycle1
	anim2 = cycle2
end SUB

SUB setoutside (BYVAL defaulttile as integer)
	bordertile = defaulttile
end SUB

SUB drawsprite (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans = -1)
'draw sprite from pic(picoff) onto page using pal() starting at po
	drawspritex(pic(), picoff, pal(), po, x, y, page, 1, trans)
end sub

SUB bigsprite (pic(), pal(), BYVAL p, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
	drawspritex(pic(), 0, pal(), p, x, y, page, 2, trans)
END SUB

SUB hugesprite (pic(), pal(), BYVAL p, BYVAL x, BYVAL y, BYVAL page, BYVAL trans = -1)
	drawspritex(pic(), 0, pal(), p, x, y, page, 4, trans)
END SUB

SUB drawspritex (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, byval scale as integer, byval trans as integer = -1)
'draw sprite scaled, used for drawsprite(x1), bigsprite(x2) and hugesprite(x4)
	dim sw as integer
	dim sh as integer
	dim hspr as ohrsprite
	dim dspr as ubyte ptr
	dim hmsk as ubyte ptr
	dim dmsk as ubyte ptr
	dim nib as integer
	dim i as integer
	dim spix as integer
	dim pix as integer
	dim mask as integer
	dim row as integer
	
	if wrkpage <> page then
		wrkpage = page
	end if

	sw = pic(picoff)
	sh = pic(picoff+1)
	picoff = picoff + 2

	'create sprite
	hspr.w = sw
	hspr.h = sh
	hspr.image = allocate(sw * sh)
	hspr.mask = allocate(sw * sh)
	dspr = hspr.image
	dmsk = hspr.mask

	'now do the pixels
	'pixels are in columns, so this might not be the best way to do it
	'maybe just drawing straight to the screen would be easier
	nib = 0
	row = 0
	for i = 0 to (sw * sh) - 1
		select case as const nib 			' 2 bytes = 4 nibbles in each int
			case 0
				spix = (pic(picoff) and &hf000) shr 12
			case 1
				spix = (pic(picoff) and &h0f00) shr 8
			case 2
				spix = (pic(picoff) and &hf0) shr 4
			case 3
				spix = pic(picoff) and &h0f
				picoff = picoff + 1
		end select
		if spix = 0 and trans then
			pix = 0					' transparent (hope 0 is never valid)
			mask = &hff
		else
			'palettes are interleaved like everything else
			pix = pal(int((po + spix) / 2))	' get color from palette
			if (po + spix) mod 2 = 1 then
				pix = (pix and &hff00) shr 8
			else
				pix = pix and &hff
			end if
			mask = 0
		end if
		*dspr = pix				' set image pixel
		dspr = dspr + sw
		*dmsk = mask
		dmsk = dmsk + sw
		row = row + 1
		if (row >= sh) then 	'ugh
			dspr = dspr - (sw * sh)
			dspr = dspr + 1
			dmsk = dmsk - (sw * sh)
			dmsk = dmsk + 1
			row = 0
		end if
		nib = nib + 1
		nib = nib and 3	'= mod 4, but possibly more efficient
	next
	'now draw the image
	drawohr(hspr,x,y, scale)
	
	deallocate(hspr.image)
	deallocate(hspr.mask)
end SUB

SUB wardsprite (pic() as integer, BYVAL picoff as integer, pal() as integer, BYVAL po as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer, BYVAL trans = -1)
'I think this just draws the sprite mirrored
'are the coords top left or top right, though?
	dim sw as integer
	dim sh as integer
	dim hspr as ohrsprite
	dim dspr as ubyte ptr
	dim hmsk as ubyte ptr
	dim dmsk as ubyte ptr
	dim nib as integer
	dim i as integer
	dim spix as integer
	dim pix as integer
	dim mask as integer
	dim row as integer

	if wrkpage <> page then
		screenset page
		wrkpage = page
	end if

	sw = pic(picoff)
	sh = pic(picoff+1)
	picoff = picoff + 2

	'create sprite
	hspr.w = sw
	hspr.h = sh
	hspr.image = allocate(sw * sh)
	hspr.mask = allocate(sw * sh)
	dspr = hspr.image
	dmsk = hspr.mask
	dspr = dspr + sw - 1 'jump to last column
	dmsk = dmsk + sw - 1 'jump to last column

	'now do the pixels
	'pixels are in columns, so this might not be the best way to do it
	'maybe just drawing straight to the screen would be easier
	nib = 0
	row = 0
	for i = 0 to (sw * sh) - 1
		select case nib			' 2 bytes = 4 nibbles in each int
			case 0
				spix = (pic(picoff) and &hf000) shr 12
			case 1
				spix = (pic(picoff) and &h0f00) shr 8
			case 2
				spix = (pic(picoff) and &hf0) shr 4
			case 3
				spix = pic(picoff) and &h0f
				picoff = picoff + 1
		end select
		if spix = 0 and trans then
			pix = 0					' transparent (hope 0 is never valid)
			mask = &hff
		else
			'palettes are interleaved like everything else
			pix = pal((po + spix) \ 2)	' get color from palette
			if (po + spix) mod 2 = 1 then
				pix = (pix and &hff00) shr 8
			else
				pix = pix and &hff
			end if
			mask = 0
		end if
		*dspr = pix				' set image pixel
		dspr = dspr + sw
		*dmsk = mask
		dmsk = dmsk + sw
		row = row + 1
		if (row >= sh) then 	'ugh
			dspr = dspr - (sw * sh)
			dspr = dspr - 1		' right to left for wardsprite
			dmsk = dmsk - (sw * sh)
			dmsk = dmsk - 1		' right to left
			row = 0
		end if
		nib = nib + 1
		nib = nib and 3	'= mod 4, but possibly more efficient
	next

	'now draw the image
	drawohr(hspr,x,y)
	deallocate(hspr.image)
	deallocate(hspr.mask)
end SUB

SUB stosprite (pic() as integer, BYVAL picoff as integer, BYVAL x as integer, BYVAL y as integer, BYVAL page as integer)
'I'm guessing this is the opposite of loadsprite, ie store raw sprite data in screen p
'starting at x, y. The offsets here do actually seem to be in words, not bytes.
	dim i as integer
	dim p as integer
	dim toggle as integer
	dim sbytes as integer
	dim sptr as ubyte ptr
	dim h as integer
	dim w as integer

	if wrkpage <> page then
		wrkpage = page
	end if

	p = picoff
	h = pic(p)
	w = pic(p + 1)
	p = p + 2
	sbytes = ((w * h) + 1) \ 2 	'only 4 bits per pixel

	sptr = spage(page)
	sptr = sptr + (320 * y) + x

	'copy to passed int buffer, with 2 bytes per int as usual
	toggle = 0
	for i = 0 to sbytes - 1
		if toggle = 0 then
			*sptr = (pic(p) and &hff00) shr 8
			toggle = 1
		else
			*sptr = pic(p) and &hff
			toggle = 0
			p = p + 1
		end if
		sptr = sptr + 1
	next

end SUB

SUB loadsprite (pic() as integer, BYVAL picoff as integer, BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL page as integer)
'reads sprite from given page into pic(), starting at picoff
'I'm not really sure I have understood this right
	dim i as integer
	dim p as integer
	dim toggle as integer
	dim sbytes as integer
	dim sptr as ubyte ptr
	dim temp as integer

	if wrkpage <> page then
		wrkpage = page
	end if

	sbytes = ((w * h) + 1) \ 2 	'only 4 bits per pixel

	sptr = spage(page)
	sptr = sptr + (320 * y) + x

	'copy to passed int buffer, with 2 bytes per int as usual
	toggle = 0
	p = picoff
	pic(p) = w			'these are 4byte ints, not compat w. orig.
	pic(p+1) = h
	p = p + 2
	for i = 0 to sbytes - 1
		temp = *sptr
		if toggle = 0 then
			pic(p) = temp shl 8
			toggle = 1
		else
			pic(p) = pic(p) or temp
			toggle = 0
			p = p + 1
		end if
		sptr = sptr + 1
	next

end SUB

SUB getsprite (pic(), BYVAL picoff, BYVAL x, BYVAL y, BYVAL w, BYVAL h, BYVAL page)
'This seems to convert a normal graphic into a sprite, storing the result in pic() at picoff
	dim as ubyte ptr sbase, sptr
	dim nyb as integer = 0
	dim p as integer = 0
	dim as integer sw, sh

	'store width and height
	p = picoff
	pic(p) = w
	p += 1
	pic(p) = h
	p += 1

	'find start of image
	sbase = spage(page)
	sbase = sbase + (y * 320) + x
	'pixels are stored in columns for the sprites (argh)
	for sh = 0 to w - 1
		sptr = sbase
		for sw = 0 to h - 1
			select case nyb
				case 0
					pic(p) = (*sptr and &h0f) shl 12
				case 1
					pic(p) = pic(p) or ((*sptr and &h0f) shl 8)
				case 2
					pic(p) = pic(p) or ((*sptr and &h0f) shl 4)
				case 3
					pic(p) = pic(p) or (*sptr and &h0f)
					p += 1
			end select
			sptr += 320
			nyb += 1
			nyb = nyb and &h03
		next
		sbase = sbase + 1 'next col
	next

END SUB

SUB interruptx (intnum as integer,inreg AS RegType, outreg AS RegType) 'not required
end SUB

FUNCTION Keyseg () as integer	'not required
	keyseg = 0
end FUNCTION

FUNCTION keyoff () as integer	'not required
	keyoff = 0
end FUNCTION

FUNCTION keyval (BYVAL a as integer) as integer
	keyval = keybd(a)
end FUNCTION

FUNCTION getkey () as integer
	dim i as integer, key as integer
	key = 0

	setkeys
	do
		setkeys
		'keybd(0) may contain garbage (but in assembly, keyval(0) contains last key pressed)
		for i=1 to &h7f
			if keyval(i) > 1 then
				key = i
				exit do
			end if
		next
		sleep 50
	loop while key = 0

	getkey = key
end FUNCTION

SUB setkeys ()
'Quite nasty. Moved all this functionality from keyval() because this
'is where it seems to happen in the original.
'I have rewritten this to use steps (frames based on the 55ms DOS timer)
'rather than raw time. It makes the maths a bit simpler. The way the
'rest of the code is structured means we need to emulate the original
'functionality of clearing the event until a repeat fires. I do this
'by stalling for 3 steps on a new keypress and 1 step on a repeat.
'1 step means the event will fire once per step, but won't fire many
'times in one frame (which is a problem, setkeys() is often called
'more than once per frame, particularly when new screens are brought
'up). - sb 2006-01-27

'Actual key state goes in keybd array for retrieval via keyval().

'In the asm version, setkeys copies over the real key state array
'(which is built using an interrupt handler) to the state array used
'by keyval and then reduces new key presses to held keys, all of
'which now happens in the backend, which may rely on a polling thread 
'or keyboard event callback as needed. - tmc
	dim a as integer
	mutexlock keybdmutex
	for a = 0 to &h7f
		keybd(a) = keybdstate(a)
		if keysteps(a) > 0 then
			keysteps(a) -= 1
		end if
		keybdstate(a) = keybdstate(a) and 1
	next
	mutexunlock keybdmutex
end SUB

sub pollingthread
	dim as integer a, dummy, buttons

	while endpollthread = 0
		mutexlock keybdmutex

		io_updatekeys keybdstate()
		'set key state for every key
		'highest scancode in fbgfx.bi is &h79, no point overdoing it
		for a = 0 to &h7f
			if keybdstate(a) and 4 then
				'decide whether to fire a new key event, otherwise the keystate is preserved as 1
				if keysteps(a) <= 0 then
					if keysteps(a) = -1 then
						'this is a new keypress
						keysteps(a) = 7
					else
						keysteps(a) = 1
					end if
					keybdstate(a) = 3
				else
					keybdstate(a) = keybdstate(a) and 3 
				end if
			else
				keybdstate(a) = keybdstate(a) and 2 'no longer pressed, but was seen
				keysteps(a) = -1 '-1 means it's a new press next time
			end if
		next
		io_getmouse dummy, dummy, dummy, buttons
		mouseflags = mouseflags or (buttons and not mouselastflags)
		mouselastflags = buttons
		mutexunlock keybdmutex

		sleep 25
	wend
end sub

SUB putpixel (BYVAL x as integer, BYVAL y as integer, BYVAL c as integer, BYVAL p as integer)
	if wrkpage <> p then
		wrkpage = p
	end if

	'wrap if x is too high
	if x >= 320 then
		y = y + (x \ 320)
		x = x mod 320
	end if

	spage(p)[y*320 + x] = c

end SUB

FUNCTION readpixel (BYVAL x as integer, BYVAL y as integer, BYVAL p as integer) as integer
	if wrkpage <> p then
		wrkpage = p
	end if

	'wrap if x is too high
	if x >= 320 then
		y = y + (x \ 320)
		x = x mod 320
	end if

	readpixel = spage(p)[y*320 + x]
end FUNCTION

SUB hollowrectangle (BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
	dim sptr as ubyte ptr
	dim i as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	'clip
	if x + w > clipr then w = (clipr - x) + 1
	if y + h > clipb then h = (clipb - y) + 1
	if x < clipl then x = clipl
	if y < clipt then y = clipt

	'draw
	drawline(x,y,x+w-1,y,c,p)
	drawline(x,y+h-1,x+w-1,y+h-1,c,p)
	drawline(x,y,x,y+h-1,c,p)
	drawline(x+w-1,y,x+w-1,y+h-1,c,p)

end SUB

SUB rectangle (BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
	dim sptr as ubyte ptr
	dim i as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	'clip
	if x + w > clipr then w = (clipr - x) + 1
	if y + h > clipb then h = (clipb - y) + 1
	if x < clipl then x = clipl
	if y < clipt then y = clipt

	'draw
	sptr = spage(p) + (y*320) + x
	while h > 0
		for i = 0 to w-1
			sptr[i] = c
		next
		h -= 1
		sptr += 320
	wend
'	line (x, y) - (x+w-1, y+h-1), c, BF

end SUB

SUB fuzzyrect (BYVAL x as integer, BYVAL y as integer, BYVAL w as integer, BYVAL h as integer, BYVAL c as integer, BYVAL p as integer)
	dim sptr as ubyte ptr
	dim i as integer
	dim tog as integer 'pattern toggle

	if wrkpage <> p then
		wrkpage = p
	end if

	'clip
	if x + w > clipr then w = (clipr - x) + 1
	if y + h > clipb then h = (clipb - y) + 1
	if x < clipl then x = clipl
	if y < clipt then y = clipt

	'draw
	sptr = spage(p) + (y*320) + x
	while h > 0
		tog = h mod 2
		for i = 0 to w-1
			if tog = 0 then
				sptr[i] = c
				tog = 1
			else
				tog = 0
			end if
		next
		h -= 1
		sptr += 320
	wend

end SUB

SUB drawline (BYVAL x1 as integer, BYVAL y1 as integer, BYVAL x2 as integer, BYVAL y2 as integer, BYVAL c as integer, BYVAL p as integer)
'uses Bresenham's run-length slice algorithm
  	dim as integer xdiff,ydiff
  	dim as integer xdirection 	'direction of X travel from top to bottom point (1 or -1)
  	dim as integer minlength  	'minimum length of a line strip
  	dim as integer startLength 	'length of start strip (approx half 'minLength' to balance line)
  	dim as integer runLength  	'current run-length to be used (minLength or minLength+1)
  	dim as integer endLength   	'length of end of line strip (usually same as startLength)

  	dim as integer instep		'xdirection or 320 (inner loop)
	dim as integer outstep		'xdirection or 320 (outer loop)
	dim as integer shortaxis	'outer loop control
	dim as integer longaxis

  	dim as integer errorterm   	'when to draw an extra pixel
  	dim as integer erroradd 		'add to errorTerm for each strip drawn
  	dim as integer errorsub 		'subtract from errorterm when triggered

  	dim as integer i,j
  	dim sptr as ubyte ptr

'Macro to simplify code
#define DRAW_SLICE(a) for i=0 to a-1: *sptr = c: sptr += instep: next

	if wrkpage <> p then
		wrkpage = p
	end if

  	if (y1>y2) then
  		'swap ends, we only draw downwards
    	i=y1: y1=y2: y2=i
    	i=x1: x1=x2: x2=i
    end if

    'point to start
    sptr = spage(p) + y1*320 + x1

  	xdiff=x2-x1
  	ydiff=y2-y1

  	if (xDiff<0) then
  		'right to left
    	xdiff=-xdiff
    	xdirection=-1
  	else
    	xdirection=1
    end if

	'special case for vertical
  	if (xdiff = 0) then
  		instep = 320
  		DRAW_SLICE(ydiff+1)
    	exit sub
  	end if

	'and for horizontal
  	if (ydiff = 0) then
  		instep = xdirection
  		DRAW_SLICE(xdiff+1)
    	exit sub
  	end if

  	'and also for pure diagonals
  	if xdiff = ydiff then
  		instep = 320 + xdirection
  		DRAW_SLICE(ydiff+1)
    	exit sub
  	end if

	'now the actual bresenham
  	if xdiff > ydiff then
  		longaxis = xdiff
    	shortaxis = ydiff

    	instep = xdirection
    	outstep = 320
  	else
		'other way round, draw vertical slices
		longaxis = ydiff
		shortaxis = xdiff

		instep = 320
		outstep = xdirection
	end if

	'calculate stuff
    minlength = longaxis \ shortaxis
	erroradd = (longaxis mod shortaxis) * 2
	errorsub = shortaxis * 2

	'errorTerm must be initialized properly since first pixel
	'is about in the center of a strip ... not the start
	errorterm = (erroradd \ 2) - errorsub

	startLength = (minLength \ 2) + 1
	endLength = startlength 'half +1 of normal strip length

	'If the minimum strip length is even
	if (minLength and 1) <> 0 then
  		errorterm += shortaxis 'adjust errorTerm
	else
		'If the line had no remainder (x&yDiff divided evenly)
  		if erroradd = 0 then
			startLength -= 1 'leave out extra start pixel
		end if
	end if

	'draw the start strip
	DRAW_SLICE(startlength)
	sptr += outstep

	'draw the middle strips
	for j = 1 to shortaxis-1
      	runLength = minLength
  		errorTerm += erroradd

  		if errorTerm > 0 then
  			errorTerm -= errorsub
			runLength += 1
  		end if

  		DRAW_SLICE(runlength)
  		sptr += outstep
	next

	DRAW_SLICE(endlength)
end SUB

SUB paintat (BYVAL x as integer, BYVAL y as integer, BYVAL c as integer, BYVAL page as integer, buf() as integer, BYVAL max as integer)
'I'm not really sure what this does, I assume it's a floodfill, but then what are buf and max for?
'Uses putpixel and readpixel, so could probably be sped up with direct access. Also ignores clipping
'at the moment, which is possibly foolish
	dim tcol as integer
	dim queue as node ptr = null
	dim tail as node ptr = null
	dim as integer w, e		'x coords west and east
	dim i as integer
	dim tnode as node ptr = null

	if wrkpage <> page then
		wrkpage = page
	end if

	tcol = readpixel(x, y, page)	'get target colour

	'prevent infinite loop if you fill with the same colour
	if tcol = c then exit sub
	
	queue = allocate(sizeof(node))
	queue->x = x
	queue->y = y
	queue->nextnode = null
	tail = queue

	do
		if readpixel(queue->x, queue->y, page) = tcol then
			putpixel(queue->x, queue->y, c, page) 'change color
			w = queue->x
			e = queue->x
			'find western limit
			while w > 0 and readpixel(w-1, queue->y, page) = tcol
				w = w-1
				putpixel(w, queue->y, c, page) 'change
			wend
			'find eastern limit
			while e < 319 and readpixel(e+1, queue->y, page) = tcol
				e = e+1
				putpixel(e, queue->y, c, page)
			wend
			'add bordering nodes
			for i = w to e
				if queue->y > 0 then
					'north
					if readpixel(i, queue->y-1, page) = tcol then
						tail->nextnode = allocate(sizeof(node))
						tail = tail->nextnode
						tail->x = i
						tail->y = queue->y-1
						tail->nextnode = null
					end if
				end if
				if queue->y < 199 then
					'south
					if readpixel(i, queue->y+1, page) = tcol then
						tail->nextnode = allocate(sizeof(node))
						tail = tail->nextnode
						tail->x = i
						tail->y = queue->y+1
						tail->nextnode = null
					end if
				end if
			next
		end if

		'advance queue pointer, and delete behind us
		tnode = queue
		queue = queue->nextnode
		deallocate(tnode)

	loop while queue <> null
	'should only exit when queue has caught up with tail

end SUB

SUB storepage (fil$, BYVAL i as integer, BYVAL p as integer)
'saves a screen page to a file
	dim f as integer
	dim idx as integer
	dim bi as integer
	dim ub as ubyte
	dim sptr as ubyte ptr
	dim scrnbase as ubyte ptr
	dim plane as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	f = freefile
	open fil$ for binary access read write as #f
	if err > 0 then
		'debug "Couldn't open " + fil$
		exit sub
	end if

	'skip to index
	seek #f, (i*64000) + 1 'will this work with write access?

	screenlock

	'modex format, 4 planes
	scrnbase = spage(p)
	for plane = 0 to 3
		sptr = scrnbase + plane

		for idx = 0 to (16000 - 1) '1/4 of a screenfull
			ub = *sptr
			put #f, , ub
			sptr = sptr + 4
		next
	next

	close #f
end SUB

SUB loadpage (fil$, BYVAL i as integer, BYVAL p as integer)
'loads a whole page from a file
	dim f as integer
	dim idx as integer
	dim bi as integer
	dim ub as ubyte
	dim sptr as ubyte ptr
	dim scrnbase as ubyte ptr
	dim plane as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	f = freefile
	open fil$ for binary access read as #f
	if err > 0 then
		'debug "Couldn't open " + fil$
		exit sub
	end if

	'skip to index
	seek #f, (i*64000) + 1

	'modex format, 4 planes
	scrnbase = spage(p)
	for plane = 0 to 3
		sptr = scrnbase + plane

		for idx = 0 to (16000 - 1) '1/4 of a screenfull
			get #f, , ub
			*sptr = ub
			sptr = sptr + 4
		next
	next

	close #f

end SUB

SUB setdiskpages (buf() as integer, BYVAL h as integer, BYVAL l as integer)
'sets up buffer (not used) and page size in lines for the page functions above
'at the moment I have ignored this, and handled whole pages only, I'll have
'to check whether partial pages are used anywhere
'No, doesn't look like it is ever less than a whole page, starting at line 0.
end SUB

SUB setwait (b() as integer, BYVAL t as integer)
't is a value in milliseconds which, in the original, is used to set the event
'frequency and is also used to set the wait time, but the resolution of the
'dos timer means that the latter is always truncated to the last multiple of
'55 milliseconds.
	dim millis as integer
	dim secs as double
	millis = (t \ 55) * 55

	secs = millis / 1000
	waittime = timer + secs
	waitset = 1
end SUB

SUB dowait ()
'wait until alarm time set in setwait()
'In freebasic, sleep is in 1000ths, and a value of less than 100 will not
'be exited by a keypress, so sleep for 5ms until timer > waittime.
	dim i as integer
	do while timer <= waittime
		sleep 5 'is this worth it?
	loop
	if waitset = 1 then
		waitset = 0
	else
		debug "dowait called without setwait"
	end if
end SUB

SUB printstr (s$, BYVAL x as integer, BYVAL y as integer, BYVAL p as integer)
	dim col as integer
	dim si as integer 'screen index
	dim pscr as ubyte ptr
	dim ch as integer 'character
	dim fi as integer 'font index
	dim cc as integer 'char column
	dim pix as integer
	dim bval as integer
	dim tbyte as ubyte
	dim fstep as integer
	dim maxrow as integer
	dim minrow as integer

	if wrkpage <> p then
		wrkpage = p
	end if

	'check bounds
	if y < -7 or y > 199 then exit sub
	if x > 319 then exit sub
	
	'only draw rows that are on the screen
	maxrow = 199 - y
	if maxrow > 7 then 
		maxrow = 7
	end if
	minrow = 0
	if y < 0 then
		minrow = -y
		y = 0
	end if
	
	'is it actually faster to use a direct buffer write, or would pset be
	'sufficiently quick?
	col = x
	pscr = spage(p)
	for ch = 0 to len(s$) - 1
		'find fontdata index, bearing in mind that the data is stored
		'2-bytes at a time in 4-byte integers, due to QB->FB quirks,
		'and fontdata itself is a byte pointer. Because there are
		'always 8 bytes per character, we will always use exactly 4
		'ints, or 16 bytes, making the initial calc pretty simple.
		fi = (s$[ch] * 16)
		'fi = s$[ch] * 8	'index to fontdata
		fstep = 1 'used because our indexing is messed up, see above
		for cc = 0 to 7
			if col >= 0 then
				si = (y * 320) + col
				if (fontdata[fi] > 0) then
					tbyte = 1 shl minrow
					for pix = minrow to maxrow
						bval = fontdata[fi] and tbyte
						if bval > 0 then
							pscr[si] = textfg
						else
							if textbg > 0 then
								pscr[si] = textbg
							end if
						end if
						si = si + 320
						tbyte = tbyte shl 1
					next
				else
					if textbg > 0 then
						for pix = minrow to maxrow
							pscr[si] = textbg
							si = si + 320
						next
					end if
				end if
			end if
			col = col + 1
			if col >= 320 THEN exit SUB
			fi = fi + fstep
			fstep = iif(fstep = 1, 3, 1) 'uneven steps due to 2->4 byte thunk
		next
	next
end SUB

SUB textcolor (BYVAL f as integer, BYVAL b as integer)
	textfg = f
	textbg = b
end SUB

SUB setfont (f() as integer)
	fontdata = cast(ubyte ptr, @f(0))
end SUB

SUB setbit (bb() as integer, BYVAL w as integer, BYVAL b as integer, BYVAL v as integer)
	dim mask as uinteger
	dim woff as integer
	dim wb as integer

	woff = w + (b \ 16)
	wb = b mod 16

	if woff > ubound(bb) then
		debug "setbit overflow: ub " + str$(ubound(bb)) + ", w " + str$(w) + ", b " + str$(b)
		exit sub
	end if

	mask = 1 shl wb
	if v = 1 then
		bb(woff) = bb(woff) or mask
	else
		mask = not mask
		bb(woff) = bb(woff) and mask
	end if
end SUB

FUNCTION readbit (bb() as integer, BYVAL w as integer, BYVAL b as integer)  as integer
	dim mask as uinteger
	dim woff as integer
	dim wb as integer

	woff = w + (b \ 16)
	wb = b mod 16

	mask = 1 shl wb

	if (bb(woff) and mask) then
		readbit = 1
	else
		readbit = 0
	end if
end FUNCTION

SUB storeset (fil$, BYVAL i as integer, BYVAL l as integer)
' i = index, l = line (only if reading from screen buffer)
	dim f as integer
	dim idx as integer
	dim bi as integer
	dim ub as ubyte
	dim toggle as integer
	dim sptr as ubyte ptr

	f = freefile
	open fil$ for binary access read write as #f
	if err > 0 then
		'debug "Couldn't open " + fil$
		exit sub
	end if

	seek #f, (i*bsize) + 1 'does this work properly with write?
	'this is a horrible hack to get 2 bytes per integer, even though
	'they are 4 bytes long in FB
	bi = 0
	toggle = 0
	if bpage >= 0 then
		'read from screen
		sptr = spage(wrkpage)
		sptr = sptr + (320 * l)
		fput(f, ,sptr, bsize)
		'do I need to bother with buffer?
	else
		'debug "buffer size to read = " + str$(bsize)
		for idx = 0 to bsize - 1 ' this will be slow
			if toggle = 0 then
				ub = bptr[bi] and &hff
				toggle = 1
			else
				ub = (bptr[bi] and &hff00) shr 8
				toggle = 0
				bi = bi + 1
			end if
			put #f, , ub
		next
	end if

	close #f

end SUB

SUB loadset (fil$, BYVAL i as integer, BYVAL l as integer)
' i = index, l = line (only if reading to screen buffer)
	dim f as integer
	dim idx as integer
	dim bi as integer
	dim ub as ubyte
	dim toggle as integer
	dim sptr as ubyte ptr

	f = freefile
	open fil$ for binary access read as #f
	if err > 0 then
		'debug "Couldn't open " + fil$
		exit sub
	end if

	seek #f, (i*bsize) + 1
	'this is a horrible hack to get 2 bytes per integer, even though
	'they are 4 bytes long in FB
	bi = 0
	toggle = 0
	if bpage >= 0 then
		'read to screen
		sptr = spage(wrkpage)
		sptr = sptr + (320 * l)
		fget(f, ,sptr, bsize)
		'do I need to bother with buffer?
	else
		'debug "buffer size to read = " + str$(bsize)
		for idx = 0 to bsize - 1 ' this will be slow
			get #f, , ub
			if toggle = 0 then
				bptr[bi] = ub
				toggle = 1
			else
				bptr[bi] = bptr[bi] or (ub shl 8)
				'check sign
				if (bptr[bi] and &h8000) > 0 then
					bptr[bi] = bptr[bi] or &hffff0000 'make -ve
				end if
				toggle = 0
				bi = bi + 1
			end if
		next
	end if

	close #f
end SUB

SUB setpicstuf (buf() as integer, BYVAL b as integer, BYVAL p as integer)
	if p >= 0 then
		if wrkpage <> p then
			wrkpage = p
		end if
	end if

	bptr = @buf(0) 'doesn't really work well with FB
	bsize = b
	bpage = p
end SUB

SUB findfiles (fmask$, BYVAL attrib, outfile$, buf())
    ' attrib 0: all files 'cept folders, attrib 16: folders only
	fmask$ = TRIM(fmask$)
	outfile$ = TRIM(outfile$)
#ifdef __FB_LINUX__
        'this is pretty hacky, but works around the lack of DOS-style attributes, and the apparent uselessness of DIR$
	DIM grep$
	grep$ = "-v '/$'"
	IF attrib = 16 THEN grep$ = "'/$'"
	DIM i%
	FOR i = LEN(fmask$) TO 1 STEP -1
		IF MID$(fmask$, i, 1) = CHR$(34) THEN fmask$ = LEFT$(fmask$, i - 1) + "\" + CHR$(34) + RIGHT$(fmask$, LEN(fmask$) - i)
	NEXT i
	i = INSTR(fmask$, "*")
	IF i THEN
		fmask$ = CHR$(34) + LEFT$(fmask$, i - 1) + CHR$(34) + RIGHT$(fmask$, LEN(fmask$) - i + 1)
	ELSE
		fmask$ = CHR$(34) + fmask$ + CHR$(34)
	END IF
	SHELL "ls -d1p " + fmask$ + "|grep "+ grep$ + ">" + outfile$ + ".tmp"
	DIM AS INTEGER f1, f2
	f1 = FreeFile
	OPEN outfile$ + ".tmp" FOR INPUT AS #f1
	f2 = FreeFile
	OPEN outfile$ FOR OUTPUT AS #f2
	DIM s$
	DO UNTIL EOF(f1)
		LINE INPUT #f1, s$
		IF RIGHT$(s$, 1) = "/" THEN s$ = LEFT$(s$, LEN(s$) - 1)
		DO WHILE INSTR(s$, "/")
			s$ = RIGHT$(s$, LEN(s$) - INSTR(s$, "/"))
		LOOP
		PRINT #f2, s$
	LOOP
	CLOSE #f1
	CLOSE #f2
	KILL outfile$ + ".tmp"
#else
    DIM a$, i%, folder$
	if attrib = 0 then attrib = 255 xor 16

	FOR i = LEN(fmask$) TO 1 STEP -1
        IF MID$(fmask$, i, 1) = "\" THEN folder$ = MID$(fmask$, 1, i): EXIT FOR
    NEXT

	dim tempf%, realf%
	tempf = FreeFile
	OPEN outfile$ + ".tmp" FOR OUTPUT AS #tempf
	a$ = DIR$(fmask$, attrib)
	if a$ = "" then
		close #tempf
		exit sub
	end if
	DO UNTIL a$ = ""
		PRINT #tempf, a$
		a$ = DIR$("", attrib)
	LOOP
	CLOSE #tempf
    OPEN outfile$ + ".tmp" FOR INPUT AS #tempf
    realf = FREEFILE
    OPEN outfile$ FOR OUTPUT AS #realf
    DO UNTIL EOF(tempf)
        LINE INPUT #tempf, a$
        IF attrib = 16 THEN
            'alright, we want directories, but DIR$ is too broken to give them to us
            'files with attribute 0 appear in the list, so single those out
            IF DIR$(folder$ + a$, 255 xor 16) = "" THEN PRINT #realf, a$
        ELSE
            PRINT #realf, a$
        END IF
    LOOP
    CLOSE #tempf
    CLOSE #realf
    KILL outfile$ + ".tmp"
#endif
END SUB

SUB unlump (lump$, ulpath$, buffer() as integer)
	unlumpfile(lump$, "", ulpath$, buffer())
end SUB

SUB unlumpfile (lump$, fmask$, path$, buf() as integer)
	dim lf as integer
	dim dat as ubyte
	dim size as integer
	dim maxsize as integer
	dim lname as string
	dim i as integer
	dim bufr as ubyte ptr
	dim nowildcards as integer = 0

	lf = freefile
	open lump$ for binary access read as #lf
	if err > 0 then
		'debug "Could not open file " + lump$
		exit sub
	end if
	maxsize = LOF(lf)

	bufr = allocate(16383)
	if bufr = null then
		close #lf
		exit sub
	end if

	'should make browsing a bit faster
	if len(fmask$) > 0 then
		if instr(fmask$, "*") = 0 and instr(fmask$, "?") = 0 then
			nowildcards = -1
		end if
	end if

	get #lf, , dat	'read first byte
	while not eof(lf)
		'get lump name
		lname = ""
		i = 0
		while not eof(lf) and dat <> 0 and i < 64
			lname = lname + chr$(dat)
			get #lf, , dat
			i += 1
		wend
		if i > 50 then 'corrupt file, really if i > 12
			debug "corrupt lump file: lump name too long"
			exit while
		end if
		'force to lower-case
		lname = lcase(lname)
		'debug "lump name " + lname

		if instr(lname, "\") or instr(lname, "/") then
			debug "unsafe lump name " + str$(lname)
			exit while
		end if

		if not eof(lf) then
			'get lump size - byte order = 3,4,1,2 I think
			get #lf, , dat
			size = (dat shl 16)
			get #lf, , dat
			size = size or (dat shl 24)
			get #lf, , dat
			size = size or dat
			get #lf, , dat
			size = size or (dat shl 8)
			if size > maxsize then
				debug "corrupt lump size" + str$(size) + " exceeds source size" + str$(maxsize)
				exit while
			end if

			'debug "lump size " + str$(size)

			'do we want this file?
			if matchmask(lname, lcase$(fmask$)) then
				'write yon file
				dim of as integer
				dim csize as integer

				of = freefile
				open path$ + lname for binary access write as #of
				if err > 0 then
					'debug "Could not open file " + path$ + lname
					exit while
				end if

				'copy the data
				while size > 0
					if size > 16383 then
						csize = 16383
					else
						csize = size
					end if
					'copy a chunk of file
					fget lf, , bufr, csize
					fput of, , bufr, csize
					size = size - csize
				wend

				close #of

				'early out if we're only looking for one file
				if nowildcards then exit while
			else
				'skip to next name
				i = seek(lf)
				i = i + size
				seek #lf, i
			end if

			if not eof(lf) then
				get #lf, , dat
			end if
		end if
	wend

	deallocate bufr
	close #lf

end SUB

SUB lumpfiles (listf$, lump$, path$, buffer())
	dim as integer lf, fl, tl	'lumpfile, filelist, tolump

	dim dat as ubyte
	dim size as integer
	dim lname as string
	dim lpath as string
	dim bufr as ubyte ptr
	dim csize as integer
	dim as integer i, t, textsize(1)

	lpath = rtrim(path$)

	fl = freefile
	open listf$ for input as #fl
	if err <> 0 then
		exit sub
	end if

	lf = freefile
	open lump$ for binary access write as #lf
	if err <> 0 then
		'debug "Could not open file " + lump$
		close #fl
		exit sub
	end if

	bufr = allocate(16000)

	'get file to lump
	do until eof(fl)
		line input #fl, lname
		lname = rtrim(lname) 'remove trailing null
		
		'validate that lumpname is 8.3 or ignore the file
		textsize(0) = 0
		textsize(1) = 0
		t = 0
		for i = 0 to len(lname)-1
			if lname[i] = asc(".") then t = 1
			textsize(t) += 1
		next
		'note extension includes the "." so can be 4 chars
		if textsize(0) > 8 or textsize(1) > 4 then
			debug "name too long: " + lname
			debug " name = " + str(textsize(0)) + ", ext = " + str(textsize(1))
			continue do
		end if

		tl = freefile
		open lpath + lname for binary access read as #tl
		if err <> 0 then
			'debug "failed to open " + lpath + lname
			continue do
		end if

		'write lump name (seems to need to be upper-case, at least
		'for any files opened with unlumpone in the QB version)
		put #lf, , ucase(lname)
		dat = 0
		put #lf, , dat

		'write lump size - byte order = 3,4,1,2 I think
		size = lof(tl)
		dat = (size and &hff0000) shr 16
		put #lf, , dat
		dat = (size and &hff000000) shr 24
		put #lf, , dat
		dat = size and &hff
		put #lf, , dat
		dat = (size and &hff00) shr 8
		put #lf, , dat

		'write lump
		while size > 0
			if size > 16000 then
				csize = 16000
			else
				csize = size
			end if
			'copy a chunk of file
			fget(tl, , bufr, csize)
			fput(lf, , bufr, csize)
			size = size - csize
		wend

		close #tl
	loop

	close #lf
	close #fl

	deallocate bufr
END SUB

FUNCTION isfile (n$) as integer
    ' I'm assuming we don't count directories as files
	'return dir$(n$) <> ""
    return dir$(n$, 255 xor 16) <> ""
END FUNCTION

FUNCTION pathlength () as integer
	path = curdir$
	pathlength = len(path)
end FUNCTION

SUB getstring (p$)
	p$ = path
end SUB

FUNCTION drivelist (d() as integer) as integer
#ifdef __FB_LINUX__
	' on Linux there is only one drive, the root /
	d(0) = -1
	drivelist = 1
#else
	'faked, needs work
	d(0) = 3
	d(1) = 4
	d(2) = 5
	drivelist = 3
#endif
end FUNCTION

FUNCTION rpathlength () as integer
	path = exepath
    rpathlength = len(path)
end FUNCTION

FUNCTION exenamelength () as integer
	path = command$(0)
	exenamelength = len(path)
end FUNCTION

SUB setdrive (BYVAL n as integer)
end SUB

FUNCTION envlength (e$) as integer
	path = environ$(e$)
	envlength = len(path)
end FUNCTION

FUNCTION isdir (sDir$) as integer
	isdir = NOT (dir$(sDir$, 16) = "")
END FUNCTION

FUNCTION isremovable (BYVAL d) as integer
	isremovable = 0
end FUNCTION

FUNCTION isvirtual (BYVAL d)
	isvirtual = 0
END FUNCTION

FUNCTION hasmedia (BYVAL d as integer) as integer
	hasmedia = 0
end FUNCTION

FUNCTION LongNameLength (filename$) as integer
	path = filename$
	longnamelength = len(path)
end FUNCTION

SUB setupmusic (mbuf() as integer)
	music_init
end SUB

SUB closemusic ()
	music_close
end SUB

SUB loadsong (f$)
	'check for extension
	dim ext as string
	dim songname as string
	dim songtype as MUSIC_FORMAT

	songname = rtrim(f$) 'lose null
	songtype = FORMAT_BAM
	ext = lcase(right(songname, 4))
	if ext = ".mid" then
		songtype = FORMAT_MIDI
	elseif ext = ".ogg" then
		songtype = FORMAT_OGG
	elseif ext = ".mod" then
		'going to need to change ext to support .it or .xm
		songtype = FORMAT_MOD
	end if

	music_play(songname, songtype)
end SUB

SUB stopsong ()
	music_pause()
end SUB

SUB resumesong ()
	music_resume
end SUB

SUB fademusic (BYVAL vol as integer)
	music_fade(vol)
end SUB

FUNCTION getfmvol () as integer
	getfmvol = music_getvolume
end FUNCTION

SUB setfmvol (BYVAL vol as integer)
	music_setvolume(vol)
end SUB

SUB copyfile (s$, d$, buf() as integer)
	dim bufr as ubyte ptr
	dim as integer fi, fo, size, csize

	fi = freefile
	open s$ for binary access read as #fi
	if err <> 0 then
		exit sub
	end if

	fo = freefile
	open d$ for binary access write as #fo
	if err <> 0 then
		close #fi
		exit sub
	end if

	size = lof(fi)

	if size < 16000 then
		bufr = allocate(size)
		'copy a chunk of file
		fget(fi, , bufr, size)
		fput(fo, , bufr, size)
	else
		bufr = allocate(16000)

		'write lump
		while size > 0
			if size > 16000 then
				csize = 16000
			else
				csize = size
			end if
			'copy a chunk of file
			fget(fi, , bufr, csize)
			fput(fo, , bufr, csize)
			size = size - csize
		wend
	end if

	deallocate bufr
	close #fi
	close #fo

end SUB

SUB screenshot (f$, BYVAL p as integer, maspal() as integer, buf() as integer)
'Not sure whether this should be in here or in gfx. Possibly both?
'	bsave f$, 0
	dim fname as string

	fname = rtrim$(f$)

	'try external first
	if gfx_screenshot(fname, p) = 0 then
		'otherwise save it ourselves
		dim header as BITMAPFILEHEADER
		dim info as BITMAPINFOHEADER
		dim argb as RGBQUAD

		dim as integer of, w, h, i, bfSize, biSizeImage, bfOffBits, biClrUsed, pitch
		dim as ubyte ptr s

		w = 320
		h = 200
		s = spage(p)
		pitch = w

		biSizeImage = w * h
		bfOffBits = 54 + 1024
		bfSize = bfOffBits + biSizeImage
		biClrUsed = 256

		header.bfType = 19778
		header.bfSize = bfSize
		header.bfReserved1 = 0
		header.bfReserved2 = 0
		header.bfOffBits = bfOffBits

		info.biSize = 40
		info.biWidth = w
		info.biHeight = h
		info.biPlanes = 1
		info.biBitCount = 8
		info.biCompression = 0
		info.biSizeImage = biSizeImage
		info.biXPelsPerMeter = &hB12
		info.biYPelsPerMeter = &hB12
		info.biClrUsed = biClrUsed
		info.biClrImportant = biClrUsed

		of = freefile
		open fname for binary access write as #of
		if err > 0 then
			'debug "Couldn't open " + fname
			exit sub
		end if

		put #of, , header
		put #of, , info

		for i = 0 to 765 step 3
			argb.rgbRed = maspal(i) * 4
			argb.rgbGreen = maspal(i+1) * 4
			argb.rgbBlue = maspal(i+2) * 4
			put #of, , argb
		next

		s += (h - 1) * pitch
		while h > 0
			fput(of, , s, pitch)
			s -= pitch
			h -= 1
		wend

		close #of
	end if
end SUB

FUNCTION setmouse (mbuf() as integer) as integer
'don't think this does much except says whether there is a mouse
'no idea what the parameter is for
	if io_enablemouse <> 0 then
		setmouse = 0
		exit function
	end if
	setmouse = 1
end FUNCTION

SUB readmouse (mbuf() as integer)
	dim as integer mx, my, mw, mb, mc
	static lastx as integer = 0
	static lasty as integer = 0

	io_getmouse(mx, my, mw, mb)
	if (mx < 0) then 
		mx = lastx
	else
		lastx = mx
	end if
	if (my < 0) then 
		my = lasty
	else
		lasty = my
	end if
	if (mx > mouse_xmax) then mx = mouse_xmax
	if (mx < mouse_xmin) then mx = mouse_xmin
	if (my > mouse_ymax) then my = mouse_ymax
	if (my < mouse_ymin) then my = mouse_ymin

	mutexlock keybdmutex   'is this necessary?
	mc = mouseflags or (mb and not mouselastflags)
	mouselastflags = mb
	mouseflags = 0

	if (mb < 0) then
		'off screen, preserve last button state
		mb = mouselastflags
		mc = 0
	end if
	mutexunlock keybdmutex

	mbuf(0) = mx
	mbuf(1) = my
	mbuf(2) = mb or mc
	mbuf(3) = mc
end SUB

SUB movemouse (BYVAL x as integer, BYVAL y as integer)
	io_setmouse(x, y)
end SUB

SUB mouserect (BYVAL xmin, BYVAL xmax, BYVAL ymin, BYVAL ymax)
	mouse_xmin = xmin
	mouse_xmax = xmax
	mouse_ymin = ymin
	mouse_ymax = ymax
	io_mouserect(xmin, xmax, ymin, ymax)
end sub

FUNCTION readjoy (joybuf() as integer, BYVAL jnum as integer) as integer
'Return 0 if joystick is not present, or -1 (true) if joystick is present
'jnum is the joystick to read (QB implementation supports 0 and 1)
'joybuf(0) = Analog X axis
'joybuf(1) = Analog Y axis
'joybuf(2) = button 1: 0=pressed nonzero=not pressed
'joybuf(3) = button 2: 0=pressed nonzero=not pressed
'Other values in joybuf() should be preserved.
'If X and Y axis are not analog,
'  upward motion when joybuf(0) < joybuf(9)
'  down motion when joybuf(0) > joybuf(10)
'  left motion when joybuf(1) < joybuf(11)
'  right motion when joybuf(1) > joybuf(12)
	readjoy = io_readjoy(joybuf(), jnum)
end FUNCTION

SUB array2str (arr() AS integer, BYVAL o AS integer, s$)
'String s$ is already filled out with spaces to the requisite size
'o is the offset in bytes from the start of the buffer
'the buffer will be packed 2 bytes to an int, for compatibility, even
'though FB ints are 4 bytes long  ** leave like this? not really wise
	DIM i AS Integer
	dim bi as integer
	dim bp as integer ptr
	dim toggle as integer

	bp = @arr(0)
	bi = o \ 2 'offset is in bytes
	toggle = o mod 2

	for i = 0 to len(s$) - 1
		if toggle = 0 then
			s$[i] = bp[bi] and &hff
			toggle = 1
		else
			s$[i] = (bp[bi] and &hff00) shr 8
			toggle = 0
			bi = bi + 1
		end if
	next

END SUB

SUB str2array (s$, arr() as integer, BYVAL o as integer)
'strangely enough, this does the opposite of the above
	DIM i AS Integer
	dim bi as integer
	dim bp as integer ptr
	dim toggle as integer

	bp = @arr(0)
	bi = o \ 2 'offset is in bytes
	toggle = o mod 2

	'debug "String is " + str$(len(s$)) + " chars"
	for i = 0 to len(s$) - 1
		if toggle = 0 then
			bp[bi] = s$[i] and &hff
			toggle = 1
		else
			bp[bi] = (bp[bi] and &hff) or (s$[i] shl 8)
			'check sign
			if (bp[bi] and &h8000) > 0 then
				bp[bi] = bp[bi] or &hffff0000 'make -ve
			end if
			toggle = 0
			bi = bi + 1
		end if
	next
end SUB

SUB setupstack (buffer() as integer, BYVAL size as integer, file$)
'Currently, stack is always 1024, and blocks of 512 are written out to file$
'whenever it gets too big. Likewise, the passed is never used for anything else.
'For simlpicity, I've decided to allocate a larger stack in memory and ignore
'the parameters.
	stacktop = allocate(32768 * 4) '32k
	if (stacktop = 0) then
		'oh dear
		debug "Not enough memory for stack"
		exit sub
	end if
	stackptr = stacktop
	stacksize = 32768
end SUB

SUB pushw (BYVAL word as integer)
'not sure about the byte order, but it shouldn't matter as long as I undo it
'the same way.
'check bounds to stop overflow - currently it will still break since there's
'no error handling, but at least it won't scribble.
	if stackptr - stacktop < stacksize - 2 and stackptr >= stacktop then
		*stackptr = word and &hff
		stackptr = stackptr + 1
		*stackptr = (word and &hff00) shr 8
		stackptr = stackptr + 1
	else
		debug "overflow"
	end if
end SUB

FUNCTION popw () as integer
	dim pw as integer

	if (stackptr > stacktop) then
		stackptr = stackptr - 1
		pw = *stackptr shl 8
		stackptr = stackptr - 1
		pw = pw or (*stackptr)
		'sign
		if pw and &h8000 then
			pw = pw or &hffff0000
		end if
	else
		pw = 0
		debug "underflow"
	end if

	popw = pw
end FUNCTION

SUB releasestack ()
	if stacksize > 0 then
		deallocate stacktop
		stacksize = -1
	end if
end SUB

FUNCTION stackpos () as integer
	stackpos = stackptr - stacktop
end FUNCTION

'private functions
function matchmask(match as string, mask as string) as integer
	dim i as integer
	dim m as integer
	dim si as integer, sm as integer

	'special cases
	if mask = "" then
		matchmask = 1
		exit function
	end if

	i = 0
	m = 0
	while (i < len(match)) and (m < len(mask)) and (mask[m] <> asc("*"))
		if (match[i] <> mask[m]) and (mask[m] <> asc("?")) then
			matchmask = 0
			exit function
		end if
		i = i+1
		m = m+1
	wend

	if (m >= len(mask)) and (i < len(match)) then
		matchmask = 0
		exit function
	end if

	while i < len(match)
		if m >= len(mask) then
			'run out of mask with string left over, rewind
			i = si + 1 ' si will always be set by now because of *
			si = i
			m = sm
		else
			if mask[m] = asc("*") then
				m = m + 1
				if m >= len(mask) then
					'* eats the rest of the string
					matchmask = 1
					exit function
				end if
				i = i + 1
				'store the positions in case we need to rewind
				sm = m
				si = i
			else
				if (mask[m] = match[i]) or (mask[m] = asc("?")) then
					'ok, next
					m = m + 1
					i = i + 1
				else
					'mismatch, rewind to last * positions, inc i and try again
					m = sm
					i = si + 1
					si = i
				end if
			end if
		end if
	wend

  	while (m < len(mask)) and (mask[m] = asc("*"))
  		m = m + 1
  	wend

  	if m < len(mask) then
		matchmask = 0
	else
		matchmask = 1
	end if

end function

function calcblock(byval x as integer, byval y as integer, byval t as integer) as integer
'returns -1 if overlay
	dim block as integer
	dim tptr as integer ptr
	dim over as integer

	'check bounds
	if bordertile = -1 then
		'wrap
		while y < 0
			y = y + map_y
		wend
		while y >= map_y
			y = y - map_y
		wend
		while x < 0
			x = x + map_x
		wend
		while x >= map_x
			x = x - map_x
		wend
	else
		if (y < 0) or (y >= map_y) then
			calcblock = bordertile
			exit function
		end if
		if (x < 0) or (x >= map_x) then
			calcblock = bordertile
			exit function
		end if
	end if

	block = readmapblock(x, y)

	'check overlay (??)
	'I think it should work like this:
	'if overlay (t) is 0, then ignore the overlay flag
	'if it's 1, return -1 and don't draw overhead tiles (this is
	'actually not working, but doesn't matter too much)
	'if it's 130 then return the tile id
	if t > 0 then
		over = readpassblock(x, y)
		over = (over and 128) + t 'whuh?
		if (over <> 130) and (over <> 1) then
			block = -1
		end if
	end if

	calcblock = block
end function

'----------------------------------------------------------------------
'Bitmap import functions - other formats are probably quite simple
'with Allegro or SDL or FreeImage, but we'll stick to this for now.
'----------------------------------------------------------------------
SUB bitmap2page (temp(), bmp$, BYVAL p)
'loads the 24-bit bitmap bmp$ into page p with palette temp()
'I'm pretty sure this is only ever called with 320x200 pics, but I
'have tried to generalise it to cope with any size.
	dim fname as string
	dim header as BITMAPFILEHEADER
	dim info as BITMAPINFOHEADER
	dim pix as RGBTRIPLE
	dim pix8 as UByte
	dim bf as integer
	dim as integer w, h, maxw, maxh
	dim as ubyte ptr sptr, sbase
	dim ub as ubyte
	dim pad as integer

	fname = rtrim$(bmp$)

	bf = freefile
	open fname for binary access read as #bf
	if err > 0 then
		'debug "Couldn't open " + fname
		exit sub
	end if

	get #bf, , header
	if header.bfType <> 19778 then
		'not a bitmap
		close #bf
		exit sub
	end if

	get #bf, , info

	if info.biBitCount <> 24 AND info.biBitCount <> 8 then
		close #bf
		exit sub
	end if

	sbase = spage(p)

	
	'navigate to the beginning of the bitmap data
	seek #bf, header.bfOffBits + 1

	
	IF info.biBitCount = 24 THEN	
		'data lines are padded to 32-bit boundaries
		pad = 4 - ((info.biWidth * 3) mod 4)
		if pad = 4 then	pad = 0
		'crop images larger than screen
		maxw = info.biWidth - 1
		if maxw > 319 then
			maxw = 319
			pad = pad + ((info.biWidth - 320) * 3)
		end if
		maxh = info.biHeight - 1
		if maxh > 199 then
			maxh = 199
		end if
		for h = info.biHeight - 1 to 0 step -1
			if h > maxh then
				for w = 0 to maxw
					'read the data
					get #bf, , pix
				next
			else
				sptr = sbase + (h * 320)
				for w = 0 to maxw
					'read the data
					get #bf, , pix
					*sptr = nearcolor(temp(), pix.rgbtRed, pix.rgbtGreen, pix.rgbtBlue)
					sptr += 1
				next
			end if
	
			'padding to dword boundary, plus excess pixels
			for w = 0 to pad-1
				get #bf, , ub
			next
		next
	ELSEIF info.biBitCount = 8 THEN
		'data lines are padded to 32-bit boundaries
		pad = 4 - (info.biWidth mod 4)
		if pad = 4 then	pad = 0
		'crop images larger than screen
		maxw = info.biWidth - 1
		if maxw > 319 then
			maxw = 319
			pad = pad + ((info.biWidth - 320) * 3)
		end if
		maxh = info.biHeight - 1
		if maxh > 199 then
			maxh = 199
		end if
		for h = info.biHeight - 1 to 0 step -1
			if h > maxh then
				for w = 0 to maxw
					'read the data
					get #bf, , pix
				next
			else
				sptr = sbase + (h * 320)
				for w = 0 to maxw
					'read the data
					get #bf, , pix8 'assume they know what they're doing
					*sptr = pix8
					sptr += 1
				next
			end if
	
			'padding to dword boundary, plus excess pixels
			for w = 0 to pad-1
				get #bf, , ub
			next
		next
	END IF

	close #bf
END SUB

SUB loadbmp (f$, BYVAL x, BYVAL y, buf(), BYVAL p)
'loads the 4-bit bitmap f$ into page p at x, y
'sets palette to match file???
	dim fname as string
	dim header as BITMAPFILEHEADER
	dim info as BITMAPINFOHEADER
	dim bf as integer
	dim as integer maxw, maxh
	dim sbase as ubyte ptr
	dim i as integer
	dim col as RGBQUAD

	fname = rtrim$(f$)

	bf = freefile
	open fname for binary access read as #bf
	if err > 0 then
		'debug "Couldn't open " + fname
		exit sub
	end if

	get #bf, , header
	if header.bfType <> 19778 then
		'not a bitmap
		close #bf
		exit sub
	end if

	get #bf, , info

	if info.biBitCount <> 4 then
		close #bf
		exit sub
	end if

	'use header offset to get to data
	seek #bf, header.bfOffBits + 1

	sbase = spage(p) + (y * 320) + x

	'crop images larger than screen
	maxw = info.biWidth - 1
	if maxw > 319 - x then	maxw = 319 - x
	maxh = info.biHeight - 1
	if maxh > 199 - y then 	maxh = 199 - y

	'call one of two loaders depending on compression
	if info.biCompression = BI_RGB then
		loadbmp4(bf, info.biWidth, info.biHeight, maxw, maxh, sbase)
	elseif info.biCompression = BI_RLE4 then
		loadbmprle4(bf, info.biWidth, info.biHeight, maxw, maxh, sbase)
	end if

	close #bf
END SUB

SUB loadbmp4(byval bf as integer, byval iw as integer, byval ih as integer, byval maxw as integer, byval maxh as integer, byval sbase as ubyte ptr)
'takes an open file handle and a screen pointer, should only be called within loadbmp
	dim pix as ubyte
	dim ub as ubyte
	dim linelen as integer
	dim toggle as integer
	dim bcount as integer
	dim as integer w, h
	dim sptr as ubyte ptr

	linelen = (iw + 1) \ 2 	'num of bytes
	linelen = ((linelen + 3) \ 4) * 4 	'nearest dword bound

	for h = ih - 1 to 0 step -1
		bcount = 0
		toggle = 0
		if h > maxh then
			for w = 0 to maxw
				if toggle = 0 then
					'read the data
					get #bf, , pix
					toggle = 1
					bcount += 1
				else
					toggle = 0
				end if
			next
		else
			sptr = sbase + (h * 320)
			for w = 0 to maxw
				if toggle = 0 then
					'read the data
					get #bf, , pix
					*sptr = (pix and &hf0) shr 4
					sptr += 1
					toggle = 1
					bcount += 1
				else
					'2nd nybble in byte
					*sptr = pix and &h0f
					sptr += 1
					toggle = 0
				end if
			next
		end if

		'padding to dword boundary, plus excess pixels
		while bcount < linelen
			get #bf, , ub
			bcount += 1
		wend
	next
END SUB

SUB loadbmprle4(byval bf as integer, byval iw as integer, byval ih as integer, byval maxw as integer, byval maxh as integer, byval sbase as ubyte ptr)
'takes an open file handle and a screen pointer, should only be called within loadbmp
	dim pix as ubyte
	dim ub as ubyte
	dim toggle as integer
	dim as integer w, h
	dim sptr as ubyte ptr
	dim i as integer
	dim as ubyte bval, v1, v2

	w = 0
	h = ih -1

	'read bytes until we're done
	while not eof(bf)
		'get command byte
		get #bf, , ub
		select case ub
			case 0	'special, check next byte
				get #bf, , ub
				select case ub
					case 0		'end of line
						w = 0
						h -= 1
					case 1		'end of bitmap
						exit while
					case 2 		'delta (how can this ever be used?)
						get #bf, , ub
						w = w + ub
						get #bf, , ub
						h = h + ub
					case else	'absolute mode
						toggle = 0
						for i = 1 to ub
							if toggle = 0 then
								get #bf, , pix
								toggle = 1
								bval = (pix and &hf0) shr 4
							else
								toggle = 0
								bval = pix and &h0f
							end if
							if h <= maxh and w <= maxw then
								sptr = sbase + (h * 320) + w
								*sptr = bval
							end if
							w += 1
						next
						if (ub + 1) mod 4 > 1 then	'is this right?
							get #bf, , ub 'pad to word bound
						end if
				end select
			case else	'run-length
				get #bf, , pix	'2 colours
				v1 = (pix and &hf0) shr 4
				v2 = pix and &h0f

				toggle = 0
				for i = 1 to ub
					if toggle = 0 then
						toggle = 1
						bval = v1
					else
						toggle = 0
						bval = v2
					end if
					if h <= maxh and w <= maxw then
						sptr = sbase + (h * 320) + w
						*sptr = bval
					end if
					w += 1
				next
		end select
	wend

end sub

SUB getbmppal (f$, mpal(), pal(), BYVAL o)
'gets the nearest-match palette pal() starting at offset o, from file f$
'according to the master palette mpal()
	dim fname as string
	dim header as BITMAPFILEHEADER
	dim info as BITMAPINFOHEADER
	dim col as RGBQUAD
	dim col8 as integer
	dim bf as integer
	dim i as integer
	dim p as integer
	dim toggle as integer

	fname = rtrim$(f$)

	bf = freefile
	open fname for binary access read as #bf
	if err > 0 then
		'debug "Couldn't open " + fname
		exit sub
	end if

	get #bf, , header
	if header.bfType <> 19778 then
		'not a bitmap
		close #bf
		exit sub
	end if

	get #bf, , info

	if info.biBitCount <> 4 then
		close #bf
		exit sub
	end if

	'read and translate the 16 colour entries
	p = o
	toggle = p mod 2
	for i = 0 to 15
		get #bf, , col
		col8 = nearcolor(mpal(), col.rgbRed, col.rgbGreen, col.rgbBlue)
		if toggle = 0 then
			pal(p) = col8
			toggle = 1
		else
			pal(p) = pal(p) or (col8  shl 8)
			toggle = 0
			p += 1
		end if
	next

	close #bf
END SUB

FUNCTION bmpinfo (f$, dat())
	dim fname as string
	dim header as BITMAPFILEHEADER
	dim info as BITMAPINFOHEADER
	dim bf as integer

	fname = rtrim$(f$)

	bf = freefile
	open fname for binary access read as #bf
	if err > 0 then
		'debug "Couldn't open " + fname
		bmpinfo = 0
		exit function
	end if

	get #bf, , header
	if header.bfType <> 19778 then
		'not a bitmap
		bmpinfo = 0
		close #bf
		exit function
	end if

	get #bf, , info

	'only these 4 fields are returned by the asm
	dat(0) = info.biBitCount
	dat(1) = info.biWidth
	dat(2) = info.biHeight
	'seems to be a gap here, or all 4 bytes of height are returned
	'but I doubt this will be relevant anyway
	dat(3) = 0
	dat(4) = info.biCompression
	'code doesn't actually seem to use anything higher than 2 anway

	close #bf

	bmpinfo = -1
END FUNCTION

function nearcolor(pal() as integer, byval red as ubyte, byval green as ubyte, byval blue as ubyte) as ubyte
'figure out nearest palette colour
'supplied pal() is r,g,b
	dim as integer i, diff, col, best, save, rdif, bdif, gdif

	best = 1000
	save = 0
	for col = 0 to 255
		i = col * 3
		rdif = (red shr 2) - pal(i)
		gdif = (green shr 2) - pal(i+1)
		bdif = (blue shr 2) - pal(i+2)
		diff = abs(rdif) + abs(gdif) + abs(bdif)
		'diff = rdif^2 + gdif^2 + bdif^2
		if diff = 0 then
			'early out on direct hit
			save = col
			exit for
		end if
		if diff < best then
			save = col
			best = diff
		end if
	next

	nearcolor = save
end function

''-----------------------------------------------------------------------
'' Compatibility stuff that should probably go in another file
''-----------------------------------------------------------------------
function xstr$(x as integer)
	if x >= 0 then
		xstr$ = " " + str$(x)
	else
		xstr$ = str$(x)
	end if
end function

function xstr$(x as single)
	if x >= 0 then
		xstr$ = " " + str$(x)
	else
		xstr$ = str$(x)
	end if
end function

function xstr$(x as double)
	if x >= 0 then
		xstr$ = " " + str$(x)
	else
		xstr$ = str$(x)
	end if
end function

'-------------- Software GFX mode routines -----------------
sub setclip(l as integer, t as integer, r as integer, b as integer)
	clipl = l
	clipt = t
	clipr = r
	clipb = b
end sub

sub drawohr(byref spr as ohrsprite, x as integer, y as integer, scale as integer)
	dim sptr as ubyte ptr
	dim as integer tx, ty
	dim as integer i, j, pix, spix

	'assume wrkpage
	sptr = spage(wrkpage)

	if scale = 0 then scale = 1

	'checking the clip region should really be outside the loop,
	'I think, but we'll see how this works
	ty = y
	for i = 0 to (spr.h * scale) - 1
		tx = x
		for j = 0 to (spr.w * scale) - 1
			'check bounds
			if not (tx < clipl or tx > clipr or ty < clipt or ty > clipb) then
				'ok to draw pixel
				pix = (ty * 320) + tx
				spix = ((i \ scale) * spr.w) + (j \ scale)
				'check mask
				if spr.mask <> 0 then
					'not really sure whether to leave the masks like
					'this or change them above, this is the wrong
					'way round, really. perhaps.
					if spr.mask[spix] = 0 then
						sptr[pix] = spr.image[spix]
					end if
				else
					sptr[pix] = spr.image[spix]
				end if
			end if
			tx += 1
		next
		ty += 1
	next

end sub

sub grabrect(page as integer, x as integer, y as integer, w as integer, h as integer, ibuf as ubyte ptr)
'ibuf should be pre-allocated
	dim sptr as ubyte ptr
	dim as integer i, j, px, py

	if ibuf = null then exit sub

	sptr = spage(page)

	py = y
	for i = 0 to h-1
		px = x
		for j = 0 to w-1
			'ignore clip rect, but check screen bounds
			if not (px < 0 or px > 319 or py < 0 or py > 199) then
				ibuf[i*w + j] = sptr[(py * 320) + px]
			else
				ibuf[i*w + j] = 0
			end if
			px += 1
		next
		py += 1
	next

end sub



#DEFINE ID(a,b,c,d) asc(a) SHL 0 + asc(b) SHL 8 + asc(c) SHL 16 + asc(d) SHL 24
function isawav(fi$) as integer
  if not isfile(fi$) then return 0 'duhhhhhh
  
  dim _RIFF as integer = ID("R","I","F","F") 'these are the "signatures" of a
  dim _WAVE as integer = ID("W","A","V","E") 'wave file. RIFF is the format,
  dim _fmt_ as integer = ID("f","m","t"," ") 'WAVE is the type, and fmt_ and
  dim _data as integer = ID("d","a","t","a") 'data are the chunks
  
  dim chnk_ID as integer
  dim chnk_size as integer
  dim f as integer = freefile
  open fi$ for binary as #f
  
  get #f,,chnk_ID
  if chnk_ID <> _RIFF then return 0 'not even a RIFF file
  
  get #f,,chnk_size 'don't care
  
  get #f,,chnk_ID
  
  if chnk_ID <> _WAVE then return 0 'not a WAVE file, pffft
  
  'is this good enough? meh, sure.
  close #f
  return 1
  
end function


SUB setupsound ()
	sound_init
end SUB

SUB closesound ()
 	sound_close
end SUB

SUB loadsfx (byref slot, f$) '0-foo, or -1 for auto
	slot = sound_load(slot, f$)
end SUB

SUB freesfx (byval slot)
	sound_free(slot)
end SUB

SUB playsfx (BYVAL slot, BYVAL l)
  sound_play(slot,l)
end sub

SUB stopsfx (BYVAL slot)
  sound_stop (slot)
end sub

SUB pausesfx (BYVAL slot)
  sound_pause(slot)
end sub

Function sfxisplaying(BYVAL slot)
  return sound_playing(slot)
end Function

function sfxslots() as integer
  return sound_slots
end function