'OHRRPGCE - Runtime backend loading routines
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#include "config.bi"
#include "common.bi"
#include "gfx.bi"
#include "music.bi"
#include "gfx.new.bi"
#include "surface.bi"
#include "cmdline.bi"

#include "backendinfo.bi"

extern "C"

#ifdef __FB_DARWIN__
	type OSType as integer
	'From CoreServices (Gestalt.h)
	declare function Gestalt (byval selector as OSType, byval reponse as integer ptr) as integer
#endif

dim gfx_Initialize as function (byval pCreationData as const GfxInitData ptr) as integer
dim gfx_Shutdown as sub ()
dim gfx_SendMessage as function (byval msg as unsigned integer, byval dwParam as unsigned integer, byval pvParam as Any ptr) as integer
'dim gfx_GetVersion as function () as integer
dim gfx_PumpMessages as sub ()
'dim gfx_Present as sub (byval pSurface as ubyte ptr, byval nWidth as integer, byval nHeight as integer, byval pPalette as RGBcolor ptr)
'dim gfx_ScreenShot as function (byval szFileName as const zstring ptr) as integer
dim gfx_SetWindowTitle as sub (byval szTitleconst as const zstring ptr)
dim gfx_GetWindowTitle as function () as const zstring ptr
'dim gfx_GetWindowState as sub (byval nID as integer, byval pState as WindowState ptr)
dim gfx_AcquireKeyboard as function (byval bEnable as integer) as integer
dim gfx_AcquireMouse as function (byval bEnable as integer) as integer
dim gfx_AcquireJoystick as function (byval bEnable as integer, byval nDevice as integer) as integer
dim gfx_AcquireTextInput as function (byval bEnable as integer) as integer
dim gfx_GetKeyboard as function (byval pKeyboard as KeyBits ptr) as integer
dim gfx_GetText as sub (byval pBuffer as wstring ptr, byval buffenLen as integer)
dim gfx_GetMouseMovement as function (byref dx as integer, byref dy as integer, byref dWheel as integer, byref buttons as integer) as integer
dim gfx_GetMousePosition as function (byref x as integer, byref y as integer, byref wheel as integer, byref buttons as integer) as integer
dim gfx_SetMousePosition as function (byval x as integer, byval y as integer) as integer
dim gfx_GetJoystickMovement as function (byval nDevice as integer, byref dx as integer, byref dy as integer, byref buttons as integer) as integer
dim gfx_GetJoystickPosition as function (byval nDevice as integer, byref x as integer, byref y as integer, byref buttons as integer) as integer
dim gfx_SetJoystickPosition as function (byval nDevice as integer, byval x as integer, byval y as integer) as integer

'Old graphics backend function pointers

dim gfx_init as function (byval terminate_signal_handler as sub cdecl (), byval windowicon as zstring ptr, byval info_buffer as zstring ptr, byval info_buffer_size as integer) as integer
dim gfx_close as sub ()
dim gfx_setdebugfunc as sub (byval debugc as sub cdecl (byval errorlevel as ErrorLevelEnum, byval message as zstring ptr))
dim gfx_getversion as function () as integer
dim gfx_setpal as sub (byval pal as RGBcolor ptr)
dim gfx_screenshot as function (byval fname as zstring ptr) as integer
dim gfx_setwindowed as sub (byval iswindow as integer)
dim gfx_windowtitle as sub (byval title as zstring ptr)
dim gfx_getwindowstate as function () as WindowState ptr
dim gfx_get_screen_size as sub (wide as integer ptr, high as integer ptr)
dim gfx_set_window_size as sub (byval newsize as XYPair = XY(-1,-1), newzoom as integer = -1)
dim gfx_supports_variable_resolution as function () as bool
dim gfx_get_resize as function (byref ret as XYPair) as bool
dim gfx_set_resizable as function (enable as bool, min_width as integer, min_height as integer) as bool
dim gfx_recenter_window_hint as sub ()
dim gfx_vsync_supported as function () as bool

dim gfx_get_settings as sub (byref settings as GfxSettings)
dim gfx_set_settings as sub (settings as GfxSettings)
dim gfx_setoption as function (byval opt as zstring ptr, byval arg as zstring ptr) as integer
dim gfx_describe_options as function () as zstring ptr
dim gfx_printchar as sub (byval ch as integer, byval x as integer, byval y as integer, byval col as integer)
dim gfx_get_safe_zone_margin as function () as single
dim gfx_set_safe_zone_margin as sub (byval margin as single)
dim gfx_supports_safe_zone_margin as function () as bool
dim gfx_ouya_purchase_request as sub(dev_id as string, identifier as string, key_der as string)
dim gfx_ouya_purchase_is_ready as function() as bool
dim gfx_ouya_purchase_succeeded as function() as bool
dim gfx_ouya_receipts_request as sub (dev_id as string, key_der as string)
dim gfx_ouya_receipts_are_ready as function () as bool
dim gfx_ouya_receipts_result as function () as string
dim io_init as sub ()
dim io_pollkeyevents as sub ()
dim io_waitprocessing as sub ()
dim io_keybits as sub (byval keybdarray as KeyBits ptr)
dim io_updatekeys as sub (byval keybd as KeyBits ptr)
dim io_enable_textinput as sub (byval enable as integer)
dim io_textinput as sub (byval buf as wstring ptr, byval bufsize as integer)
dim io_get_clipboard_text as function () as zstring ptr
dim io_set_clipboard_text as sub (text as zstring ptr)
dim io_show_virtual_keyboard as sub ()
dim io_hide_virtual_keyboard as sub ()
dim io_show_virtual_gamepad as sub ()
dim io_hide_virtual_gamepad as sub ()
dim io_remap_android_gamepad as sub (byval player as integer, gp as GamePadMap)
dim io_remap_touchscreen_button as sub (byval button_id as integer, byval ohr_scancode as integer)
dim io_running_on_console as function () as bool
dim io_running_on_ouya as function () as bool
dim io_mousebits as sub (byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer, byref mclicks as integer)
dim io_setmousevisibility as sub (byval visible as integer)
dim io_getmouse as sub (byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer)
dim io_setmouse as sub (byval x as integer, byval y as integer)
dim io_mouserect as sub (byval xmin as integer, byval xmax as integer, byval ymin as integer, byval ymax as integer)
dim io_readjoysane as function (byval as integer, byref as uinteger, byref as integer, byref as integer) as integer
dim io_get_joystick_state as function (byval joynum as integer, byval state as IOJoystickState ptr) as integer


'New Surface-based graphics backend function pointers

dim gfx_surfaceCreate as function ( byval width as integer, byval height as integer, byval format as SurfaceFormat, byval usage as SurfaceUsage, byval ppSurfaceOut as Surface ptr ptr) as integer
dim gfx_surfaceCreatePixelsView as function ( byval pixels as any ptr, byval width as integer, byval height as integer, byval pitch as integer, byval format as SurfaceFormat, byval ppSurfaceOut as Surface ptr ptr) as integer
dim gfx_surfaceCreateFrameView as function ( byval pFrameIn as FrameFwd ptr, byval ppSurfaceOut as Surface ptr ptr) as integer
dim gfx_surfaceCreateView as function ( byval pSurfaceIn as Surface ptr, byval x as integer, byval y as integer, byval width as integer, byval height as integer, byval ppSurfaceOut as Surface ptr ptr) as integer
dim gfx_surfaceDestroy as function ( byval ppSurfaceIn as Surface ptr ptr ) as integer
dim gfx_surfaceReference as function ( byval pSurfaceIn as Surface ptr ) as Surface ptr
dim gfx_surfaceUpdate as function ( byval pSurfaceIn as Surface ptr ) as integer
dim gfx_surfaceGetData as function ( byval pSurfaceIn as Surface ptr ) as integer
dim gfx_surfaceFill as function ( byval fillColor as integer, byval pRect as SurfaceRect ptr, byval pSurfaceIn as Surface ptr ) as integer
dim gfx_surfaceFillAlpha as function ( byval fillColor as RGBcolor, byval alpha as double, byval pRect as SurfaceRect ptr, byval pSurfaceIn as Surface ptr ) as integer
dim gfx_surfaceStretch as function ( byval pRectSrc as SurfaceRect ptr, byval pSurfaceSrc as Surface ptr, byval pPalette as RGBPalette ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr ) as integer
dim gfx_surfaceCopy as function ( byval pRectSrc as SurfaceRect ptr, byval pSurfaceSrc as Surface ptr, byval pPalette as RGBcolor ptr, pPal8 as Palette16 ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byref opts as DrawOptions ) as integer

dim gfx_paletteFromRGB as function ( byval pColorsIn as RGBcolor ptr, byval ppPaletteOut as RGBPalette ptr ptr) as integer
dim gfx_paletteDestroy as function ( byval ppPaletteIn as RGBPalette ptr ptr ) as integer
dim gfx_paletteUpdate as function ( byval pPaletteIn as RGBPalette ptr ) as integer

dim gfx_renderQuadColor as sub ( byval pQuad as VertexPC ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )
dim gfx_renderQuadTexture as sub ( byval pQuad as VertexPT ptr, byval pTexture as Surface ptr, byval pPalette as RGBPalette ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )
dim gfx_renderQuadTextureColor as sub ( byval pQuad as VertexPTC ptr, byval pTexture as Surface ptr, byval pPalette as RGBPalette ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )

dim gfx_renderTriangleColor as sub ( byval pTriangle as VertexPC ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )
dim gfx_renderTriangleTexture as sub ( byval pTriangle as VertexPT ptr, byval pTexture as Surface ptr, byval pPalette as RGBPalette ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )
dim gfx_renderTriangleTextureColor as sub ( byval pTriangle as VertexPTC ptr, byval pTexture as Surface ptr, byval pPalette as RGBPalette ptr, byval pRectDest as SurfaceRect ptr, byval pSurfaceDest as Surface ptr, byval pOpts as DrawOptions ptr )

dim gfx_present as function ( byval pSurfaceIn as Surface ptr, byval pPalette as RGBPalette ptr ) as integer

type FnGfxLoad as function cdecl () as integer

declare function gfx_alleg_setprocptrs() as integer
declare function gfx_fb_setprocptrs() as integer
declare function gfx_dummy_setprocptrs() as integer
declare function gfx_sdl_setprocptrs() as integer
declare function gfx_sdl2_setprocptrs() as integer
declare function gfx_console_setprocptrs() as integer
'declare function gfx_sdlpp_setprocptrs() as integer

end extern

type GfxBackendStuff
	'FB doesn't allow initialising UDTs containing var-length strings
	name as string * 7      'Without gfx_ prefix
	alt_name as string * 7  'An alternative name that's also accepted
	libname as string * 15  'Filename from which to load a dyn-linked backend, without extension
	load as FnGfxLoad       'Set function ptrs. Is NULL if the backend is dynamically linked
	wantpolling as bool     'Need allmodex to run the polling thread?
	dylib as any ptr        'Handle for a loaded dynamic library, if any
end type

#ifdef GFX_ALLEG_BACKEND
dim shared as GfxBackendStuff alleg_stuff = ("alleg", "", "", @gfx_alleg_setprocptrs, YES, NULL)
#endif
#ifdef GFX_DIRECTX_BACKEND
dim shared as GfxBackendStuff directx_stuff = ("directx", "", "gfx_directx", NULL, NULL)  'work out wantpolling when loading
#endif
#ifdef GFX_DUMMY_BACKEND
dim shared as GfxBackendStuff dummy_stuff = ("dummy", "", "", @gfx_dummy_setprocptrs, NO, NULL)
#endif
#ifdef GFX_FB_BACKEND
dim shared as GfxBackendStuff fb_stuff = ("fb", "", "", @gfx_fb_setprocptrs, YES, NULL)
#endif
#ifdef GFX_SDL_BACKEND
dim shared as GfxBackendStuff sdl_stuff = ("sdl", "", "", @gfx_sdl_setprocptrs, NO, NULL)
#endif
#ifdef GFX_SDL2_BACKEND
dim shared as GfxBackendStuff sdl2_stuff = ("sdl2", "", "", @gfx_sdl2_setprocptrs, NO, NULL)
#endif
#ifdef GFX_CONSOLE_BACKEND
dim shared as GfxBackendStuff console_stuff = ("console", "", "", @gfx_console_setprocptrs, NO, NULL)
#endif
#ifdef GFX_SDLPP_BACKEND
dim shared as GfxBackendStuff sdlpp_stuff = ("sdl++", "sdlpp", "gfx_sdl", NULL, NO, NULL)
'dim shared as GfxBackendStuff sdlpp_stuff = ("sdl++", "", @gfx_sdlpp_setprocptrs)
#endif

' Alternative spellings allowed
dim shared valid_gfx_backends(...) as string * 10 = {"alleg", "directx", "dummy", "fb", "sdl", "sdl2", "console", "sdlpp", "sdl++"}

dim shared gfx_choices() as GfxBackendStuff ptr
'Initialises gfx_choices with pointers to *_stuff variables, in some build-dependent order
'(you can't initialise arrays with addresses because FB considers them nonconstant)
GFX_CHOICES_INIT

declare function load_backend(which as GFxBackendStuff ptr) as bool
declare sub unload_backend(which as GFxBackendStuff ptr)
declare function lookup_gfx_backend(name as string) as GfxBackendStuff ptr
declare sub default_gfx_render_procs()

dim shared currentgfxbackend as GfxBackendStuff ptr = NULL
dim shared queue_error as string  'queue up errors until it's possible to actually display them (TODO: not implemented)
dim wantpollingthread as bool
dim as string gfxbackend, musicbackend
dim as string gfxbackendinfo, musicbackendinfo
dim as string systeminfo

dim allegro_initialised as bool = NO

extern "C"

#ifdef GFX_DUMMY_BACKEND

'Init functions for gfx_dummy backend. This does NOT set most of the mandatory function pointers,
'so will crash Game/Custom! This backend is only for commandline utilities that need access to allmodex/etc.
'gfx_dummy_init/gfx_dummy_setprocptrs/io_dummy_init are used only by gfx_dummy
function gfx_dummy_init(byval terminate_signal_handler as sub cdecl (), byval windowicon as zstring ptr, byval info_buffer as zstring ptr, byval info_buffer_size as integer) as integer
	return 1
end function

sub io_dummy_init ()
end sub

function gfx_dummy_setprocptrs() as integer
	'Just enough to be able to call setmodex() and get working gfx_Surface* interface.
	gfx_init = @gfx_dummy_init
	io_init = @io_dummy_init
	return 1
end function

#endif

sub gfx_dummy_get_screen_size(wide as integer ptr, high as integer ptr) : *wide = 0 : *high = 0 : end sub
function gfx_dummy_supports_variable_resolution() as bool : return NO : end function
function gfx_dummy_get_resize(byref ret as XYPair) as bool : return NO : end function
function gfx_dummy_set_resizable(enable as bool, min_width as integer, min_height as integer) as bool : return NO : end function
sub gfx_dummy_recenter_window_hint() : end sub
function gfx_dummy_vsync_supported_false() as bool : return NO : end function
function gfx_dummy_vsync_supported_true() as bool : return YES : end function
function gfx_dummy_get_safe_zone_margin() as single : return 0.0 : end function
sub gfx_dummy_set_safe_zone_margin(byval margin as single) : end sub
function gfx_dummy_supports_safe_zone_margin() as bool : return NO : end function
sub gfx_dummy_get_settings (byref settings as GfxSettings) : end sub
sub gfx_dummy_set_settings (settings as GfxSettings) : end sub
sub gfx_dummy_ouya_purchase_request(dev_id as string, identifier as string, key_der as string) : end sub
function gfx_dummy_ouya_purchase_is_ready() as bool : return YES : end function 'returns YES because we don't want to wait for the timeout
function gfx_dummy_ouya_purchase_succeeded() as bool : return NO : end function
sub gfx_dummy_ouya_receipts_request(dev_id as string, key_der as string) : end sub
function gfx_dummy_ouya_receipts_are_ready() as bool : return YES : end function 'returns YES because we don't want to wait for the timeout
function gfx_dummy_ouya_receipts_result() as string : return "" : end function

sub io_dummy_waitprocessing() : end sub
sub io_dummy_pollkeyevents() : end sub
sub io_dummy_updatekeys(byval keybd as integer ptr) : end sub
sub io_dummy_mousebits(byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer, byref mclicks as integer) : end sub
sub io_dummy_getmouse(byref mx as integer, byref my as integer, byref mwheel as integer, byref mbuttons as integer) : end sub
sub io_dummy_enable_textinput(byval enable as integer) : end sub
function io_dummy_get_clipboard_text() as zstring ptr : return NULL : end function
sub io_dummy_set_clipboard_text(text as zstring ptr) : end sub
sub io_dummy_show_virtual_keyboard() : end sub
sub io_dummy_hide_virtual_keyboard() : end sub
sub io_dummy_show_virtual_gamepad() : end sub
sub io_dummy_hide_virtual_gamepad() : end sub
sub io_dummy_remap_android_gamepad(byval player as integer, gp as GamePadMap) : end sub
sub io_dummy_remap_touchscreen_button(byval button_id as integer, byval ohr_scancode as integer) : end sub
function io_dummy_running_on_console() as bool : return NO : end function
function io_dummy_running_on_ouya() as bool : return NO : end function

end extern

'Some parts of the API (function pointers) are optional in all gfx backends.
'Those are set to defaults, most of which do nothing.
'In addition other functions are only allowed to be missing when loading old dynamic
'libraries from before they existed; handled in gfx_load_library[_new]
local sub set_default_gfx_function_ptrs
	default_gfx_render_procs()
	gfx_getversion = NULL
	gfx_Initialize = NULL
	gfx_init = NULL
	gfx_setdebugfunc = NULL
	gfx_get_screen_size = @gfx_dummy_get_screen_size
	gfx_set_window_size = NULL
	gfx_supports_variable_resolution = @gfx_dummy_supports_variable_resolution
	gfx_get_resize = @gfx_dummy_get_resize
	gfx_set_resizable = @gfx_dummy_set_resizable
	gfx_recenter_window_hint = @gfx_dummy_recenter_window_hint
	gfx_vsync_supported = @gfx_dummy_vsync_supported_false
	gfx_get_settings = @gfx_dummy_get_settings
	gfx_set_settings = @gfx_dummy_set_settings
	gfx_printchar = NULL
	gfx_set_safe_zone_margin = @gfx_dummy_set_safe_zone_margin
	gfx_get_safe_zone_margin = @gfx_dummy_get_safe_zone_margin
	gfx_supports_safe_zone_margin = @gfx_dummy_supports_safe_zone_margin
	gfx_ouya_purchase_request = @gfx_dummy_ouya_purchase_request
	gfx_ouya_purchase_is_ready = @gfx_dummy_ouya_purchase_is_ready
	gfx_ouya_purchase_succeeded = @gfx_dummy_ouya_purchase_succeeded
	gfx_ouya_receipts_request = @gfx_dummy_ouya_receipts_request
	gfx_ouya_receipts_are_ready = @gfx_dummy_ouya_receipts_are_ready
	gfx_ouya_receipts_result = @gfx_dummy_ouya_receipts_result
	io_pollkeyevents = @io_dummy_pollkeyevents
	io_waitprocessing = @io_dummy_waitprocessing
	io_keybits = @io_amx_keybits   'Special handling when missing, see gfx_load_library
	io_updatekeys = @io_dummy_updatekeys
	io_enable_textinput = @io_dummy_enable_textinput
	io_textinput = NULL
	io_get_clipboard_text = @io_dummy_get_clipboard_text
	io_set_clipboard_text = @io_dummy_set_clipboard_text
	io_show_virtual_keyboard = @io_dummy_show_virtual_keyboard
	io_hide_virtual_keyboard = @io_dummy_hide_virtual_keyboard
	io_show_virtual_gamepad = @io_dummy_show_virtual_gamepad
	io_hide_virtual_gamepad = @io_dummy_hide_virtual_gamepad
	io_remap_android_gamepad = @io_dummy_remap_android_gamepad
	io_remap_touchscreen_button = @io_dummy_remap_touchscreen_button
	io_running_on_console = @io_dummy_running_on_console
	io_running_on_ouya = @io_dummy_running_on_ouya
	io_mousebits = @io_amx_mousebits   'Special handling when missing, see gfx_load_library
	io_getmouse = @io_dummy_getmouse
	io_readjoysane = NULL
	io_get_joystick_state = NULL
end sub

local function hTRYLOAD(byval hFile as any ptr, byval procedure as any ptr ptr, funcname as string) as bool
	dim tempptr as any ptr = dylibsymbol(hfile, funcname)
	if tempptr <> NULL then *procedure = tempptr
	'Otherwise leave default value of procedure intact
	return tempptr <> NULL
end function
#define TRYLOAD(procedure) hTRYLOAD(hFile, @procedure, #procedure)

#macro MUSTLOAD(procedure)
	procedure = dylibsymbol(hfile, #procedure)
	if procedure = NULL then
		debug filename & " - Could not load required procedure " & #procedure
		dylibfree(hFile)
		return NO
	end if
#endmacro

'Load a dynamically linked gfx backend. Returns true on success
local function gfx_load_library(byval backendinfo as GfxBackendStuff ptr, filename as string) as bool
	dim hFile as any ptr = backendinfo->dylib
	dim needpolling as bool = NO
	if hFile <> NULL then return YES  'Already loaded

	IF backendinfo->name = "directx" THEN
		'override default. TODO: move into gfx_directx
		gfx_vsync_supported = @gfx_dummy_vsync_supported_true
	END IF

	hFile = dylibload(filename)
	if hFile = NULL then return NO

	MUSTLOAD(gfx_getversion)
	dim as integer apiver = gfx_getversion()
	if apiver <> CURRENT_GFX_API_VERSION then
		queue_error = "gfx_version: " & filename & " supports API version " & apiver & " rather than current version " & CURRENT_GFX_API_VERSION
		debug(queue_error)
		dylibfree(hFile)
		hFile = NULL
		return NO
	end if


	' Switching over to new gfx API gradually; accept either init routine.
	' (Although we only support recent gfx_directx which have gfx_Initialize)
	TRYLOAD(gfx_Initialize)
	if gfx_Initialize = NULL then
		MUSTLOAD(gfx_init)
	else
		TRYLOAD (gfx_init)
	end if
	MUSTLOAD(gfx_close)
	TRYLOAD (gfx_setdebugfunc)
	'gfx_getversion already loaded
	MUSTLOAD(gfx_setpal)
	MUSTLOAD(gfx_screenshot)
	MUSTLOAD(gfx_setwindowed)
	MUSTLOAD(gfx_windowtitle)
	MUSTLOAD(gfx_getwindowstate)
	TRYLOAD (gfx_get_screen_size)
	TRYLOAD (gfx_set_window_size)
	TRYLOAD (gfx_supports_variable_resolution)
	TRYLOAD (gfx_get_resize)
	TRYLOAD (gfx_set_resizable)
	TRYLOAD (gfx_recenter_window_hint)
	TRYLOAD (gfx_get_settings)
	TRYLOAD (gfx_set_settings)
	MUSTLOAD(gfx_setoption)
	MUSTLOAD(gfx_describe_options)
	TRYLOAD (gfx_printchar)
	TRYLOAD (gfx_get_safe_zone_margin)
	TRYLOAD (gfx_set_safe_zone_margin)
	TRYLOAD (gfx_supports_safe_zone_margin)
	TRYLOAD (gfx_ouya_purchase_request)
	TRYLOAD (gfx_ouya_purchase_is_ready)
	TRYLOAD (gfx_ouya_purchase_succeeded)
	TRYLOAD (gfx_ouya_receipts_request)
	TRYLOAD (gfx_ouya_receipts_are_ready)
	TRYLOAD (gfx_ouya_receipts_result)
	'WARNING: If you add a new TRYLOAD you must initialize the ptr in set_default_gfx_function_ptrs

	'New rendering API (FIXME: complete this)
	MUSTLOAD (gfx_present)
	'End of new API

	MUSTLOAD(io_init)
	TRYLOAD (io_pollkeyevents)
	TRYLOAD (io_waitprocessing)
	if TRYLOAD(io_keybits) = NO then
		needpolling = YES
	end if
	TRYLOAD (io_updatekeys)
	TRYLOAD (io_enable_textinput)
	TRYLOAD (io_textinput)
	TRYLOAD (io_get_clipboard_text)
	TRYLOAD (io_set_clipboard_text)
	TRYLOAD (io_show_virtual_keyboard)
	TRYLOAD (io_hide_virtual_keyboard)
	TRYLOAD (io_show_virtual_gamepad)
	TRYLOAD (io_hide_virtual_gamepad)
	TRYLOAD (io_remap_android_gamepad)
	TRYLOAD (io_remap_touchscreen_button)
	TRYLOAD (io_running_on_console)
	TRYLOAD (io_running_on_ouya)
	if TRYLOAD(io_mousebits) = NO then
		needpolling = YES
	end if
	MUSTLOAD(io_setmousevisibility)
	TRYLOAD (io_getmouse)
	MUSTLOAD(io_setmouse)
	MUSTLOAD(io_mouserect)
	TRYLOAD (io_readjoysane)
	TRYLOAD (io_get_joystick_state)

	backendinfo->dylib = hFile
	backendinfo->wantpolling = needpolling
	return YES
end function

'(NOT USED - and probably never will be)
'Loads dynamic library graphics backends' procs into memory - new interface.
'Returns true on success
'filename is the name of the file, ie. "gfx_directx.dll" 
'backendinfo is modified with relevant data
local function gfx_load_library_new(byval backendinfo as GfxBackendStuff ptr, filename as string) as bool
	Dim hFile As any ptr
	hFile = dylibload(filename)
	If hFile = NULL Then Return NO

	If TRYLOAD(gfx_GetVersion) = NO Then
		'gfx_GetVersion and gfx_getversion are the same variable, but different functions in hFile
		MUSTLOAD(gfx_getversion)
	End If

	Dim apiVersion As Integer
	apiVersion = gfx_GetVersion()
	If (apiVersion and 2) = 0 Then
		queue_error = filename + " backend does not support v2--reports bitfield " & apiVersion
		debug(queue_error)
		dylibfree(hFile)
		Return NO
	End If

	'backend checks out ok; start loading functions
	MUSTLOAD(gfx_Initialize)
	MUSTLOAD(gfx_Shutdown)
	MUSTLOAD(gfx_SendMessage)
	MUSTLOAD(gfx_PumpMessages)
	'MUSTLOAD(gfx_Present)
	MUSTLOAD(gfx_ScreenShot)
	MUSTLOAD(gfx_SetWindowTitle)
	MUSTLOAD(gfx_GetWindowTitle)
	'MUSTLOAD(gfx_GetWindowState)
	MUSTLOAD(gfx_AcquireKeyboard)
	MUSTLOAD(gfx_AcquireMouse)
	MUSTLOAD(gfx_AcquireJoystick)
	MUSTLOAD(gfx_AcquireTextInput)
	MUSTLOAD(gfx_GetKeyboard)
	MUSTLOAD(gfx_GetText)
	MUSTLOAD(gfx_GetMouseMovement)
	MUSTLOAD(gfx_GetMousePosition)
	MUSTLOAD(gfx_SetMousePosition)
	MUSTLOAD(gfx_GetJoystickMovement)
	MUSTLOAD(gfx_GetJoystickPosition)
	MUSTLOAD(gfx_SetJoystickPosition)

	'success
	backendinfo->dylib = hFile
	backendinfo->wantpolling = NO

	Return YES
End Function

local sub default_gfx_render_procs()
	gfx_surfaceCreate = @gfx_surfaceCreate_SW
	gfx_surfaceCreateView = @gfx_surfaceCreateView_SW
	gfx_surfaceCreatePixelsView = @gfx_surfaceCreatePixelsView_SW
	gfx_surfaceCreateFrameView = @gfx_surfaceCreateFrameView_SW
	gfx_surfaceDestroy = @gfx_surfaceDestroy_SW
	gfx_surfaceReference = @gfx_surfaceReference_SW
	gfx_surfaceUpdate = @gfx_surfaceUpdate_SW
	gfx_surfaceGetData = @gfx_surfaceGetData_SW
	gfx_surfaceFill = @gfx_surfaceFill_SW
	gfx_surfaceFillAlpha = @gfx_surfaceFillAlpha_SW
	gfx_surfaceStretch = @gfx_surfaceStretch_SW
	gfx_surfaceCopy = @gfx_surfaceCopy_SW
	gfx_paletteFromRGB = @gfx_paletteFromRGB_SW
	gfx_paletteDestroy = @gfx_paletteDestroy_SW
	gfx_paletteUpdate = @gfx_paletteUpdate_SW
	gfx_renderQuadColor = @gfx_renderQuadColor_SW
	gfx_renderQuadTexture = @gfx_renderQuadTexture_SW
	gfx_renderQuadTextureColor = @gfx_renderQuadTextureColor_SW
	gfx_renderTriangleColor = @gfx_renderTriangleColor_SW
	gfx_renderTriangleTexture = @gfx_renderTriangleTexture_SW
	gfx_renderTriangleTextureColor = @gfx_renderTriangleTextureColor_SW
end sub

local sub prefer_gfx_backend(b as GfxBackendStuff ptr)
	for i as integer = ubound(gfx_choices) - 1 to 0 step -1
		if gfx_choices(i + 1) = b then swap gfx_choices(i), gfx_choices(i + 1)
	next
end sub

'Set the default gfx backend for load/init_preferred_gfx_backend.
sub prefer_gfx_backend(name as string)
	if not valid_gfx_backend(name) then
		visible_debug "Invalid graphics backend " & name
		exit sub
	end if
	dim bkend as GfxBackendStuff ptr = lookup_gfx_backend(name)
	if bkend then
		prefer_gfx_backend bkend
	else
		debuginfo "prefer_gfx_backend: gfx backend " & name & " isn't available"
	end if
end sub

'If a gfx backend with this name exists, even if not available in this build.
function valid_gfx_backend(name as string) as bool
	for idx as integer = 0 to ubound(valid_gfx_backends)
		if valid_gfx_backends(idx) = name then return YES
	next idx
	return NO
end function

function lookup_gfx_backend(name as string) as GfxBackendStuff ptr
	for idx as integer = 0 to ubound(gfx_choices)
		if gfx_choices(idx)->name = name orelse gfx_choices(idx)->alt_name = name then
			return gfx_choices(idx)
		end if
	next
	return NULL
end function

'If a gfx backend with this name is compiled in. But a shared lib might be missing.
function have_gfx_backend(name as string) as bool
	for idx as integer = 0 to ubound(gfx_choices)
		if gfx_choices(idx)->name = name orelse gfx_choices(idx)->alt_name = name then
			return YES
		end if
	next
	return NO
end function

function backends_setoption(opt as string, arg as string) as integer
	'General backend options.
	'Note: this function always loads a graphics backend, so should be
	'called before gfx_setoption(), and --gfx should be the first option
	if opt = "gfx" then
		if currentgfxbackend <> NULL then
			display_help_string "Can't specify --gfx after a backend is loaded! " _
					    "(The backend is loaded automatically to process " _
					    "unknown commandline options, so put --gfx first)"
			return 2
		end if

		'First check if its a backend which isn't compiled in
		if not valid_gfx_backend(arg) then
			display_help_string """" + arg + """ is not a valid graphics backend"
			return 2
		end if

		dim backendinfo as GfxBackendStuff ptr = lookup_gfx_backend(arg)
		if backendinfo = NULL then
			display_help_string "gfx_" + arg + " support is not enabled in this build"
		else
			prefer_gfx_backend(backendinfo)
			if not load_backend(backendinfo) then
				display_help_string "gfx_" + arg + " could not be loaded!"
				terminate_program
			end if
		end if
		return 2
	else
		load_preferred_gfx_backend
		if opt = "w" or opt = "windowed" then
			gfx_setwindowed(1)
			return 1
		elseif opt = "f" or opt = "fullscreen" then
			gfx_setwindowed(0)
			return 1
		end if
	end if
	return 0
end function

'Returns true on success
local function load_backend(which as GFxBackendStuff ptr) as bool
	if currentgfxbackend = which then return YES
	if currentgfxbackend <> NULL then
		unload_backend(currentgfxbackend)
	end if

	set_default_gfx_function_ptrs()

	if which->load = NULL then
		'Dynamically linked
		dim filename as string = which->libname
#ifdef __FB_WIN32__
		filename += ".dll"
#else
		filename += ".so"   'try other paths?
#endif
		if gfx_load_library(which, filename) = NO then return NO
	else
		'Statically linked
		if which->load() = 0 then return NO
	end if

	if gfx_setdebugfunc then
		gfx_setdebugfunc(@debugc)
	end if

	'FIXME: in the Android port, gfxbackend takes the value "sd"!!

	currentgfxbackend = which
	gfxbackendinfo = ""
	gfxbackend = which->name
	wantpollingthread = which->wantpolling
	return YES
end function

' Does not shut down the backend!
local sub unload_backend(which as GFxBackendStuff ptr)
	if which->dylib then
		dylibfree(which->dylib)
		which->dylib = NULL
	end if
	currentgfxbackend = NULL
	gfxbackendinfo = ""
	gfxbackend = ""
end sub

' Returns true if the desired backend was loaded. It's always the case that
' the backend was shut down and another or the same one was loaded+initialised
' (if not, that's a fatal error).
function switch_gfx_backend(name as string) as bool
	dim backendinfo as GfxBackendStuff ptr = lookup_gfx_backend(name)
	BUG_IF(backendinfo = NULL, "Invalid backend " & name, NO)

	if currentgfxbackend then
		' Set the current as second preference, so we go back to it if switching fails.
		prefer_gfx_backend(currentgfxbackend)

		gfx_close()
		unload_backend(currentgfxbackend)
	end if

	prefer_gfx_backend(backendinfo)
	init_preferred_gfx_backend()

	return currentgfxbackend = backendinfo
end function

' Try to load (but not init) gfx backends in order of preference until one works.
' Noop if one is already loaded.
sub load_preferred_gfx_backend()
	if currentgfxbackend <> NULL then exit sub
	for i as integer = 0 to ubound(gfx_choices)
		if load_backend(gfx_choices(i)) then exit sub
	next
	display_help_string "Could not load any graphic backend! (Who forgot to compile without at least gfx_fb?)"
	terminate_program
end sub

' Try to init gfx backends in order of preference until one works.
' Must not be called if a backend is already initialised!
' Ok to call if one is merely loaded, though.
sub init_preferred_gfx_backend()
	for i as integer = 0 to ubound(gfx_choices)
		with *gfx_choices(i)
			if load_backend(gfx_choices(i)) then
				'currentgfxbackend/etc have now been set; we should either
				'successfully initialize or call unload_backend.

				before_gfx_backend_init

				debuginfo "Initialising gfx_" + .name + "..."
				if gfx_Initialize then
					dim initdata as GfxInitData = ( _
						GFXINITDATA_SZ, @"O.H.R.RPG.C.E.", @"FB_PROGRAM_ICON", _
						@post_terminate_signal, @debugc, @post_event _
					)
					if gfx_Initialize(@initdata) then
						exit sub
					end if
				end if
				if gfx_init then
					dim info_buffer as zstring * 512
					if gfx_init(@post_terminate_signal, "FB_PROGRAM_ICON", @info_buffer, 511) = 0 then
						'TODO: what about the polling thread?
						queue_error = info_buffer
						debug queue_error
					else
						if len(info_buffer) then
							gfxbackendinfo = info_buffer
							debuginfo "gfx_" & gfxbackend & " " & gfxbackendinfo
						end if
						exit sub
					end if
				end if
				unload_backend(gfx_choices(i))
			end if
		end with
	next

	display_help_string "No working graphics backend!"
	terminate_program
end sub

' Load musicbackendinfo, systeminfo
sub read_backend_info()
	'gfx backend not selected yet.

	'Initialise the music backend name because it's static, yet music_init won't have been called yet
	musicbackend = MUSIC_BACKEND
	'musicbackendinfo = "music_" + MUSIC_BACKEND
	musicbackendinfo = music_get_info()

	#ifdef __FB_DARWIN__
		dim as integer response
		'Note that we have to give the OSTypes backwards because we're little-endian
		Gestalt(*cast(integer ptr, @"1sys"), @response)  'gestaltSystemVersionMajor
		systeminfo = "Mac OS " & response & "."
		Gestalt(*cast(integer ptr, @"2sys"), @response)  'gestaltSystemVersionMinor
		systeminfo &= response & "."
		Gestalt(*cast(integer ptr, @"3sys"), @response)  'gestaltSystemVersionBugFix
		systeminfo &= response
	#endif

	#ifdef __FB_WIN32__
		systeminfo = get_windows_runtime_info()
	#endif
end sub

'==============================================================================

sub gfx_backend_menu ()
	dim default_backend as string = read_config_str("gfx.backend")
	redim menu() as string
	for idx as integer = 0 to ubound(gfx_choices)
		dim item as string = "gfx_" & gfx_choices(idx)->name
		'You shouldn't compile Game/Custom with gfx_dummy, it will crash.
		'But in case you make that mistake, hide it.
		if item = "gfx_dummy" then continue for
		if gfx_choices(idx) = currentgfxbackend then
			item &= " (Current)"
		elseif gfx_choices(idx)->name = default_backend then
			'Only shown if you use --gfx to override the default
			item &= " (Selected default)"
		end if
		a_append menu(), item
	next

	dim choice as integer
	choice = multichoice(!"Switch to which graphics backend?\n" _
			     !"(Switching may cause problems)\n" _
			     "Your selection will be remembered for " & exename & DOTEXE, menu())
	if choice > -1 then
		' Due to a FB fixed-len string bug, passing this fixstr directly corrupts it
		dim backendname as string = gfx_choices(choice)->name
		if switch_gfx(backendname) then
			write_config exe_prefix & "gfx.backend", backendname
		else
			notification "Switching failed; the debug log (Shift-F8 to open) might tell why."
		end if
	end if
end sub

'==============================================================================

' Eventually this will let you switch music backends, not just delegate to music_settings_menu
sub music_backend_menu ()
	if music_settings_menu() = NO then
		notification "No adjustable music backend settings"
	end if
end sub
