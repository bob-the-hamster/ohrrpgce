# -*- mode:python -*-
"""Main scons build script for OHRRPGCE
Run "scons -h" to print help (and "scons -H" for options to scons itself).

cf. SConstruct, ohrbuild.py
"""
from __future__ import print_function
import sys
import os
import shlex
import itertools
import re
from ohrbuild import get_command_output
from misc import linux_portability_check
import ohrbuild

# Flags passed to fbc both when compiling and linking
# (Whenever something is added to this you should also add to FBC_CFLAGS if appropriate.)
FBFLAGS = [] #, '-showincludes']

### Compile flags (not used for linking)
# For all C and C++ code (including -gen gcc generated and compiled) except for euc generated
CFLAGS = ['-Wall', '-Wno-deprecated-declarations']  # Complaints about mallinfo()
CFLAGS += ['-fwrapv', '-frounding-math']  # FB may change the rounding mode
# Flags for FBCC (C compiler for -gen gcc generated C), whether passed through fbc or when FBCC
# is invoked directly.
GENGCC_CFLAGS = []
# In addition to GENGCC_CFLAGS, flags for -gen gcc C sources only when we compile them
# manually using FBCC, rather than via fbc. Namely, ones fbc would normally pass automatically.
# To reduce commandlines these are subtracted from CFLAGS before being passed through fbc -Wc.
FBC_CFLAGS = ['-fwrapv', '-frounding-math', '-fno-strict-aliasing']
FBC_CFLAGS += ('-Wno-unused-label -Wno-unused-but-set-variable '
               '-Wno-unused-variable -Wno-unused-function'.split())
# For C we compile by directly invoking FBCC/CC, rather than via "fbc -gen gcc".
# Use gnu99 dialect instead of c99. c99 causes GCC to define __STRICT_ANSI__
# which causes types like off_t and off64_t to be renamed to _off_t and _off64_t
# under MinGW. (See bug 951)
NONFBC_CFLAGS = ['--std=gnu11']
# For C++ (in addition to CFLAGS).
# Can add -fno-exceptions, but only removes ~2KB
CXXFLAGS = '--std=c++0x -Wno-non-virtual-dtor'.split()

### Link flags
# CCLINKFLAGS are passed to $CC when linking with gcc/clang (linkgcc=1, which is the default)
CCLINKFLAGS = []
# FBLINKFLAGS are passed to fbc when linking with fbc (linkgcc=0)
FBLINKFLAGS = []
# FBLINKERFLAGS are passed to the linker (with -Wl) when linking with fbc
FBLINKERFLAGS = []

FRAMEWORKS_PATH = os.path.expanduser("~/Library/Frameworks")  # Frameworks search path in addition to the default /Library/Frameworks

builddir = Dir('.').abspath + os.path.sep
rootdir = Dir('#').abspath + os.path.sep

release = int (ARGUMENTS.get ('release', False))
verbose = int (ARGUMENTS.get ('v', False))
if verbose:
    FBFLAGS += ['-v']
if 'FBFLAGS' in os.environ:
    FBFLAGS += shlex.split (os.environ['FBFLAGS'])
gengcc = int (ARGUMENTS.get ('gengcc', True if release else False))
linkgcc = int (ARGUMENTS.get ('linkgcc', True))   # Link using gcc instead of fbc?

destdir = ARGUMENTS.get ('destdir', '')
prefix =  ARGUMENTS.get ('prefix', '/usr')
dry_run = int(ARGUMENTS.get ('dry_run', '0'))  # Only used by uninstall
buildname = ARGUMENTS.get('buildname', '')
buildtests = int(ARGUMENTS.get ('buildtests', True))
python = ARGUMENTS.get('python', os.environ.get('PYTHON'))
if python == None:
    for name in ('python3', 'python', 'py'):
        pypath = WhereIs(name)
        # Win 10 has dummy python.exe and python3.exe helpers for installing from the Windows Store
        if pypath and 'WindowsApps' not in pypath:
            python = name
            break
    else:
        exit("Python wasn't found. Install Python 3 and ensure python or py is in the PATH.")

base_libraries = []  # libraries shared by all utilities (except bam2mid)

# Set default value for -j/--jobs option
try:
    import multiprocessing  # Python 2.6+
    SetOption('num_jobs', multiprocessing.cpu_count())
except (ImportError, NotImplementedError):
    pass

################ Find FBC

# FBC, the FB compiler, is a ToolInfo object (which can be treated as a string)
FBC = ohrbuild.get_fb_info(ARGUMENTS.get('fbc', os.environ.get('FBC', 'fbc')))

if FBC.version < 1040:
    exit("FreeBASIC 1.04 or later required")

# Headers in fb/ depend on this define
CFLAGS += ['-DFBCVERSION=%d' % FBC.version]

################ Decide the target/OS and cpu arch

# Note: default_arch will be one of x86, x86_64, arm, aarch64, not more specific.
# FBC.default_target will be one of win32, dos, linux, freebsd, darwin, etc
default_arch = FBC.default_arch

host_win32 = sys.platform.startswith('win')

# Target OS/platform (more than one can be True)
win32 = False
unix = False    # True on linux, mac, android, web
mac = False
android = False
web = False     # Emscripten (unix, minos)
minos = False   # Platforms with a minimal OS and no desktop environment, such as web or game consoles.
                # (#define MINIMAL_OS in FB/C/C)
                # Expect that one of win32/unix/... is True telling which OS is most similar.

android_source = False
win95 = int(ARGUMENTS.get ('win95', '0'))
glibc = False  # Computed below; can also be overridden by glibc=1 cmdline argument
default_cc = 'gcc'  # Set by compiler= arg
target = ARGUMENTS.get ('target', None)
cross_compiling = (target is not None)  # Possibly inaccurate, avoid!
arch = ARGUMENTS.get ('arch', None)  # default decided below
wasm = int(ARGUMENTS.get('wasm', 1))
for_node = False
transpile_dir = None

android_source = int(ARGUMENTS.get('android-source', '0'))
if android_source:
    # Transpile to android/tmp
    if not target:  # Does passing target= actually work properly?
        target = 'android'
    android = True
    default_arch = 'arm'
    transpile_dir = 'android/tmp'

transpile_dir = ARGUMENTS.get('transpiledir', transpile_dir)
if transpile_dir:
    transpile_dir = os.path.join(rootdir, transpile_dir)  # Ensure an absolute path
    gengcc = True
    linkgcc = True  # To get CCLINKFLAGS

if not target:
    target = FBC.default_target

# Must check android before linux, because of 'arm-linux-androideabi'
if 'android' in target:
    android = True
elif 'win32' in target or 'windows' in target or 'mingw' in target:
    win32 = True
elif 'darwin' in target or 'mac' in target:
    mac = True
elif 'linux' in target:
    unix = True
    glibc = True
elif 'bsd' in target or 'unix' in target:
    unix = True
elif 'js' in target:
    web = True
    minos = True
    default_cc = 'emcc'  # Emscripten
    for_node = ('node' in target)
    target = 'js-asmjs'  # fbc accepts no synonyms. Actually wasm not asm.js by default.
else:
    print("!! WARNING: target '%s' not recognised!" % target)

if not win32:
    unix = True

target_prefix = ''  # prepended to gcc, etc.
if target.count('-') >= 2:
    target_prefix = target + '-'
    if not arch:
        # Try to recognise it so we know whether we're target
        # This will not recognise all archs used in target triples, that's OK
        arch = target.split('-')[0]

# Determine 'arch', converting it into the particular synonym used by the rest of this script
# (which sometimes differs from the synonym expected by other tools)
if arch == '32':
    if android:
        arch = 'armeabi'  # This might be obsolete?
    elif 'x86' in default_arch:
        arch = 'x86'
    else:
        arch = 'armv7-a'
if arch == '64':
    if 'x86' in default_arch:
        arch = 'x86_64'
    else:
        arch = 'aarch64'
if arch in ('i386', 'i686', '686'):
    # i386 is the name used on Mac, i686 commonly used on Linux, 686 by fbc
    # On PC treat all of these as Pentium 4+ (by requiring SSE2) unless sse2=0 is used,
    # in which case it really is 686 (Pentium Pro+)
    arch = 'x86'
if arch in ('x64',):
    arch = 'x86_64'
if arch in ('armeabi', 'androideabi'):
    # armeabi is an android abi name. ARM EABI is a family of ABIs.
    # For example, in debian ARM EABI (called armel) allows armv4t+.
    arch = 'armv5te'
if arch in ('arm', 'armv7a', 'armeabi-v7a'):
    # Again, armeabi-v7a is an android abi.
    arch = 'armv7-a'
if arch in ('arm64', 'aarch64', 'arm64-v8a'):
    # arm64-v8a is an android abi. aarch64 is the arch name recognised by FB.
    arch = 'aarch64'
if not arch:
    if target_prefix:
        # The arch is implied in the target triple. Let fbc handle it, parsing the
        # triple is too much work
        arch = '(see target)'
    elif web:
        # There are no arch options to fbc. But you can run "scons wasm=0|1|2"
        arch = '(see target)'
    elif android:
        # There are 4 ARM ABIs used on Android
        # armeabi - ARMV5TE and later. All floating point is done by library calls
        #           (aka androideabi, as it is slightly more specific than the ARM EABI)
        #           Removed in ndk r17.
        # armeabi-v7a - ARM V7 and later, has hardware floating point (VFP)
        # armeabi-v7a-hard - not a real ABI. armeabi-v7a with faster passing convention
        #           for floating point values. Not binary compatible with armeabi, support
        #           was dropped in later Android NDK versions.
        # arm64-v8a
        # See https://developer.android.com/ndk/guides/abis.html for more
        arch = 'armv5te'
    else:
        arch = default_arch

if arch == 'x86':
    # x86 only: whether to use SSE2 instructions. These are always available on x86 Mac & Android and on x86_64
    sse2 = int(ARGUMENTS.get('sse2', 1))

# We set gengcc=True if FB will default to it; we need to know whether it's used
if FBC.version >= 1080 and arch == 'x86_64':
    # FB 1.08 adds gas64 backend but doesn't use it yet
    gengcc = True
elif arch != 'x86':
    gengcc = True
if mac:
    gengcc = True

################ Other commandline arguments

tiny = int(ARGUMENTS.get('tiny', 0))

if int (ARGUMENTS.get ('asm', False)):
    FBFLAGS += ["-R", "-RR", "-g"]

pdb = int(ARGUMENTS.get('pdb', 0))
if pdb:
    # fbc -gen gas outputs STABS debug info, gcc outputs DWARF; cv2pdb requires DWARF
    gengcc = True
    if not win32:
        print("pdb=1 only makes sense when targeting Windows")
        Exit(1)

# There are five levels of debug here: 0, 1, 2, 3, 4 (ugh!). See the help.
if release:
    debug = 0
else:
    debug = 2  # Default to happy medium
if tiny:
    debug = 0
if 'debug' in ARGUMENTS:
    debug = int (ARGUMENTS['debug'])
if debug < 2:
    optimisations = 2  # compile with C/C++/FB->C/Euphoria->C optimisations
elif debug == 2:
    optimisations = 1  # compile with C/C++ optimisations
else:
    optimisations = 0
FB_exx = (debug in (2,3))     # compile with -exx?
if debug >= 1 or pdb:
    # If debug=0 and pdb, then the debug info gets stripped later
    FBFLAGS.append ('-g')
    FBC_CFLAGS.append ('-g')
    CFLAGS.append ('-g')
    CCLINKFLAGS.append ('-g')

# Note: fbc includes symbols (but not debug info) in .o files even without -g,
# but strips everything if -g not passed during linking; with linkgcc we need to strip.
linkgcc_strip = (debug == 0 and pdb == 0)  # (linkgcc only) strip debug info and unwanted symbols?

lto = int(ARGUMENTS.get('lto', tiny != 0))  # lto=1 by default in tiny builds, but lto=0 overrides
# Emscripten already uses LTO by default, but these extra args trim a little more off.
if lto:
    CFLAGS.append('-flto')
    # GCC throws many warnings about structs that harmlessly differ between C/FB (only in name?), and warns
    # to use -fno-strict-aliasing. That might actually be needed despite the declarations being equivalent.
    CFLAGS.append('-fno-strict-aliasing')   # Already in FBC_CFLAGS, fbc always passes it.
    CCLINKFLAGS += ['-fno-strict-aliasing', '-Wno-lto-type-mismatch']
    #CCLINKFLAGS.append('-flto')  # Shouldn't actually be needed?
    if 'x86' in arch:
        # The default Intel syntax results in link-time asm errors like "Error: junk `(%rbp)' after expression"
        FBFLAGS += ['-asm', 'att']

if not tiny and not lto:
    # Make sure we can print stack traces
    # Also -O2 plus profiling crashes for me due to mandatory frame pointers being omitted.
    CFLAGS.append('-fno-omit-frame-pointer')

# glibc=0|1 overrides automatic detection
glibc = int(ARGUMENTS.get ('glibc', glibc))
if glibc:
    CFLAGS += ["-DHAVE_GLIBC"]
    if not tiny or debug :
        # This includes symbols which are used by glibc's backtrace_symbols() function
        # (unlike GDB backtraces which are created using debug info, and sadly GDB doesn't
        # try to use these symbols)
        # Unfortunately it even puts in symbols for functions that don't exist because they
        # were dead code or always inlined (especially in LTO builds)
        CCLINKFLAGS.append('-Wl,--export-dynamic')
        FBLINKERFLAGS.append('--export-dynamic')

portable = False
if release and unix and not mac and not android and not web:
    portable = True
portable = int (ARGUMENTS.get ('portable', portable))

profile = int (ARGUMENTS.get ('profile', 0))
if profile:
    FBFLAGS.append ('-profile')
    FBC_CFLAGS.append ('-pg')
    CFLAGS.append ('-pg')
    CCLINKFLAGS.append ('-pg')
if int (ARGUMENTS.get ('valgrind', 0)):
    #-exx under valgrind is nearly redundant, and really slow
    FB_exx = False
    # This changes memory layout of vectors to be friendlier to valgrind
    CFLAGS.append ('-DVALGRIND_ARRAYS')
asan = int (ARGUMENTS.get ('asan', 0))
if asan:
    # AddressSanitizer is supported by both gcc & clang. They are responsible for linking runtime library
    assert linkgcc, "linkgcc=0 asan=1 combination not supported."
    CFLAGS.append ('-fsanitize=address')
    CCLINKFLAGS.append ('-fsanitize=address')
    base_libraries.append ('m')
    # Also, compile FB to C by default, unless overridden with gengcc=0.
    if int (ARGUMENTS.get ('gengcc', 1)):
        gengcc = True
        FB_exx = False  # Superceded by AddressSanitizer

if tiny:
    gengcc = True
    CFLAGS.append('-Os')
    CXXFLAGS.append('-fno-exceptions')  # Just a few bytes
    CCLINKFLAGS.append('-Os')  # For LTO
elif optimisations:
    CFLAGS.append ('-O3')
    # (Under Emscripten, linking with -O1 is a lot slower than both -O0 and -O2. -O0 is not much faster
    # But can't link ohrrpgce-game with -O0, at least debug builds: too many locals.)
    CCLINKFLAGS.append ('-O2')  # For LTO
    if optimisations > 1:
        # Also optimise FB code. Only use -O2 instead of -O3 because -O3 produces about 10% larger
        # binaries (before and after compression) but most of the performance critical stuff is in
        # (non-generated) .c/.cpp files anyway; even the improvement in HS benchmarks is only about 3%.
        FB_O = '2'
        if android:
            # For Android all C is compiled with same flags (including FBC_CFLAGS) so we want to use -O3
            FB_O = '3'
        # FB optimisation flag currently does pretty much nothing except passed on to -gen gcc.
        FBFLAGS += ['-O', FB_O]
        FBC_CFLAGS.append ('-O' + FB_O)
else:
    CFLAGS.append ('-O0')

# Help dead code stripping. (This helps a lot even in LTO builds!)
# Not useful when using emscripten, which has proper dead code stripping
if not web:
    CFLAGS += ['-ffunction-sections', '-fdata-sections']

# Backend selection.
if 'gfx' in ARGUMENTS:
    gfx = ARGUMENTS['gfx']
elif 'OHRGFX' in os.environ:
    gfx = os.environ['OHRGFX']
elif mac or web:
    gfx = 'sdl2'
elif android:
    gfx = 'sdl'
elif win32:
    if win95:
        gfx = 'directx+sdl+fb'
    else:
        gfx = 'sdl2+directx+fb'
else: # unix
    gfx = 'sdl2+fb'
gfx = [g.lower() for g in gfx.split("+")]
if 'music' in ARGUMENTS:
    music = ARGUMENTS['music']
elif 'OHRMUSIC' in os.environ:
    music = os.environ['OHRMUSIC']
elif 'sdl' in gfx:
    music = 'sdl'
else:
    music = 'sdl2'
music = [music.lower()]

# You can link both gfx_sdl and gfx_sdl2, but one of SDL 1.2, SDL 2 will
# be partially shadowed by the other and will crash. Need to use dynamic linking. WIP.
if 'sdl' in music+gfx and 'sdl2' in music+gfx:
    print("Can't link both sdl and sdl2 music or graphics backends at same time")
    Exit(1)

if win95 and 'sdl2' in music+gfx:
    print("SDL2 (gfx_sdl2/music_sdl2) doesn't support Windows 2000 or older")
    Exit(1)


################ Create base environment

envextra = {}
if win32:
    # Force use of gcc instead of MSVC++, which we don't support (e.g. different compiler flags)
    envextra = {'tools': ['mingw']}
env = Environment (CFLAGS = [],
                   CXXFLAGS = [],
                   VAR_PREFIX = '',
                   **envextra)

# Shocked that scons doesn't provide $HOME
# $DISPLAY is need for both gfx_sdl and gfx_fb (when running tests)
# FB 1.11 supports $SOURCE_DATE_EPOCH
for var in 'PATH', 'DISPLAY', 'HOME', 'EUDIR', 'WINEPREFIX', 'SOURCE_DATE_EPOCH':
    if var in os.environ:
        env['ENV'][var] = os.environ[var]
for var in 'AS', 'CC', 'CXX':
    if var in os.environ:
        # Make a File object so scons escapes spaces in paths
        env['ENV'][var] = File(os.environ[var])
# env['ENV']['GCC'] is set below


################ Find tools other than FBC
# TODO: FBC should be in the same section

# If you want to use a different C/C++ compiler do "CC=... CXX=... scons ...".
# If CC is clang, you may want to set FBCC too.
default_cc = ARGUMENTS.get('compiler', default_cc)
mod = globals()
CC = ohrbuild.findtool(mod, 'CC', default_cc)
if not CC:
    CC = ohrbuild.findtool(mod, (), 'cc')
    if not CC:
        exit("Missing a C compiler! (Couldn't find " + default_cc + " nor cc in PATH, nor is CC set. Can also try compiler=clang.)")
# FBCC is the compiler used for fbc-generated C code (gengcc=1).
FBCC = ohrbuild.findtool(mod, ('FBCC', 'GCC'), default_cc)
if not FBCC: FBCC = CC
# emc++ exists but we don't need to use it
default_cxx = {'gcc':'g++', 'clang':'clang++', 'emcc':'emcc'}.get(default_cc, 'g++')
CXX = ohrbuild.findtool(mod, 'CXX', default_cxx)
if not CXX:
    CXX = ohrbuild.findtool(mod, (), 'c++')
    if not CXX:
        exit("Missing a C++ compiler! (Couldn't find " + default_cxx + " nor c++ in PATH, nor is CXX set.)")

EUC = ohrbuild.findtool(mod, 'EUC', "euc")  # Euphoria to C compiler (None if not found)
EUBIND = ohrbuild.findtool(mod, 'EUBIND', "eubind")  # Euphoria binder (None if not found)

MAKE = ohrbuild.findtool(mod, 'MAKE', 'make')
if not MAKE and win32:
    MAKE = ohrbuild.findtool(mod, 'MAKE', 'mingw32-make')

# Replace CC and FBCC with ToolInfo objects (which can still be treated as strings)
CC = ohrbuild.get_cc_info(CC)
FBCC = CC if CC.path == FBCC else ohrbuild.get_cc_info(FBCC)

if 'FBCC' not in env['ENV']:
    if 'compiler' not in ARGUMENTS and CC.is_gcc:
        # Copy CC to FBCC if CC is gcc.
        # Using clang for -gen gcc is experimental (fbc doesn't officially support it)
        # so don't use clang unless explicitly requested with compiler=...
        # Note: GCC in env['ENV'] mostly isn't used when compiling when FBCC.is_clang, because fbc only produces .c files
        FBCC = CC
# fbc uses GCC variable for -gen gcc, doesn't check CC. Renamed to FBCC in this script for less confusion.
env['ENV']['GCC'] = FBCC.path

# This may look redundant, but it's so $MAKE, etc in command strings work, as opposed to setting envvars.
for tool in ('FBC', 'CC', 'FBCC', 'CXX', 'MAKE', 'EUC', 'EUBIND'):
    val = globals()[tool]
    if val:
        if not isinstance(val, ohrbuild.ToolInfo):
            val = File(val)
        env[tool] = val


################ Define Builders and Scanners for FreeBASIC and ReloadBasic

FBFLAGS += ['-i', builddir]  # For backendinfo.bi

def prefix_targets(target, source, env):
    target = [File(env['VAR_PREFIX'] + str(a)) for a in target]
    return target, source

def translate_rb(source):
    if source.endswith('.rbas'):
        return env.RB(source)
    return File(source)


if portable and unix and glibc:
    # Only implemented on GNU
    def check_lib_reqs(source, target, env):
        for targ in target:
            linux_portability_check.check_deps(str(targ))
    check_binary = Action(check_lib_reqs, None)  # Action wrapper which prints nothing
else:
    check_binary = None


def bas_build_action(moreflags = ''):
    "Actions to compile .bas to .o/.obj or to .c"
    if transpile_dir:
        return ['$FBC $FBFLAGS -r $SOURCE -o $TARGET ' + moreflags]

    if gengcc and FBCC.is_clang and not web:
        # fbc asks FBCC to produce assembly and then runs that through as,
        # but clang produces some directives that as doesn't like.
        # So we do the .c -> asm step ourselves.
        # NOTE: $CFLAGS in the env = CFLAGS + NONFBC_CFLAGS in Python.
        return ['$FBC $FBFLAGS -r $SOURCE -o ${TARGET}.c ' + moreflags,
                '$FBCC $CFLAGS $FBC_CFLAGS $GENGCC_CFLAGS -c ${TARGET}.c -o $TARGET']
    else:
        # In this case FBC_CFLAGS isn't needed (fbc passes them automatically),
        # and GENGCC_CFLAGS has already been added into FBFLAGS with -Wc.
        return '$FBC $FBFLAGS -c $SOURCE -o $TARGET ' + moreflags

def compile_bas_modules(target, source, env):
    """
    This is the emitter for BASEXE when using linkgcc: it compiles sources if needed, where
    the first specified module is the main module (-m flag), and rest are regular modules,
    matching behaviour of passing .bas's to fbc.
    """
    for i, obj in enumerate(source):
        if str(obj).endswith('.bas'):
            if i == 0:
                source[i] = env.BASMAINO(obj)
            else:
                source[i] = env.BASO(obj)
    return target, source


if transpile_dir:
    out_suffix = '.c'
else:
    out_suffix = '.o'

if win32:
    exe_suffix = '.exe'
elif web:
    if for_node:
        exe_suffix = '.js'
    else:
        exe_suffix = '.html'
else:
    exe_suffix = ''

#variant_baso creates Nodes/object files with filename prefixed with VAR_PREFIX environment variable
variant_baso = Builder (action = bas_build_action(),
                        suffix = out_suffix, src_suffix = '.bas', single_source = True, emitter = prefix_targets,
                        source_factory = translate_rb)
baso = Builder (action = bas_build_action(),
                suffix = out_suffix, src_suffix = '.bas', single_source = True,
                source_factory = translate_rb)
basmaino = Builder (action = bas_build_action('-m ${SOURCE.filebase}'),
                    suffix = out_suffix, src_suffix = '.bas', single_source = True,
                    source_factory = translate_rb)

def SrcFile(env, src):
    """Replacement for env.Object(). src is an .bas/.rbas/.c/.cpp/etc file.
    Either compile to an object file, or transpile FB to .c and leave others alone."""
    if transpile_dir:
        if '.bas' in str(src):
            return env.BASO(src)  # Transpiles
        else:
            return File(src)  # Do nothing
    else:
        return env.Object(src)

if transpile_dir:
    copy_sources = Builder(generator = ohrbuild.copy_source_actions,
                           emitter = compile_bas_modules,
                           source_factory = translate_rb)
    env['TRANSPILE_DIR'] = transpile_dir
    env.Append(BUILDERS = {'COPY_SOURCES':copy_sources})

if not linkgcc:
    # Linking with fbc.
    # Because fbc < 1.07 ignores all but the last -Wl flag, have to concatenate them.
    basexe = Builder (action = ['$FBC $FBFLAGS -x $TARGET $SOURCES $FBLINKFLAGS ${FBLINKERFLAGS and "-Wl " + ",".join(FBLINKERFLAGS)}',
                                check_binary],
                      suffix = exe_suffix, src_suffix = '.bas',
                      source_factory = translate_rb)
else:
    # linkgcc's basexe is defined below.
    basexe = None

# Surely there's a simpler way to do this
def depend_on_reloadbasic_py(target, source, env):
    return (target, source + ['reloadbasic/reloadbasic.py'])

rbasic_builder = Builder (action = [[python, File('reloadbasic/reloadbasic.py'), '--careful', '$SOURCE', '-o', '$TARGET']],
                          suffix = '.rbas.bas', src_suffix = '.rbas', emitter = depend_on_reloadbasic_py)

# windres is part of mingw.
# FB includes GoRC.exe, but finding that file is too much trouble...
rc_builder = Builder (action = target_prefix + 'windres --input $SOURCE --output $TARGET',
                      suffix = '.obj', src_suffix = '.rc')

bas_scanner = Scanner (function = ohrbuild.basfile_scan,
                       skeys = ['.bas', '.bi'], recursive = True, argument = builddir)
hss_scanner = Scanner (function = ohrbuild.hssfile_scan,
                       skeys = ['.hss', '.hsi', '.hsd'], recursive = True)

env['BUILDERS']['Object'].add_action ('.bas', bas_build_action())
# These are needed for Object() auto-dependency detection
SourceFileScanner.add_scanner ('.bas', bas_scanner)
SourceFileScanner.add_scanner ('.bi', bas_scanner)
SourceFileScanner.add_scanner ('.hss', hss_scanner)

env.Append (BUILDERS = {'BASEXE':basexe, 'BASO':baso, 'BASMAINO':basmaino, 'VARIANT_BASO':variant_baso,
                        'RB':rbasic_builder, 'RC':rc_builder},
            SCANNERS = [bas_scanner, hss_scanner])


################ Mac SDKs

if mac:
    macsdk = ARGUMENTS.get ('macsdk', '')
    macSDKpath = ''
    if os.path.isdir(FRAMEWORKS_PATH):
        FBLINKERFLAGS += ['-F', FRAMEWORKS_PATH]
        CCLINKFLAGS += ['-F', FRAMEWORKS_PATH]
    # OS 10.4 is the minimum version supported by SDL 1.2.14 on x86 (README.MacOSX
    # in the SDL source tree seems to be out of date, it doesn't even mention x86_64)
    # and OS 10.6 is the minimum for x86_64. 10.6 was released 2009
    # (See https://playcontrol.net/ewing/jibberjabber/big_behind-the-scenes_chang.html)
    # Note: if we wanted to build a x86/x86_64 fat binary that runs on < 10.6, we need
    # to add LSMinimumSystemVersionByArchitecture to the plist, see above link.
    # Our FB Mac fork also currently targets OS 10.4.
    macosx_version_min = '10.4'
    if 'sdl2' in gfx+music:
        # The minimum target supported by SDL 2 for x86 & x64 is 10.6,
        # although SDL 2.0.4 and earlier only required 10.5 on x86
        # requires SDK 10.7+ to compile.
        macosx_version_min = '10.6'
    if arch == 'x86_64':
        macosx_version_min = '10.6'  # Both SDL 1.2 & 2.0
        # (though OS 10.5 is the first to support x86_64 Cocoa apps)
    if macsdk:
        if macsdk == '10.4':
            # 10.4 has a different naming scheme
            macSDKpath = 'MacOSX10.4u.sdk'
        else:
            # There is also /System/Developer/CommandLineTools/SDKs/MacOSX.sdk/
            macSDKpath = 'MacOSX' + macsdk + '.sdk'
        macSDKpath = '/Developer/SDKs/' + macSDKpath
        if not os.path.isdir(macSDKpath):
            raise Exception('Mac SDK ' + macsdk + ' not installed: ' + macSDKpath + ' is missing')
        macosx_version_min = macsdk
        CCLINKFLAGS += ["-isysroot", macSDKpath]  # "-static-libgcc", '-weak-lSystem']
    CFLAGS += ['-mmacosx-version-min=' + macosx_version_min]
    FBLINKERFLAGS += ['-mmacosx-version-min=' + macosx_version_min]
    CCLINKFLAGS += ['-mmacosx-version-min=' + macosx_version_min]
    if macosx_version_min != '10.4':
        # SDL 1.2.15+ (and SDL_mixer) uses @rpath in its load path, so the executable now needs
        # to contain an rpath. (Fix for bug #1113) @rpath was added in Mac OS 10.5. This is why
        # SDL 1.2.15 sets macOS 10.5 as the minimum. We're still using SDL 1.2.14 for 32-bit builds.
        FBLINKERFLAGS += ['-rpath,@executable_path/../Frameworks']
        CCLINKFLAGS += ['-Wl,-rpath,@executable_path/../Frameworks']


################ Cross-compiling and arch-specific stuff

if not web:
    FBFLAGS += ['-mt']  # Multithreaded FB runtime

if target:
    FBFLAGS += ['-target', target]

NO_PIE = '-no-pie'
if android:
    # Android 5.0+ will only run PIE exes, for security reasons (ASLR).
    # However, only Android 4.1+ (APP_PLATFORM android-16) support  PIE exes!
    # This only matters for compiling test cases.
    # A workaround is to use a tool to load a PIE executable as a library
    # and run it on older Android:
    #https://chromium.googlesource.com/chromium/src/+/32352ad08ee673a4d43e8593ce988b224f6482d3/tools/android/run_pie/run_pie.c
    CCLINKFLAGS += ["-pie"]
elif not win32:
    # Recent versions of some linux distros, such as debian and arch, config
    # gcc to default to PIE on non-x86, but our linkgcc code isn't written
    # to support PIE, causing ld 'relocation' errors. Simplest solution is
    # to disable PIE.
    # (Assuming if FBCC is clang then CC is too)
    if mac:
        # -no_pie (no position-independent execution) fixes a warning
        # (Using -Wl supports very old gcc)
        NO_PIE = '-Wl,-no_pie'
    elif FBCC.is_gcc and FBCC.version < 500:
        # gcc 4.9 apparently doesn't have -nopie, so I assume it was added in 5.x
        NO_PIE = None
    elif FBCC.is_gcc and FBCC.version < 540:
        # -no-pie was added in gcc 6.
        # But on Ubuntu 16.04 -no-pie exists in gcc 5.4.
        # Some builds of gcc 5.x (but not stock gcc 5.4.0) support -nopie.
        NO_PIE = '-nopie'
    elif FBCC.is_clang and FBCC.version < 400:
        NO_PIE = None
    elif FBCC.is_clang and FBCC.version < 500:
        # -no-pie was added to clang in July 2017, which I think is clang 5.0
        # while -nopie was added Oct 2016 (4.0).
        # Recent clang accepts both, recent gcc only accepts -no-pie
        NO_PIE = '-nopie'
    if NO_PIE:
        # -no-pie is a gcc/clang flag affecting linking. -fno-pie affects code
        # generation, and it seems neither implies the other. -fno-pie has been
        # around a long time (at least GCC 4.9, Clang 3.7).
        CFLAGS += ['-fno-pie']
        # -no_pie is only needed when CXX does the linking, not with linkgcc=0,
        # since apparently it's gcc, not ld, which is defaulting to PIE
        CCLINKFLAGS += [NO_PIE]

if arch == 'armv5te':
    # FB puts libraries in 'arm' folder
    FBFLAGS += ["-arch", arch]
elif arch == 'armv7-a':
    FBFLAGS += ["-arch", arch]
elif arch == 'aarch64':
    FBFLAGS += ["-arch", arch]
elif arch == 'x86':
    FBFLAGS += ["-arch", "686"]  # "x86" alias not recognised by FB yet
    FBC_CFLAGS.append ('-m32')
    CFLAGS.append ('-m32')
    CCLINKFLAGS.append ('-m32')
    if (FBC.version < 1060 or (win32 and sse2)) and CC.is_gcc and gengcc == False:
        # Linux x86 (see GCC bug 40838) and Mac OSX ABIs require the stack be kept 16-byte
        # aligned but fbc's GAS backend wasn't updated for that ABI change until FB 1.06.
        # Additionally, work around GCC bug https://gcc.gnu.org/bugzilla/show_bug.cgi?id=56597
        # (present at least in mxe's GCC 5.5.0) where GCC assumes 16-byte stack alignment on x86
        # Windows too, although the stack is only 4-byte aligned there (GCC aligns the stack
        # in/before main() and assumes you don't link to code generated by any other compiler).
        # I don't know what clang does, but it has -mstack-alignment= instead of these options.
        #CFLAGS.append ('-mpreferred-stack-boundary=2')
        CFLAGS.append ('-mincoming-stack-boundary=2')
    # On Intel Macs, SSE2 is both always present and required by system headers.
    if mac:
        sse2 = True
    if sse2:
        CFLAGS += ['-msse2']
        # We effectively require pentium4+, but adding -march=pentium4 or even
        # -march=pentium4 -mtune=generic can generate slower code and break GCC 10's autovectoriser
    else:
        # gcc -m32 on a x86_64 host defaults to enabling SSE & SSE2, explicitly disable
        CFLAGS += ['-mno-sse', '-DNO_SSE']
        FBFLAGS += ['-d', 'NO_SSE']
        # Note that if using gengcc=0, fbc doesn't emit SSE2 (unless you pass '-fpu sse'),
        # so don't need to pass anything to fbc

elif arch == 'x86_64':
    FBFLAGS += ["-arch", arch]
    FBC_CFLAGS.append ('-m64')
    CFLAGS.append ('-m64')
    CCLINKFLAGS.append ('-m64')
    # This also causes older FB to default to -gen gcc, as -gen gas not supported
    # (but FB 1.08 added -gen gas64)
    # (therefore we don't need to pass -mpreferred-stack-boundary=2)
elif arch == '(see target)':
    pass  # We let fbc figure it out from the target
elif arch == default_arch:
    # This happens on 32bit arm platforms, where default_arch == 'arm'.
    # We don't need to know a more specific CPU arch, we only need that
    # for the ABI when compiling for Android.
    pass
else:
    print("Error: Unknown architecture %s" % arch)
    Exit(1)


print("Using target:", target, " arch:", arch, " fbc:", FBC.describe(), " fbcc:", FBCC.describe(), " cc:", CC.describe(), " cctarget:", CC.target)

# If cross compiling, do a sanity test
# If it contains two dashes it looks like a target triple
# (FIXME: newer clang-based NDKs have wrapper scripts named like aarch64-linux-android21-clang
# which is not the same as the target-triple clang actually prints, so this breaks)
if target_prefix and target_prefix != CC.target + '-':
    print("Error: This CC doesn't target " + target_prefix)
    print ("You need to either pass 'target' as a target triple (e.g. target=arm-linux-androideabi) and "
           "ensure that the toolchain executables (e.g. arm-linux-androideabi-gcc) "
           "are in your PATH, or otherwise set CC, CXX, and AS environmental variables.")
    Exit(1)

if 'x86' in arch and gengcc:
    if FBCC.is_clang:
        # Currently needed on x86 only: fbc outputs some asm which clang doesn't like (-masm=intel doesn't help)
        FBFLAGS += ['-asm', 'att']
    else:
        FBC_CFLAGS += ['-masm=intel']

# Add FBFLAGS for -gen gcc builds, including flags passed to C compiler
if gengcc:
    FBFLAGS += ["-gen", "gcc"]
    if FBCC.is_clang:
        # -exx (in fact -e) causes fbc to use computed gotos which clang can't compile
        # due to https://bugs.llvm.org/show_bug.cgi?id=18658
        FB_exx = False
    if FBCC.is_gcc:
        if FBCC.version >= 900 and FBC.version < 1080:
            # Workaround an error. See https://sourceforge.net/p/fbc/bugs/904/
            GENGCC_CFLAGS.append ('-Wno-format')
        if FBCC.version >= 1000:
            # And another problem due to gcc 10+ being very picky about equivalent types (c.f. FB bug sf#904)
            GENGCC_CFLAGS.append('-Wno-builtin-declaration-mismatch')
        # -exx results in a lot of labelled goto use, which confuses gcc 4.8+, which tries harder to throw this warning
        # (This flag only recognised by recent gcc)
        if FBCC.version >= 480:
            GENGCC_CFLAGS.append ('-Wno-maybe-uninitialized')
            # (The following is not in gcc 4.2)
            # Ignore warnings due to using an array lbound > 0
            GENGCC_CFLAGS.append ('-Wno-array-bounds')
        # Ignore annoying warning https://sourceforge.net/p/fbc/bugs/936/
        GENGCC_CFLAGS.append ('-Wno-missing-braces')
    if FBCC.is_clang:
        # clang doesn't like fbc's declarations of standard functions
        # (although FB 1.20 fixes most incompatible-library-redeclaration warnings)
        GENGCC_CFLAGS += ['-Wno-builtin-requires-header', '-Wno-incompatible-library-redeclaration']

    tmp = CFLAGS + GENGCC_CFLAGS
    # Drop everything fbc passes automatically
    #print("Dropping from CFLAGS, in FBC_CFLAGS:", set(tmp).intersection(FBC_CFLAGS))
    #print("In FBC_CFLAGS, not in CFLAGS:", set(FBC_CFLAGS).difference(tmp))
    tmp = [f for f in tmp if f not in FBC_CFLAGS]
    # Drop all defines, because there are no #includes or #ifs in the generated code
    tmp = [f for f in tmp if not f.startswith('-D')]
    if len(tmp):
        # NOTE: You can only pass -Wc (which passes flags on to gcc) once to fbc <=1.06; the last -Wc overrides others!
        # fbc <=1.07 has a limit of 127 characters for -Wc arguments (gh#298), so stop the build from breaking
        # if we exceed the limit by removing final args, which are assumed to be least important.
        if FBC.version < 1080:
            while len(','.join(tmp)) > 127:
                print("WARNING: due to bug in old fbc, dropping arg -Wc %s" % tmp[-1])
                tmp.pop()
        FBFLAGS += ["-Wc", ','.join(tmp)]

if mac:
    # Doesn't have --gc-sections. This is similar, but more aggressive than --gc-sections
    CCLINKFLAGS += ['-Wl,-dead_strip']
else:
    # --gc-sections decreases filesize, but unfortunately doesn't remove symbols for dropped sections,
    # not even with -flto or --strip-discarded!
    CCLINKFLAGS += ['-Wl,--gc-sections']

if FB_exx:
    FBFLAGS.append ('-exx')


################ A bunch of stuff for linking

if linkgcc:
    # Link using g++ instead of fbc; this makes it easy to link correct C++ libraries, but harder to link FB

    # Find the directory where the FB libraries are kept.
    # Take the last line, in case -v is in FBFLAGS
    libpath = get_command_output(FBC.path, ["-print", "fblibdir"] + FBFLAGS).split('\n')[-1]

    # Sanity check that FB supports this target/arch
    # Some FB targets (win32) don't have PIC libs, android only has PIC libs
    # (libfb is always built while libfbmt is optional)
    checkfile = os.path.join (libpath, 'libfb.a')
    checkfile2 = os.path.join (libpath, 'libfbpic.a')
    if not os.path.isfile (checkfile) and not os.path.isfile (checkfile2):
        print("Error: This installation of FreeBASIC doesn't support this target-arch combination;\n" + checkfile + " [or libfbpic.a] is missing.")
        Exit(1)

    # This causes ld to recursively search the dependencies of linked dynamic libraries
    # for more dependencies (specifically SDL on X11, etc)
    # Usually the default, but overridden on some distros. Don't know whether GOLD ld supports this.
    if not mac and not web:
        CCLINKFLAGS += ['-Wl,--add-needed']

    # FB libs
    # Passing this -L option straight to the linker is necessary, otherwise gcc gives it
    # priority over the default library paths, which on Windows means using FB's old mingw libraries
    if android:
        # See NO_PIE discussion above
        CCLINKFLAGS += ['-Wl,-L' + libpath, os.path.join(libpath, 'fbrt0pic.o'), '-lfbmtpic']
    elif web:
        CCLINKFLAGS += ['-Wl,-L' + libpath, '-lfb']
    else:
        CCLINKFLAGS += ['-Wl,-L' + libpath, os.path.join(libpath, 'fbrt0.o'), '-lfbmt']

    if verbose:
        CCLINKFLAGS += ['-v']
    if linkgcc_strip:
        # Strip debug info but leave in the function (and unwanted global) symbols.
        # Result is about 600KB larger than a full strip, and after running
        # strip_unwanted_syms below, down to 280KB.
        CCLINKFLAGS += ['-Wl,-S']
    if win32:
        # win32\ld_opt_hack.txt contains --stack option which can't be passed using -Wl
        CCLINKFLAGS += ['-static-libgcc', '-static-libstdc++', '-Wl,@win32/ld_opt_hack.txt']
        CCLINKFLAGS += ['-l', ':libstdc++.a']
    else:
        CCLINKFLAGS += ['-lstdc++']
        # Android doesn't have ncurses, and libpthread is part of libc
        # web builds don't use threads
        if not android and not web:
            # The following are required by libfb (not libfbgfx)
            CCLINKFLAGS += ['-lpthread']
            # Some Linux systems have only libncurses.so.5, others only libncurses.so.6
            # (since ~2015), and some have libtinfo.so while others don't. Probably same mess on BSD.
            # So don't link to libncurses/libtinfo. Instead we link to lib/termcap_stub.c below.
            # Don't know about Mac situation.
            if not portable or mac:
                CCLINKFLAGS += ['-lncurses']

    if web:
        if not for_node:
            if False:
                # Maybe use FB's default shell for commandline programs
                CCLINKFLAGS += ['--shell-file', os.path.join(libpath, 'fb_shell.html'), os.path.join(libpath, 'termlib_min.js')]
            else:
                CCLINKFLAGS += ['--shell-file', 'web/ohrrpgce-shell-template.html']
        # JS support routines for FB's console mode emulation, using termlib.js, which unlike fbc/linkgcc=0, we leave out.
        # So could replace this with stubs, but it's only small.
        CCLINKFLAGS += ['--post-js', os.path.join(libpath, 'fb_rtlib.js')]

    if pdb:
        # Note: to run cv2pdb you need Visual Studio or Visual C++ Build Tools installed,
        # but not necessarily in PATH. (Only a few dlls and mspdbsrv.exe actually needed.)
        # By default cv2pdb modifies the exe in-place, stripping DWARF debug info,
        # pass NUL as second argument to throw away the stripped copy.
        handle_symbols = os.path.join('support', 'cv2pdb') + exe_suffix + ' $TARGET '
        # Actually, we need to always strip the debug info, because cv2pdb puts the GUID
        # of the .pdb in the exe at the same time, without which the .pdb doesn't work.
        # It would be possible to modify cv2pdb to add the GUID without stripping
        # (by modifying PEImage::replaceDebugSection())
        strip = True  #debug > 0
        if strip == False:
            # Do not strip
            handle_symbols += 'NUL'
        else:
            handle_symbols += '$TARGET'
        handle_symbols += ' win32/${TARGET.filebase}.pdb'
        if not host_win32:
            handle_symbols = 'WINEDEBUG=fixme-all wine ' + handle_symbols
            # If cv2pdb fails (because Visual Studio is missing) continue without error
            handle_symbols += " || true"
        else:
            handle_symbols += " || exit /b 0"   # aka " || true"
    else:
        if web:
            handle_symbols = None
        elif tiny:
            # Perform a full strip
            handle_symbols = "strip $TARGET"
        elif linkgcc_strip and not mac:
            # This strips ~330kB from each of game.exe and custom.exe, leaving ~280kB of symbols
            # The size reduction is more like 60kB on Linux.
            # Untested on mac. And I would guess not needed, due to -dead_strip
            def strip_unwanted_syms(source, target, env):
                # source are the source objects for the executable and target is the exe
                ohrbuild.strip_nonfunction_symbols(target[0].path, target_prefix, builddir, env)
            handle_symbols = Action(strip_unwanted_syms, None)  # Action wrapper to print nothing
        else:
            handle_symbols = None

    #if mac:
        # -( -) are not supported on Mac, and don't seem to work with some other linkers either (e.g. on NixOS)...
    if True:
        # ...so never use -( -), to be more portable
        basexe_gcc_action = '$CC -o $TARGET $SOURCES $CCLINKFLAGS'
    else:
        basexe_gcc_action = '$CC -o $TARGET $SOURCES "-Wl,-(" $CCLINKFLAGS "-Wl,-)"'

    basexe = Builder(action = [basexe_gcc_action, check_binary, handle_symbols], suffix = exe_suffix,
                     src_suffix = '.bas', emitter = compile_bas_modules)

    env['BUILDERS']['BASEXE'] = basexe

if not linkgcc:
    if FBC.version >= 1060:
        # Ignore #inclib directives (specifically, so we can include modplug.bi)
        FBLINKFLAGS += ['-noobjinfo']
    if win32:
        # Link statically
        FBLINKFLAGS += ['-l', ':libstdc++.a']  # Yes, fbc accepts this argument form
    else:
        FBLINKFLAGS += ['-l','stdc++'] #, '-l','gcc_s']
    if mac:
        # libgcc_eh (a C++ helper library) is only needed when linking/compiling with old versions of Apple g++
        # including v4.2.1; for most compiler versions and configuration I tried it is unneeded
        # (Normally fbc links with gcc_eh if required, I wonder what goes wrong here?)
        FBLINKFLAGS += ['-l','gcc_eh']
    if portable:
        print("WARNING: portable=1 probably won't work in combination with linkgcc=0")
        # E.g. fbc will link to libtinfo/libncurses.

if portable and (unix and not mac):
    # For compatibility with libstdc++ before GCC 5
    # See https://bugzilla.mozilla.org/show_bug.cgi?id=1153109
    # and https://gcc.gnu.org/onlinedocs/libstdc%2B%2B/manual/using_dual_abi.html
    CXXFLAGS.append ("-D_GLIBCXX_USE_CXX11_ABI=0")
    if glibc:
        # For compatibility with older glibc when linking with glibc >= 2.28 (2018-08-01),
        # redirect certain functions like fcntl (used in libfb) to __wrap_fcntl, etc, which
        # are defined in lib/glibc_compat.c.
        # See https://rpg.hamsterrepublic.com/ohrrpgce/Portable_GNU-Linux_binaries
        syms = "fcntl", "fcntl64", "stat64", "pow", "exp", "log"
        CCLINKFLAGS.append ("-Wl," + ",".join("--wrap=" + x for x in syms))
        FBLINKERFLAGS += ["--wrap=" + x for x in syms]

# As long as exceptions aren't used anywhere and don't have to be propagated between libraries,
# we can link libgcc_s statically, which avoids one more thing that might be incompatible
# (although I haven't seen any problems yet). I think we can use
# -static-libgcc with exceptions, provided we link with g++?
# NOTE: libgcc_s.so still appears in ldd output, but it's no longer listed in objdump -p
# dependencies... hmmm...
# if unix:
#     CCLINKFLAGS += ['-static-libgcc']

if web:
    EMFLAGS = ['ASYNCIFY']
    EMFLAGS += ['WASM=' + str(wasm)]
    if wasm:
        # Needed to convert wasm offsets to function names
        EMFLAGS += ['USE_OFFSET_CONVERTER']
    EMFLAGS += ['DEMANGLE_SUPPORT=1']
    # Commandline programs should properly quit when done. Avoids a warning.
    # Game/Custom probably shouldn't quit at all.
    EMFLAGS += ['EXIT_RUNTIME']

    EMFLAGS += ['INITIAL_MEMORY=128MB']
    #EMFLAGS += ['ALLOW_MEMORY_GROWTH=1']
    #EMFLAGS += ['MALLOC=emmalloc']  # Simpler/smaller allocator

    if debug >= 3:
        EMFLAGS += ['ASSERTIONS=2']
        # Check for bad pointer access including null pointers and alignment faults
        EMFLAGS += ['SAFE_HEAP=1']

    emlinkflags = Flatten(['-s',flag] for flag in EMFLAGS)
    CCLINKFLAGS += emlinkflags
    FBLINKERFLAGS += emlinkflags

#################### Generate extraconfig.cfg for Android

if android_source:
    with open(rootdir + 'android/extraconfig.cfg', 'w+') as fil:
        # Unfortunately the commandergenius port only has a single CFLAGS,
        # which gets used for handwritten C, generated-from-FB C, and C++.
        # It would be better to change that.
        NDK_CFLAGS = CFLAGS + NONFBC_CFLAGS + FBC_CFLAGS + GENGCC_CFLAGS
        fil.write('AppCflags="%s"\n' % ' '.join(NDK_CFLAGS))
        fil.write('AppCppflags="%s"\n' % ' '.join(CXXFLAGS))
        if arch == 'armv5te':
            abi = 'armeabi'
        elif arch == 'armv7-a':
            abi = 'armeabi-v7a'
        elif arch == 'aarch64':
            abi = 'arm64-v8a'
            # TODO: To support both 32 and 64 bit ARM apparently need this:
            #abi = 'arm64-v8a,armeabi'
            # to set APP_ABI in project/jni/Settings.mk to that value, but that
            # won't work, need to separately cross-compile FB to C for each arch.
        else:
            abi = arch
        fil.write('MultiABI="%s"\n' % abi)
        if 'custom' in COMMAND_LINE_TARGETS:
            fil.write('. project/jni/application/src/EditorSettings.cfg')
    # Cause sdl-android's build.sh to re-generate Settings.mk, since extraconfig.cfg may have changed
    Execute(['touch %s/android/AndroidAppSettings.cfg' % rootdir])

####################

# With the exception of base_libraries, now have determined all shared variables
# so put them in the shared Environment env. After this point need to modify one of
# the specific Environments.

env['FBFLAGS'] = FBFLAGS
env['CFLAGS'] += CFLAGS + NONFBC_CFLAGS
env['CXXFLAGS'] += CFLAGS + CXXFLAGS
env['GENGCC_CFLAGS'] = GENGCC_CFLAGS
env['FBC_CFLAGS'] = FBC_CFLAGS
env['CCLINKFLAGS'] = CCLINKFLAGS
env['FBLINKFLAGS'] = FBLINKFLAGS
env['FBLINKERFLAGS'] = FBLINKERFLAGS

# These no longer have any effect.
del FBFLAGS, CFLAGS, FBC_CFLAGS, NONFBC_CFLAGS, GENGCC_CFLAGS, CXXFLAGS
del CCLINKFLAGS, FBLINKFLAGS, FBLINKERFLAGS

################ Program-specific stuff starts here

# We have six environments:
# env             : Used for most utilities
# +-> commonenv   : Common configuration for anything using allmodex. Not used directly, but later cloned to create:
#     +-> gameenv : For Game
#     +-> editenv : For Custom
#     +-> allmodexenv : For other utilities that need allmodex (for graphics)
# w32_env         : For gfx_directx (completely separate; uses Visual C++)

commonenv = env.Clone ()

# Added to env and commonenv
base_modules = []   # modules (any language) shared by all executables (except bam2mid)
#base_libraries defined above

# Added to gameenv and editenv
shared_modules = []  # FB/RB modules shared by, but with separate builds, for Game and Custom

# Added to commonenv
common_modules = []  # other modules (in any language) shared by Game and Custom; only built once
common_libraries = []
common_libpaths = []


################ gfx and music backend modules and libraries

# OS-specific libraries and options for each backend are added below.

gfx_map = {'fb': {'shared_modules': 'gfx_fb.bas', 'common_libraries': 'fbgfxmt fbmt'},
           'alleg' : {'shared_modules': 'gfx_alleg.bas', 'common_libraries': 'alleg'},
           'sdl' : {'shared_modules': 'gfx_sdl.bas', 'common_libraries': 'SDL'},
           'sdl2' : {'shared_modules': 'gfx_sdl2.bas', 'common_libraries': 'SDL2'},
           'console' : {'shared_modules': 'gfx_console.bas', 'common_modules': 'lib/curses_wrap.c'},
           'dummy' : {},
           'directx' : {}, # nothing needed
           'sdlpp': {}     # nothing needed
           }

music_map = {'native':
                 {'shared_modules': 'music_native.bas music_audiere.bas',
                  'common_modules': os.path.join ('audwrap','audwrap.cpp'),
                  'common_libraries': 'audiere', 'common_libpaths': '.'},
             'native2':
                 {'shared_modules': 'music_native2.bas music_audiere.bas',
                  'common_modules': os.path.join ('audwrap','audwrap.cpp'),
                  'common_libraries': 'audiere', 'common_libpaths': '.'},
             'sdl':
                 {'shared_modules': 'music_sdl.bas sdl_lumprwops.bas',
                  'common_libraries': 'SDL SDL_mixer'},
             'sdl2':
                 {'shared_modules': 'music_sdl2.bas',
                  'common_libraries': 'SDL2 SDL2_mixer'},
             'allegro':
                 {'shared_modules': 'music_allegro.bas',
                  'common_libraries': 'alleg'},
             'silence':
                 {'shared_modules': 'music_silence.bas'}
            }

for k in gfx:
    for k2, v2 in gfx_map[k].items():
        globals()[k2] += v2.split(' ')

for k in music:
    for k2, v2 in music_map[k].items():
        globals()[k2] += v2.split(' ')


################ OS-specific modules and libraries

if web:
    # IndexedDB-based persistent FS, used in JS rather than from FB
    common_libraries += ["idbfs.js"]

    # Emscripten settings which add libraries to the link
    EMFLAGS = []
    #EMFLAGS += ['USE_SDL_IMAGE=0', 'USE_SDL_TTF=0', 'USE_SDL_NET=0']
    if 'sdl' in gfx:
        emsdlflags += ['USE_SDL=1', 'USE_SDL_MIXER=1']
    elif 'sdl2' in gfx:
        emsdlflags += ['USE_SDL=2', 'USE_SDL_MIXER=2', 'SDL2_MIXER_FORMATS=["ogg", "mod", "mid"]']
        #emsdlflags += ['-s', 'USE_MODPLUG', '-s', 'USE_MPG123']

    emlinkflags = Flatten(['-s',flag] for flag in EMFLAGS)
    commonenv['CCLINKFLAGS'] += emlinkflags
    commonenv['FBLINKERFLAGS'] += emlinkflags

if not minos:
    # This module is OS-specific but shared by Windows (winsock) and Unix.
    base_modules += ['os_sockets.c']

if win32:
    base_modules += ['os_windows.bas', 'os_windows2.c', 'lib/win98_compat.bas',
                     'lib/msvcrt_compat.c', 'gfx_common/win_error.c']
    # winmm needed for MIDI, used by music backends but also by miditest
    # psapi.dll needed just for get_process_path() and memory_usage(). Not present on Win98 unfortunately,
    # so now we dynamically link it.
    # ole32.dll and shell32.dll needed just for open_document()
    # advapi32 is needed by libfb[mt]
    # Strangely advapi32 and shell32 are automatically added by ld when using linkgcc=1 but not linkgcc=0
    base_libraries += ['winmm', 'ole32', 'gdi32', 'shell32', 'advapi32', 'wsock32' if win95 else 'ws2_32']
    if win95:
        # Link to Winsock 2 instead of 1 to support stock Win95 (Use win95=0 and mingw-w64 (not mingw) to get support for IPv6)
        env['CFLAGS'] += ['-D', 'USE_WINSOCK1']
        # Temp workaround for bug #1241 when compiling with mingw-w64 6.0.0 (currently used for official builds) to support Win95-2k
        base_modules += ['lib/___mb_cur_max_func.c']
    common_libraries += ['fbgfxmt', 'fbmt']   # For display_help_string
    commonenv['FBFLAGS'] += ['-s','gui']  # Change to -s console to see 'print' statements in the console!
    commonenv['CCLINKFLAGS'] += ['-lgdi32', '-Wl,--subsystem,windows']
    #env['CCLINKFLAGS'] += ['win32/CrashRpt1403.lib']  # If not linking the .dll w/ LoadLibrary
    env['CFLAGS'] += ['-I', 'win32/include']
    if 'sdl' in gfx or 'fb' in gfx:
        common_modules += ['lib/SDL/SDL_windowsclipboard.c', 'gfx_common/ohrstring.cpp']
    if 'console' in gfx:
        common_libraries += ['pdcurses']
    # if 'sdl' in music:
    #     # libvorbisfile is linked into SDL_mixer.dll which has been compiled to export its symbols
    #     commonenv['FBFLAGS'] += ['-d', 'HAVE_VORBISFILE']
elif mac:
    base_modules += ['os_unix.c', 'os_unix2.bas']
    common_modules += ['os_unix_wm.c']
    common_libraries += ['Cocoa']  # For CoreServices (linked as a framework)
    if 'sdl2' not in gfx:
        common_modules += ['lib/SDL/SDL_cocoaclipboard.m']
    if 'sdl' in gfx:
        common_modules += ['mac/SDLmain.m']
        commonenv['FBFLAGS'] += ['-entry', 'SDL_main']
        if env.WhereIs('sdl-config'):
            commonenv.ParseConfig('sdl-config --cflags')
        else:
            commonenv['CFLAGS'] += ["-I", "/Library/Frameworks/SDL.framework/Headers", "-I", FRAMEWORKS_PATH + "/SDL.framework/Headers"]
    if 'sdl2' in gfx:
        # SDL2 does not have SDLmain
        if env.WhereIs('sdl2-config'):
            commonenv.ParseConfig('sdl2-config --cflags')
        else:
            commonenv['CFLAGS'] += ["-I", "/Library/Frameworks/SDL2.framework/Headers", "-I", FRAMEWORKS_PATH + "/SDL2.framework/Headers"]
    # if 'sdl' in music:
    #     # libvorbisfile is linked into SDL_mixer.framework which has been compiled to export its symbols
    #     commonenv['FBFLAGS'] += ['-d', 'HAVE_VORBISFILE']

elif android:
    # liblog for __android_log_print/write
    base_libraries += ['log']
    base_modules += ['os_unix.c', 'os_unix2.bas']
    common_modules += ['os_unix_wm.c', 'android/sdlmain.c']
elif unix:  # Unix+X11 systems: Linux & BSD
    if not minos:
        base_libraries += ['dl']
    base_modules += ['os_unix.c', 'os_unix2.bas']
    # os_unix_wm.c is mostly stubs if not USE_X11 and not mac
    common_modules += ['os_unix_wm.c']
    if portable:
        # To support old libstdc++.so versions
        base_modules += ['lib/stdc++compat.cpp']
        if not mac:  # Don't know about Mac
            base_modules += ['lib/termcap_stub.c']
        if glibc:
            base_modules += ['lib/glibc_compat.c']
    if not minos and ('sdl' in gfx or 'fb' in gfx):
        # These files are taken from SDL2, so gfx_sdl2 doesn't need them
        common_modules += ['lib/SDL/SDL_x11clipboard.c', 'lib/SDL/SDL_x11events.c']
    if gfx == ['console'] or minos:
        commonenv['FBFLAGS'] += ['-d', 'NO_X11']
        commonenv['CFLAGS'] += ['-DNO_X11']
    else:
        # All graphical gfx backends need the X11 libs
        common_libraries += 'X11 Xext Xpm Xrandr Xrender Xinerama'.split (' ')
        common_modules += ['lib/x11_printerror.c']
    if 'console' in gfx and portable:
        print("gfx=console is not compatible with portable=1, which doesn't link to ncurses.")
        Exit(1)
    # common_libraries += ['vorbisfile']
    # commonenv['FBFLAGS'] += ['-d','HAVE_VORBISFILE']


################ Add the library search paths to env and commonenv

def add_libpath(env, libpath):
    env['FBLINKFLAGS'] += ['-p', libpath]
    env['CCLINKFLAGS'] += ['-L', libpath]

libdir = None
if 'libdir' in ARGUMENTS:
    libdir = os.path.join(rootdir, ARGUMENTS['libdir'])
    add_libpath(env, libdir)
    add_libpath(commonenv, libdir)

if win32:
    # win32/ contains .a and .dll.a files
    add_libpath(env, 'win32')
    add_libpath(commonenv, 'win32')

for libpath in common_libpaths:
    add_libpath(commonenv, libpath)
del common_libpaths


################ Add the libraries to env and commonenv

for lib in base_libraries:
    env['CCLINKFLAGS'] += ['-l' + lib]
    env['FBLINKFLAGS'] += ['-l', lib]

frameworks = None
if mac:
    frameworks = ARGUMENTS.get('frameworks', 'SDL,SDL_mixer,SDL2,SDL2_mixer')
    if frameworks in ('0', 'no', ''):
        frameworks = ()
    else:
        frameworks = frameworks.split(',')
    frameworks += ('Cocoa',)

for lib in common_libraries + base_libraries:
    if mac and lib in frameworks:
        # Use frameworks rather than normal unix libraries
        # (Note: linkgcc=0 does not work on Mac because the #inclib "SDL" in the
        # SDL headers causes fbc to pass -lSDL to the linker, which can't be
        # found (even if we add the framework path, because it's not called libSDL.dylib))
        commonenv['CCLINKFLAGS'] += ['-framework', lib]
        commonenv['FBLINKERFLAGS'] += ['-framework', lib]
    else:  #elif not web:
        commonenv['CCLINKFLAGS'] += ['-l' + lib]
        commonenv['FBLINKFLAGS'] += ['-l', lib]


################ Environment Variants

gameenv = commonenv.Clone(VAR_PREFIX = 'game-')
editenv = commonenv.Clone(VAR_PREFIX = 'edit-')
allmodexenv = commonenv.Clone(VAR_PREFIX = 'util-')
gameenv['FBFLAGS'] += ['-d','IS_GAME',   '-m','game']
editenv['FBFLAGS'] += ['-d','IS_CUSTOM', '-m','custom']

################ Modules

# The following are linked into all executables, except miditest.
base_modules +=   ['util.bas',
                   'base64.bas',
                   'unicode.c',
                   'array.c',
                   'miscc.c',
                   'fb/error.c',
                   'lib/sha1.c',
                   'lib/lodepng.c',  # Only for lodepng_gzip.c
                   'lib/lodepng_gzip.c',  # Only for filetest
                   'filelayer.cpp',
                   'globals.bas',
                   'lumpfile.bas',
                   'networkutil.bas',
                   'vector.bas']

# Modules shared by the reload utilities, additional to base_modules
reload_modules =  ['reload.bas',
                   'reloadext.bas']

# The following are built only once and linked into Game, Custom and other
# utilities using allmodex (commontest, gfxtest, etc).
common_modules += ['blit.c',
                   'matrixMath.cpp',
                   'rasterizer.cpp',
                   'rotozoom.c',
                   'surface.cpp',
                   'lib/gif.cpp',
                   'lib/jo_jpeg.cpp',
                   'lib/ujpeg.c']

# The following are compiled up to three times, for Game, Custom and other
# other utilities using allmodex, with IS_GAME, IS_CUSTOM or neither defined.
# (All Game/Custom shared FB files are here instead of common_modules so we
# don't have to remember where using IS_GAME/IS_CUSTOM is allowed.)
# (.bas files only)
shared_modules += ['achievements.rbas',
                   'allmodex',
                   'audiofile',
                   'backends',
                   'bam2mid',
                   'bcommon',
                   'browse',
                   'common.rbas',
                   'common_menus',
                   'cmdline',
                   'loading.rbas',
                   'menus',
                   'reload',
                   'reloadext',
                   'sliceedit',
                   'slices',
                   'specialslices',
                   'steam',
                   'thingbrowser',
                   'plankmenu']
# (.bas files only)
edit_modules = ['custom',
                'customsubs.rbas',
                'drawing',
                'textboxedit',
                'scriptedit',
                'mapsubs',
                'attackedit',
                'audioedit',
                'enemyedit',
                'fontedit',
                'formationedit',
                'generaledit.rbas',
                'globalstredit',
                'heroedit.rbas',
                'menuedit',
                'itemedit',
                'shopedit',
                'reloadedit',
                'editedit',
                'editrunner',
                'editorkit',
                'distribmenu']

# (.bas files only)
game_modules = ['game',
                'achievements_runtime.rbas',
                'bmod.rbas',
                'bmodsubs',
                'menustuf.rbas',
                'moresubs.rbas',
                'scriptcommands',
                'yetmore2',
                'walkabouts',
                'savegame.rbas',
                'scripting',
                'oldhsinterpreter',
                'purchase.rbas',
                'pathfinding.bas']


################ Generate files containing Version/build info

def version_info(source, target, env):
    ohrbuild.verprint(globals(), builddir, rootdir)
# globals.bas and backendinfo.bi are created in build/
verprint_targets = ['globals.bas', 'backendinfo.bi', '#/buildinfo.ini', '#/distver.bat']
VERPRINT = env.Command (target = verprint_targets,
                        source = ['codename.txt'], 
                        action = env.Action(version_info, "Generating version/backend info"))
# We can't describe what the dependencies to verprint() are, so make sure scons always runs it
AlwaysBuild(VERPRINT)
NoCache(verprint_targets)

################ Data files

# Files to embed in Custom+Game
common_datafiles = Glob('sourceslices/*.slice') + ['#/buildinfo.ini']
# Files to embed in other utilities
util_datafiles = []

# datafiles = ohrbuild.get_embedded_datafiles(rootdir)
DATAFILES_C =      env.Command(target = [builddir + 'datafiles.c'], source = common_datafiles,
                               action = env.Action(ohrbuild.generate_datafiles_c, "Generating datafiles.c"))
UTIL_DATAFILES_C = env.Command(target = [builddir + 'util-datafiles.c'], source = util_datafiles,
                               action = env.Action(ohrbuild.generate_datafiles_c, "Generating util-datafiles.c"))
common_modules.append(DATAFILES_C)

if web:
    # <TARGET>.data is created containing contents of ./data, mounted as /data in the file system
    customenv['CCLINKFLAGS'] += ['--preload-file', 'data']
    # This is for testing convenience only
    gameenv['CCLINKFLAGS'] += ['--preload-file', 'games']
    customenv['CCLINKFLAGS'] += ['--preload-file', 'games']

################ Generate object file Nodes

if linkgcc and not win32:
    if 'fb' in gfx:
        # Program icon required by fbgfx, but we only provide it on Windows,
        # because on X11 need to provide it as an XPM instead
        common_modules += ['linux/fb_icon.c']

# Note that base_objects are not built in commonenv!
base_objects = Flatten([SrcFile(env, a) for a in base_modules])  # concatenate NodeLists
common_objects = base_objects + Flatten([SrcFile(commonenv, a) for a in common_modules])
# Modules included by utilities but not Game or Custom
base_objects += [SrcFile(env, 'common_base.bas'), SrcFile(env, UTIL_DATAFILES_C)]

#now... GAME and CUSTOM

gamesrc = common_objects[:]
for item in game_modules:
    gamesrc.extend (gameenv.BASO (item))
for item in shared_modules:
    gamesrc.extend (gameenv.VARIANT_BASO (item))

editsrc = common_objects[:]
for item in edit_modules:
    editsrc.extend (editenv.BASO (item))
for item in shared_modules:
    editsrc.extend (editenv.VARIANT_BASO (item))

allmodex_objects = common_objects[:]
for item in shared_modules:
    allmodex_objects.extend (allmodexenv.VARIANT_BASO (item))

if win32:
    # The .rc file includes game.ico or custom.ico and is compiled to an .o file
    # (If linkgcc=0, could just pass the .rc to fbc)
    gamesrc += Depends(gameenv.RC('gicon.o', 'gicon.rc'), 'game.ico')
    editsrc += Depends(editenv.RC('cicon.o', 'cicon.rc'), 'custom.ico')

# Sort RB modules to the front so they get built first, to avoid bottlenecks
gamesrc.sort (key = lambda node: 0 if '.rbas' in node.path else 1)
editsrc.sort (key = lambda node: 0 if '.rbas' in node.path else 1)

# For reload utilities
reload_objects = base_objects + Flatten ([SrcFile(env, a) for a in reload_modules])

# For utiltest
base_objects_without_util = [a for a in Flatten(base_objects) if File('util.bas') not in a.sources]
# For commontest
allmodex_objects_without_common = [a for a in Flatten(allmodex_objects) if File('common.rbas.bas') not in a.sources]


################ Executable definitions
# Executables are explicitly placed in rootdir, otherwise they would go in build/

def env_exe(name, env = env, builder = None, source = None, **kwargs):
    "Defines an executable. But we don't actually build it if transpiling."
    if builder is None:
        if transpile_dir:
            builder = env.COPY_SOURCES
        else:
            builder = env.BASEXE
    ret = builder(rootdir + name, source = source, **kwargs)
    Alias(name, ret)
    NoCache(ret)  # Executables are large but fast to link, not worth caching
    return ret[0]  # first element of the NodeList is the executable

if win32:
    gamename = 'game'
    editname = 'custom'
else:
    gamename = 'ohrrpgce-game'
    editname = 'ohrrpgce-custom'

GAME   = env_exe(gamename, env = gameenv, source = gamesrc)
CUSTOM = env_exe(editname, env = editenv, source = editsrc)
Alias('game', GAME)
Alias('custom', CUSTOM)
# if libdir:
#     libs = Glob(libdir + '/*')
#     Depends(GAME, libs)
#     Depends(CUSTOM, libs)

env_exe ('bam2mid', source = ['bam2mid.bas'] + base_objects)
env_exe ('miditest')
env_exe ('unlump', source = ['unlump.bas'] + base_objects)
env_exe ('relump', source = ['relump.bas'] + base_objects)
env_exe ('dumpohrkey', source = ['dumpohrkey.bas'] + base_objects)
# This builder arg is needed to link the necessary libraries
env_exe ('imageconv', env = allmodexenv, source = ['imageconv.bas'] + allmodex_objects)

####################  Compiling Euphoria (HSpeak)

def check_have_euc(target, source, env):
    if not EUC:
        print("Error: Euphoria is required to compile HSpeak but is not installed (euc is not in the PATH)")
        Exit(1)
    if cross_compiling and 'eulib' not in ARGUMENTS:
        print("WARNING: looks like you're cross-compiling HSpeak so should pass an eulib=... argument with the path to a Euphoria eu.a compiled for " + target_prefix)

def check_have_eubind(target, source, env):
    if not EUBIND:
        print("Error: Euphoria is required to compile HSpeak but is not installed (eubind is not in the PATH)")
        Exit(1)
    print("Note: binding hspeak. Run scons with release=1 to compile a faster hspeak")

def setup_eu_vars(compiling):
    """Set the necessary variables on env for the euphoria EUEXE Builder.
    compiling: true if compiling with euc rather than binding with eubind."""
    hspeak_builddir = builddir + "hspeak"
    euc_extra_args = []
    # Work around Euphoria bug (in 4.0/4.1), where $EUDIR is ignored if another
    # copy of Euphoria is installed system-wide
    if 'EUDIR' in env['ENV']:
        euc_extra_args += ['-eudir', env['ENV']['EUDIR']]
    if compiling:
        # We have not found any way to capture euc's stderr on Windows so can't check version there
        # (But currently the nightly build machine runs 4.0.5)
        if NO_PIE and not win32 and not mac and EUC and ohrbuild.get_euphoria_version(EUC) >= 40100:
            # On some systems (not including mac) gcc defaults to building PIE
            # executables, but the linux euphoria 4.1.0 builds aren't built for PIE/PIC,
            # resulting in a "recompile with -fPIC" error.
            # But the -extra-lflags option is new in Eu 4.1.
            euc_extra_args += ['-extra-lflags', NO_PIE]

        if 'eulib' in ARGUMENTS:
            euc_extra_args += ['-lib', ARGUMENTS['eulib']]
        if cross_compiling:
            euc_extra_args += ['-arch', arch]
            if win32:
                euc_extra_args += ['-plat', 'windows']
            elif mac:
                euc_extra_args += ['-plat', 'osx']
            else:  # unix
                euc_extra_args += ['-plat', 'linux']   # FIXME: not quite right
        env['EUCMAKEFLAGS'] = ['CC=' + str(CC), 'LINKER=' + str(CC)]

    env['EUFLAGS'] = euc_extra_args
    env['EUBUILDDIR'] = Dir(hspeak_builddir)  # Ensures spaces are escaped
    # euc itself creates a .mak file that's broken if the (destination)
    # path to hspeak.exe contains a space.

# Cross-compiling using eubind could be possible if we passed it the path to
# eub.exe, but for now just use euc.
if optimisations > 1 or cross_compiling:
    # Use euc and gcc to compile hspeak in release builds
    setup_eu_vars(True)

    # HSpeak is built by translating to C, generating a Makefile, and running make.
    euexe = Builder(action = [Action(check_have_euc, None),
                              '$EUC -con -gcc $SOURCES $EUFLAGS -verbose -maxsize 5000 -makefile -build-dir $EUBUILDDIR',
                              '$MAKE -j%d -C $EUBUILDDIR -f hspeak.mak $EUCMAKEFLAGS' % (GetOption('num_jobs'),)],
                    suffix = exe_suffix, src_suffix = '.exw')
else:
    setup_eu_vars(False)
    # Use eubind to combine hspeak.exw and the eui interpreter into a single (slower) executable
    euexe = Builder(action = [Action(check_have_eubind, None),
                              '$EUBIND -con $SOURCES $EUFLAGS'],
                    suffix = exe_suffix, src_suffix = '.exw')

env.Append(BUILDERS = {'EUEXE': euexe})

####################

HSPEAK = env_exe('hspeak', builder = env.EUEXE, source = ['hspeak.exw', 'hsspiffy.e'] + Glob('euphoria/*.e'))
RELOADTEST = env_exe ('reloadtest', source = ['reloadtest.bas'] + reload_objects)
x2rsrc = ['xml2reload.bas'] + reload_objects
if win32:
    # Hack around our provided libxml2.a lacking a function. (Was less work than recompiling)
    x2rsrc.append (SrcFile(env, 'win32/utf8toisolat1.c'))
XML2RELOAD = env_exe ('xml2reload', source = x2rsrc, FBLINKFLAGS = env['FBLINKFLAGS'] + ['-l','xml2'], CCLINKFLAGS = env['CCLINKFLAGS'] + ['-lxml2'])
RELOAD2XML = env_exe ('reload2xml', source = ['reload2xml.bas'] + reload_objects)
RELOADUTIL = env_exe ('reloadutil', source = ['reloadutil.bas'] + reload_objects)
RBTEST = env_exe ('rbtest', source = [env.RB('rbtest.rbas'), env.RB('rbtest2.rbas')] + reload_objects)
VECTORTEST = env_exe ('vectortest', source = ['vectortest.bas'] + base_objects)
# Compile util.bas as a main module to utiltest.o to prevent its linkage in other binaries
UTILTEST = env_exe ('utiltest', source = env.BASMAINO('utiltest.o', 'util.bas') + base_objects_without_util)
FILETEST = env_exe ('filetest', source = ['filetest.bas'] + base_objects)
Depends(FILETEST, env_exe ('filetest_helper', source = ['filetest_helper.bas'] + base_objects))
COMMONTEST = env_exe ('commontest', env = allmodexenv, source = allmodexenv.BASMAINO('commontest.o', 'common.rbas') + allmodex_objects_without_common)
GFXTEST = env_exe ('gfxtest', env = allmodexenv, source = ['gfxtest.bas'] + allmodex_objects)

Alias ('reload', [RELOADUTIL, RELOAD2XML, XML2RELOAD, RELOADTEST, RBTEST])

# gfx_directx.dll and gfx_directx_test1.exe
# Skip the following if we aren't building these, to avoid warnings if VC++ isn't available.
if any('gfx_directx' in targ for targ in BUILD_TARGETS):
    if not host_win32:
        exit("Can't cross-compile gfx_directx, requires Visual C++")

    directx_sources = ['d3d.cpp', 'didf.cpp', 'gfx_directx.cpp', 'joystick.cpp', 'keyboard.cpp',
                       'midsurface.cpp', 'mouse.cpp', 'window.cpp']
    directx_sources = [os.path.join('gfx_directx', f) for f in directx_sources]
    directx_sources += ['gfx_common/ohrstring.cpp', 'gfx_common/win_error.c',
                        'lib/msvcrt_compat.c', 'lib/SDL/SDL_windowsclipboard.c']

    # Create environment for compiling gfx_directx.dll
    # $OBJPREFIX is prefixed to the name of each object file, to ensure there are no clashes
    w32_env = Environment (OBJPREFIX = 'gfx_directx-')
    w32_env['ENV']['PATH'] = os.environ['PATH']
    if "Include" in os.environ:
        w32_env.Append(CPPPATH = os.environ['Include'].split(';'))
    if "Lib" in os.environ:
        w32_env.Append(LIBPATH = os.environ['Lib'].split(';'))
    if 'DXSDK_DIR' in os.environ:
        w32_env.Append(CPPPATH = [os.path.join(os.environ['DXSDK_DIR'], 'Include')])
        w32_env.Append(LIBPATH = [os.path.join(os.environ['DXSDK_DIR'], 'Lib', 'x86')])
    w32_env.Append(CPPPATH = "gfx_common")

    if profile:
        # Profile using MicroProfiler, which uses instrumentation (counting function calls)
        # There are many other available profilers based on either instrumentation or
        # statistical sampling (like gprof), so this can be easily adapted.
        dllpath = WhereIs("micro-profiler.dll", os.environ['PATH'], "dll")

        if not dllpath:
            # MicroProfiler is MIT licensed, but you need to install it using
            # regsvr32 (with admin privileges) for it to work, so there's little
            # benefit to distributing the library ourselves.
            print("MicroProfiler is not installed. You can install it from")
            print("https://visualstudiogallery.msdn.microsoft.com/800cc437-8cb9-463f-9382-26bedff7cdf0")
            Exit(1)

        # if optimisations == False:
        #     # MidSurface::copySystemPage() and Palette::operator[] are extremely slow when
        #     # profiled without optimisation, so don't instrument MidSurface.
        #     w32_no_profile_env = w32_env.Clone ()
        #     midsurface = os.path.join ('gfx_directx', 'midsurface.cpp')
        #     directx_sources.remove (midsurface)
        #     directx_sources.append (w32_no_profile_env.Object (midsurface))

        MPpath = os.path.dirname(dllpath) + os.path.sep
        directx_sources.append (w32_env.Object('micro-profiler.initalizer.obj', MPpath + 'micro-profiler.initializer.cpp'))
        w32_env.Append (LIBPATH = MPpath)
        # Call _penter and _pexit in every function.
        w32_env.Append (CPPFLAGS = ['/Gh', '/GH'])

    RESFILE = w32_env.RES ('gfx_directx/gfx_directx.res', source = 'gfx_directx/gfx_directx.rc')
    Depends (RESFILE, ['gfx_directx/help.txt', 'gfx_directx/Ohrrpgce.bmp'])
    directx_sources.append (RESFILE)

    # Enable exceptions, most warnings, treat .c files are C++, unicode/wide strings
    w32_env.Append (CPPFLAGS = ['/EHsc', '/W3', '/TP'], CPPDEFINES = ['UNICODE', '_UNICODE', 'FBCVERSION=%d' % FBC.version])

    if profile:
        # debug info, static link VC9.0 runtime lib, but no link-time code-gen
        # as it inlines too many functions, which don't get instrumented
        w32_env.Append (CPPFLAGS = ['/Zi', '/MT'], LINKFLAGS = ['/DEBUG'])
        # Optimise for space (/O1) to inline trivial functions, otherwise takes seconds per frame
        w32_env.Append (CPPFLAGS = ['/O2' if optimisations else '/O1'])
    elif optimisations == False:
        # debug info, runtime error checking, static link debugging VC9.0 runtime lib, no optimisation
        w32_env.Append (CPPFLAGS = ['/Zi', '/RTC1', '/MTd', '/Od'], LINKFLAGS = ['/DEBUG'])
    else:
        # static link VC9.0 runtime lib, optimise, whole-program optimisation
        w32_env.Append (CPPFLAGS = ['/MT', '/O2', '/GL'], LINKFLAGS = ['/LTCG'])

    #if pdb:  # I see no reason not to build a .pdb
    if True:
        # /OPT:REF enables dead code removal (trimming 110KB) which is disabled by default by /DEBUG,
        # while /OPT:NOICF disables identical-function-folding, which is confusing while debugging
        w32_env.Append (CPPFLAGS = ['/Zi'],
                        LINKFLAGS = ['/DEBUG', '/PDB:' + rootdir + 'win32/gfx_directx.pdb',
                                     '/OPT:REF', '/OPT:NOICF'])

    w32_env.SharedLibrary (rootdir + 'gfx_directx.dll', source = directx_sources,
                          LIBS = ['user32', 'ole32', 'gdi32'])
    TEST = w32_env.Program (rootdir + 'gfx_directx_test1.exe', source = ['gfx_directx/gfx_directx_test1.cpp'],
                            LIBS = ['user32'])
    Alias ('gfx_directx_test', TEST)


################ Non-file/action targets

def Phony(name, source, action, message = None, buildsource = True):
    """Define a target which performs some action (e.g. a Python function) unconditionally.
    If buildsource is False, don't rebuild sources."""
    if not buildsource:
        source = []
    if message:
        action = env.Action(action, message)
    node = env.Alias(name, source = source, action = action)
    AlwaysBuild(node)  # Run even if there happens to be a file of the same name
    return node

def RPGWithScripts(rpg, main_script):
    """Construct an (Action) node for an .rpg, which updates it by re-importing
    an .hss if it (or any included script file) has been modified."""
    sources = [main_script, "plotscr.hsd"]
    if EUC:
        # Only include hspeak as dependency if Euphoria is installed, otherwise can't run tests
        sources += [HSPEAK]
    action = env.Action(CUSTOM.abspath + ' --nowait --hsflags w ' + rpg + ' ' + main_script)  # Ignore warnings
    # Prepending # means relative to rootdir, otherwise this a rule to build a file in build/
    if os.path.isdir(rootdir + rpg):
        # Hack, you can't rebuild a directory but this seems to work nicely
        nodefile = '#' + os.path.join(rpg, 'plotscr.lst')
    else:
        nodefile = '#' + rpg
    node = env.Command(nodefile, source = sources, action = action)
    Precious(node)  # Don't delete the .rpg before "rebuilding" it
    NoClean(node)   # Don't delete the .rpg with -c
    NoCache(node)   # Don't copy the .rpg into build/cache
    # Note: the following Ignore does NOT work if the .hss file manually includes plotscr.hsd/scancode.hsi!
    Ignore(node, [CUSTOM, "plotscr.hsd", "scancode.hsi"])  # Don't reimport just because these changed...
    Requires(node, CUSTOM)  # ...but do rebuild Custom before reimporting (because of maxScriptCmdID, etc, checks)
    # Note: unfortunately this Requires causes scons to make sure CUSTOM is
    # up to date even if it's not called; I don't know how to avoid that.
    SideEffect (Alias ('c_debug.txt'), node)  # Prevent more than one copy of Custom from running at once
    return node

### Test .rpgs
T = 'testgame/'
# Avoid gfx_directx when running test games, it doesn't skip frames
_gfx = sorted(gfx, key=lambda x: x == 'directx')
test_args = GAME.abspath + ' --gfx ' + _gfx[0] + ' --log . --runfast -z 2 '
AUTOTEST = Phony ('autotest_rpg',
                  source = [GAME, RPGWithScripts(T+'autotest.rpgdir', T+'autotest.hss')],
                  action =
                  [test_args + T+'autotest.rpgdir',
                   'grep -q "TRACE: TESTS SUCCEEDED" g_debug.txt'],
                  buildsource = buildtests)
env.Alias ('autotest', source = AUTOTEST)
INTERTEST = Phony ('interactivetest',
                   source = [GAME, RPGWithScripts(T+'interactivetest.rpg', T+'interactivetest.hss')],
                   action =
                   [test_args + T+'interactivetest.rpg --replayinput ' + T+'interactivetest.ohrkey',
                    'grep -q "TRACE: TESTS SUCCEEDED" g_debug.txt'],
                   buildsource = buildtests)
# This prevents more than one copy of Game from being run at once
# (doesn't matter where g_debug.txt is actually placed).
# The Alias prevents scons . from running the tests.
SideEffect (Alias ('g_debug.txt'), [AUTOTEST, INTERTEST])

HSPEAKTEST = Phony ('hspeaktest', source = HSPEAK, action =
                    [[python, rootdir + 'hspeaktest.py', 'testgame/parser_tests.hss']])

# Note: does not include hspeaktest, because it fails, and Euphoria may not be installed
tests = [exe.abspath for exe in Flatten([RELOADTEST, RBTEST, VECTORTEST, UTILTEST, FILETEST, COMMONTEST])]
test_srcs = tests[:] if buildtests else []
test_srcs += [AUTOTEST, INTERTEST]  # These are Nodes so can't be used as actions
TESTS = Phony ('test', source = test_srcs, action = tests)
Alias ('tests', TESTS)

def packager(target, source, env):
    action = str(target[0])  # 'install' or 'uninstall'
    if android or not unix:
        print("The '%s' action is only implemented on Unix systems." % action)
        return 1
    if action == 'install' and dry_run:
        print("dry_run option not implemented for 'install' action")
        return 1
    sys.path += ['linux']
    import linuxpkg
    getattr(linuxpkg, action)(destdir, prefix, dry_run = dry_run)

Phony ('install', source = [GAME, CUSTOM, HSPEAK], action = packager, message = "Installing...")
Phony ('uninstall', source = [], action = packager, message = "Uninstalling..." + (dry_run and " (dry run)" or ""))

Default (GAME)
Default (CUSTOM)

#print [str(a) for a in FindSourceFiles(GAME)]

Help ("""
Usage:  scons [SCons options] [options] [targets]

Options:
  gfx=BACKENDS        Graphics backends, concatenated with +. Options:
                        """ + " ".join(gfx_map.keys()) + """
                      (Don't try to use gfx_dummy!)
                      At runtime, backends are tried in the order specified.
                      Current (default) value: """ + "+".join(gfx) + """
                      Defaults differ by OS and if win95=1 is passed.
  music=BACKEND       Music backend. Options:
                        """ + " ".join(music_map.keys()) + """
                      Current (default) value: """ + "+".join(music) + """
  release=1           Sets the default settings used for releases, including
                      nightly builds (which you can override):
                      Equivalent to debug=0 gengcc=1, and also portable=1
                      on Unix (except Android and Mac)
  gengcc=1            Compile using C backend (faster binaries, longer compile
                      times, and some extra warnings). This is always used
                      everywhere except x86 Windows/Linux/BSD. See also 'compiler'.
  debug=0|1|2|3|4     Debug level:
                                  -exx |     debug info      | optimisation
                                 ------+---------------------+--------------
                       debug=0:    no  |    minimal syms     |    yes   <--Releases
                       debug=1:    no  |        yes          |    yes
                       debug=2:    yes |        yes          | C/C++ only <--Default
                       debug=3:    yes |        yes          |    no
                       debug=4:    no  |        yes          |    no
                      (pdb=1:          always stripped to pdb         )
                      -exx builds have array, pointer and file error checking and
                        are slow. [Disabled if using clang, asan or valgrind.]
                      debug info: "minimal syms" means: only function
                        symbols present (to allow basic stacktraces); adds ~300KB.
                        (Note: if gengcc=0, then debug=0 is completely unstripped)
                      optimisation: Also causes hspeak to be translated to C
  tiny=1              Create a minimum-size build. Enables gengcc=1, debug=0 (with
                      even less debug info), lto=1 and use -Os. Runs slower
                      (scripts by ~20%).  Adding lto=0 hugely shortens build time,
                      is not much larger, but even slower.
  pdb=1               (Windows only.) Produce .pdb debug info files, for CrashRpt
                      and BreakPad crash analysis. .pdb files are put in win32/.
                      Visual Studio or Visual C++ Build Tools must be installed.
                      Forces gengcc=1. Doesn't support linkgcc=0.
                      Requires wine if cross-compiling to Windows.
  buildname=NAME      A name used to identify the build, to find debug symbols.
                      Currently only officially used on Windows for Game/Custom.
  lto=1               Do link-time optimisation, for a faster, smaller build
                      (around 10-15% smaller for Game/Custom, 50% for utilities)
                      but long compile time. Useful with gengcc=1 only.
  valgrind=1          Recommended when using valgrind (also turns off -exx).
  asan=1              Use AddressSanitizer. Unless overridden with gengcc=0 also
                      disables -exx and uses C backend.
  profile=1           Profiling build using gprof (executables) or MicroProfiler
                      (gfx_directx.dll/gfx_directx_test1.exe).
  asm=1               Keep temporary .asm or .c files in build/ after compiling.
                      (If you want to compile to .c, use transpiledir= instead.)
  fbc=PATH            Use a particular FreeBASIC compiler (defaults to fbc).
                      Alternatively set the FBC envvar.
  python=PATH         Use a particular Python interpreter (defaults to python3).
                      Alternatively set the PYTHON envvar.
  macsdk=version      Compile against a Mac OS X SDK instead of using the system
                      headers and libraries. Specify the SDK version, e.g. 10.4.
                      You'll need the relevant SDK installed in /Developer/SDKs
                      and may want to use a copy of FB built against that SDK.
                      Also sets macosx-version-min (defaults to 10.4).
  frameworks=...      (Mac only) A comma-separated list of frameworks to link to
                      rather than to .dylibs. By default always uses frameworks.
                      "frameworks=" links only to .dylibs. Use this if
                      SDL/SDL_mixer have been installed using a package manager
                      like MacPorts or Nix. Creates non-distributable binaries.
  libdir=PATH         A directory containing libraries passed with -L to linker
                      and also (Unix only) sets filenames for runtime linking
                      (E.g. libdir=linux/x86)
  prefix=PATH         For 'install' and 'uninstall' actions. Default: '/usr'
  destdir=PATH        For 'install' and 'uninstall' actions. Use if you want to
                      install into a staging area, for a package creation tool.
                      Default: ''
  dry_run=1           For 'uninstall' only. Print files that would be deleted.
  buildtests=0        Affects test targets only: run tests without recompiling
                      anything or reimporting scripts.
  v=1                 Verbose output from commands.
  linkgcc=0           Link using fbc instead of gcc/clang. May not work.
  compiler=gcc|clang|...   Prefer to use clang/gcc/... for C, C++ and -gen gcc.
                      Defaults to gcc (and g++), or emcc for web builds.
                      CC, CXX, FBCC environmental variables always take
                      precedence if set, but this sets the defaults.
                      After compiler= and CC/CXX/FBCC we fallback to cc/c++.
                      Note that -exx is disabled if using clang for -gen gcc.
  builddir=PATH       Directory to use for .o files and cache. Default: 'build'
  transpiledir=PATH   Don't build binaries, instead transpile all FB modules to
                      .c files, and copy all .c and .cpp files together with
                      needed headers to PATH (after deleting existing contents).
                      Also outputs .txt files with compile/link flags.
  android-source=1    Transpile to android/tmp and write android/extraconfig.cfg,
                      part of the Android build process.
                      (See wiki for explanation.) Note: defaults to the original
                      armeabi ABI, which is becoming obsolete, c.f. 'arch='.
  glibc=0|1           Override automatic detection of GNU libc (detection just
                      checks for Linux).
  target=...          Set cross-compiling target. Passed through to fbc. Either:
                      -a toolchain prefix triplet e.g. arm-linux-androideabi
                       (will be prefixed to names of tools like gcc/as/ld/, e.g.
                       arm-linux-androideabi-gcc)
                      -any target name supported by fbc, e.g.
                       win32, linux, darwin, freebsd, android
                       or a platform-cpu pair, e.g. linux-arm
                      -js (Emscripten, produces an .html), short for js-asmjs
                      -node.js (produce <target>.js that can be run with node.js)
                      Current (default) value: """ + target + """
  arch=ARCH           Specify target CPU type. Overrides 'target'. Options
                      include:
                       x86, x86_64        x86 Desktop PCs, Android devices.
                       arm or armeabi     Older 32-bit ARM devices w/o FPUs.
                           or arm5vte     (Android default.)
                       armv7-a            Newer 32-bit ARM devices w/ FPUs,
                                          like RPi2+.
                       arm64 or aarch64   64-bit ARM devices.
                         or arm64-v8a
                       32 or 64           32 or 64 bit variant of the default
                                          arch (x86 or ARM).
                      Current (default) value: """ + arch + """
  wasm=0|1|2          (For Emscripten)
                      0: compile to asm.js to support older browsers
                      1: (default) compile to WebAssembly
                      2: compile to both and select best at runtime.
  sse2=0              (x86 only). Disable SSE & SSE2 instructions to support
                      Pentium Pro+ rather than Pentium 4+. Runs slower.
  eulib=...           Only needed when cross-compiling hspeak. Path to eu.a
                      library compiled for the target platform.
  portable=1          (For Linux and BSD) Try to build portable binaries, and
                      check library dependencies.
  win95=1             (For Windows) Support old Windows versions. (By default
                      stock Win95 isn't supported.) Changes default backends.

The following environmental variables are also important:
  FBFLAGS             Pass more flags to fbc
  FBC                 Override FB compiler (alternative to passing fbc=...)
  PYTHON              Override Python  (alternative to passing python=...)
  AS, CC, CXX         Override assembler/compiler. Should be set when
                      crosscompiling unless target=... is given instead.
  FBCC                Used only to compile C code generated from FB code
                      (e.g. when using gengcc=1).
                      If compiler=gcc|clang this defaults to gcc or clang,
                      otherwise to CC unless CC appears to be clang, then it
                      defaults to gcc.
  GCC                 Alias for FBCC.
  OHRGFX, OHRMUSIC    Specify default gfx, music backends
  DXSDK_DIR, Lib,
     Include          For compiling gfx_directx.dll
  EUC                 euc Euphoria-to-C compiler, for compiling hspeak
  EUBIND              eubind Euphoria binder, produces hspeak in debug builds
  EUDIR               Override location of the Euphoria installation, for
                      compiling hspeak (not needed if installed system-wide)
  SOURCE_DATE_EPOCH   Override the build date.
  SCONS_CACHE_SIZE    Max size of the compile results cache in MB; default 100.
                      Set to 0 to disable the cache.

Targets (executables to build):
  """ + gamename + """ (or game)
  """ + editname + """ (or custom)
  gfx_directx.dll
  unlump
  relump
  hspeak              HamsterSpeak compiler (note: arch and target ignored)
                      Requires Euphoria. (If you get compile errors try release=0)
  dumpohrkey          Convert .ohrkeys to text
  bam2mid             Convert .bam to .mid
  imageconv           Convert between png/bmp/jpg/gif (suggest using gfx=dummy)
  reload2xml
  xml2reload          Requires libxml2 to build.
  reloadutil          To compare two .reload documents, or time load time
 Automated tests (executables; use "test" target to build and run):
  commontest
  gfxtest
  filetest
  rbtest
  reloadtest
  utiltest
  vectortest
 Non-default automated test targets (not run by "scons test"):
  hspeaktest
 Nonautomated test programs:
  gfx_directx_test    gfx_directx.dll test
  miditest
Other targets/actions:
  install             (Unix only.) Install the OHRRPGCE. Uses prefix and destdir
                      args.
                      Installs files into ${destdir}${prefix}/games and
                      ${destdir}${prefix}/share
  uninstall           (Unix only.) Removes 'install'ed files. Uses prefix,
                      destdir, dry_run args (must be same as when installing).
  reload              Compile all RELOAD utilities.
  autotest            Runs autotest.rpgdir. See autotest.py for a better tool to
                      check differences.
  interactivetest     Runs interactivetest.rpg with recorded input.
  test (or tests)     Compile and run all automated tests, including
                      autotest.rpg.
  .                   Compile everything and run all tests

With no targets specified, compiles game and custom.

Examples:
 Do a debug build of Game and Custom:
  scons
 Do a release build (same as official releases) of everything and run tests:
  scons release=1 . test
 Specifying graphics and music backends for a debug build of Game:
  scons gfx=sdl+fb music=native game
 Compile one file at a time, to avoid mixed-up error messages:
  scons -j1
 Create a fully optimised 64 bit build with debug symbols:
  scons arch=64 release=1 debug=1 .
 Create a release build supporting Windows 95+ (Windows only):
  scons win95=1 sse2=0 release=1  .
 A release build against Linux prebuilt libraries:
  scons release=1 libdir=linux/x86_64
 Compile and install (Unix only):
  sudo scons install prefix=/usr/local

After compiling, you can run ohrpackage.py to package results for distribution.
""")
