#!/usr/bin/env python3

"""
Various utility functions used by SConscript while building, but could also be
used by other tools.
"""

from __future__ import print_function
import os
import sys
from os.path import join as pathjoin
import subprocess
import platform
import math
import random
import re
import time
import datetime
import glob
try:
    from SCons.Util import WhereIs
except ImportError:
    # If this script is imported from outside scons
    def WhereIs(exename):
        for p in os.environ["PATH"].split(os.pathsep):
            for ext in ("", ".exe", ".bat"):
                path = os.path.join(p, exename + ext)
                if os.path.exists(path):
                    return path
#from SCons.Tool import SourceFileScanner

host_win32 = platform.system() == 'Windows'

########################################################################
# Utilities

def get_command_outputs(cmd, args, shell = True, error_on_stderr = False):
    """Runs a shell command and returns stdout and stderr as strings"""
    if shell:
        # Argument must be a single string (additional arguments get passed as extra /bin/sh args)
        if isinstance(args, (list, tuple)):
            args = ' '.join(args)
        cmdargs = '"' + cmd + '" ' + args
    else:
        assert isinstance(args, (list, tuple))
        cmdargs = [cmd] + args
    proc = subprocess.Popen(cmdargs, shell=shell, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    outtext = proc.stdout.read().decode().strip()
    errtext = proc.stderr.read().decode().strip()
    proc.wait()  # To get returncode
    if proc.returncode or (error_on_stderr and errtext):
        exit("subprocess.Popen(%s) failed:\n%s\nstderr:%s" % (cmdargs, outtext, errtext))
    return outtext, errtext

def get_command_output(cmd, args, shell = True, ignore_stderr = False):
    """Runs a shell command and returns stdout as a string.
    Halts program on nonzero return or if ignore_stderr=False and anything printed to stderr."""
    # Annoyingly fbc prints (at least some) error messages to stdout instead of stderr
    return get_command_outputs(cmd, args, shell, not ignore_stderr)[0]

########################################################################
# Scanning for FB include files

include_re = re.compile(r'^\s*#include\s+"(\S+)"', re.M | re.I)

# Add an include file to this list if it is autogenerated in build/; these
# count as dependencies even if they don't exist in a clean build.
generated_includes = ['backendinfo.bi']

def scrub_includes(includes, builddir):
    """Remove those include files from a list which scons should ignore
    because they're standard FB/library includes."""
    ret = []
    for fname in includes:
        if fname in generated_includes:
            ret.append(builddir + fname)
        if os.path.isfile(fname):
            # scons should expect include files in rootdir, where FB looks for them
            ret.append('#' + os.path.sep + fname)
    return ret

def basfile_scan(node, env, path, builddir):
    contents = node.get_text_contents()
    included = scrub_includes(include_re.findall(contents), builddir)
    #print str(node) + " includes", included
    return env.File(included)

########################################################################
# Scanning for HS include files

hss_include_re = re.compile(r'^\s*include\s*,\s*"?([^"\n]+)"?', re.M | re.I)

def hssfile_scan(node, env, path):
    """Find files included into a .hss."""
    contents = node.get_text_contents()
    included = []
    subdir = os.path.dirname(node.srcnode().path)
    for include in hss_include_re.findall (contents):
        include = include.strip()
        # Search for the included file in the same directory as 'node'
        check_for = os.path.join(subdir, include)
        if os.path.isfile(check_for):
            include = check_for
        included.append(include)
    #print str(node) + " includes", included
    # Turning into File nodes allows plotscr.hsd & scancode.hsi to be found in the root dir
    return env.File(included)

########################################################################
# Querying svn, git

def missing (name, message):
    print("%r executable not found. It may not be in the PATH, or simply not installed.\n%s" % (name, message))

def query_revision (rootdir, revision_regex, date_regex, ignore_error, *command):
    "Get the SVN revision and date (YYYYMMDD format) from the output of a command using regexps"
    # Note: this is reimplemented in linux/ohr_debian.py
    rev = 0
    date = ''
    output = None
    try:
        f = subprocess.Popen (command, stdout = subprocess.PIPE, stderr = subprocess.PIPE, cwd = rootdir)
        output = f.stdout.read().decode()
        errmsg = f.stderr.read().decode()
        if errmsg and not ignore_error:
            print(errmsg)
    except OSError:
        missing (command[0], '')
        output = ''
    date_match = re.search (date_regex, output)
    if date_match:
       date = date_match.expand ('\\1\\2\\3')
    rev_match = re.search (revision_regex, output)
    if rev_match:
        rev = int (rev_match.group(1))
    return date, rev

def query_svn (rootdir, command):
    """Call with either 'svn info' or 'git svn info'
    Returns a (rev,date) pair, or (0, '') if not an svn working copy"""
    return query_revision (rootdir, 'Revision: (\d+)', 'Last Changed Date: (\d+)-(\d+)-(\d+)', True, *command.split())

def query_git (rootdir):
    """Figure out last svn commit revision and date from a git repo
    which is a git-svn mirror of an svn repo.
    Returns a (rev,date) pair, or (0, '') if not a git repo"""
    if os.path.isdir (os.path.join (rootdir, '.git')):
        # git svn info is terribly slow on Windows, and slow elsewhere, so we don't use it.
        if False and not host_win32 and os.path.isdir (os.path.join (rootdir, '.git', 'svn', 'refs', 'remotes')):
            # If git config settings for git-svn haven't been set up yet, or git-svn hasn't been
            # told to initialise yet, this will take a long time before failing
            date, rev = query_svn (rootdir, 'git svn info')
        else:
            # Try to determine SVN revision ourselves, otherwise doing
            # a plain git clone won't have the SVN revision info
            date, rev = query_revision (rootdir, 'git-svn-id.*@(\d+)', 'Date:\s*(\d+)-(\d+)-(\d+)', False,
                                        *'git log --grep git-svn-id --date short -n 1'.split())
    else:
        date, rev = '', 0
    return date, rev

def query_svn_rev_and_date(rootdir):
    """Determine svn revision and date (datetime.date object), from svn, git, or svninfo.txt
    NOTE: Actually, we return current date instead of svn last-modified date,
    as the source might be locally modified"""
    date, rev = query_git (rootdir)
    if rev == 0:
        date, rev = query_svn (rootdir, 'svn info')
    if rev == 0:
        print("Falling back to reading svninfo.txt")
        date, rev = query_svn (rootdir, 'cat svninfo.txt')
    if rev == 0:
        print()
        print(""" WARNING!!
Could not determine SVN revision, which will result in RPG files without full
version info and could lead to mistakes when upgrading .rpg files. A file called
svninfo.txt should have been included with the source code if you downloaded a
.zip instead of using svn or git.""")
        print()

    # Discard git/svn date and use current date instead because it doesn't reflect when
    # the source was actually last modified.
    # Unless overridden: https://reproducible-builds.org/specs/source-date-epoch/
    if 'SOURCE_DATE_EPOCH' in os.environ:
        build_date = datetime.datetime.utcfromtimestamp(int(os.environ['SOURCE_DATE_EPOCH']))
    else:
        build_date = datetime.date.today()
    #date = build_date.strftime('%Y%m%d')

    return rev, build_date

########################################################################

def get_euphoria_version(EUC):
    """Returns an integer like 40103 meaning 4.1.3"""
    # euc does something really weird when you try to capture stderr. Seems to
    # duplicate stdout to stderr.
    # Using stderr=subprocess.STDOUT to merge stderr back into stdout works around it
    # but only on Linux/Mac
    # This works even if you are redirecting:
    #    scons hspeak 2>&1 | tee
    # Which is important because the nightly builds need to do that
    eucver = subprocess.check_output([EUC, "--version"], stderr=subprocess.STDOUT).decode()
    eucver = re.findall(" v([0-9.]+)", eucver)[0]
    print("Euphoria version", eucver)
    x,y,z = eucver.split('.')
    return int(x)*10000 + int(y)*100 + int(z)

########################################################################

class ToolInfo:
    "Info about a compiler, returned by get_cc_info()"
    def __str__(self):
        return self.path
    def describe(self):
        return self.path + " (" + self.fullversion + ")"

def expand_tool_path(path, always_expand = False):
    """Try to find the file a path refers to, allowing absolute and relative
    paths and checking PATH; returns None if it can't be found.
    If it's in PATH, expand only if always_expand.
    """
    path = os.path.expanduser(path)  # expand ~
    if host_win32:
        if path.startswith('"') and path.endswith('"'):
            path = path[1:-1]
    if os.path.isfile(path):
        return path
    ret = WhereIs(path)
    if ret:
        if always_expand:
            return ret
        return path
    # The CWD gets changed to build/ while SConscript is processed, so look
    # relative to original directory, but then it gets changed back to original
    # dir while compiling, so convert to abspath
    ret = os.path.join("..", path)
    if os.path.isfile(ret):
        return os.path.abspath(ret)
    return None

def findtool(module, envvars, toolname, always_expand = False):
    """Look for a callable program, checking envvars, module variables, relative paths, PATH,
    and $target_prefix.
    Returns None if not found."""
    if not isinstance(envvars, (list, tuple)):
        envvars = envvars,
    for envvar in envvars:
        if os.environ.get(envvar):
            ret = os.environ.get(envvar)
            break
    else:
        if WhereIs(module['target_prefix'] + toolname):
            ret = module['target_prefix'] + toolname
        else:
            ret = toolname
    # standalone builds of FB on Windows do not search $PATH for binaries,
    # so we have to do so for it!
    ret = expand_tool_path(ret, host_win32 or always_expand)
    return ret

########################################################################

def get_cc_info(CC):
    "Process the output of gcc -v or clang -v for program name, version, and target. Returns a ToolInfo"
    # Used to call -dumpfullversion, -dumpversion, -dumpmachine instead
    ret = ToolInfo()
    stdout,stderr = get_command_outputs(CC, ["-v"])  # shell=True just to get "command not found" error
    match = re.search("(\S+) version ([0-9.]+)", stderr)
    match2 = re.search("Target: (\S+)", stderr)
    if not match or not match2:
        exit("Couldn't understand output of %s:\n%s\n%s\n" % (CC, stdout, stderr))
    ret.fullversion = match.group(1) + " " + match.group(2)
    ret.name = match.group(1)
    ret.version = int(match.group(2).replace('.', '')) # Convert e.g. 4.9.2 to 492
    ret.target = match2.group(1)
    ret.is_clang = ret.name == 'clang'
    ret.is_gcc = ret.name == 'gcc'
    ret.path = CC
    return ret

########################################################################
# Querying fbc

def get_fb_info(fbc):
    """Returns FBC, a ToolInfo for the FB compiler containing version and default target and arch info."""
    FBC = ToolInfo()
    fbc = expand_tool_path(fbc)
    if not fbc:
        exit("FreeBasic compiler is not installed! (Couldn't find fbc)")
    FBC.path = fbc
    FBC.name = os.path.basename(fbc)

    # Newer versions of fbc (1.0+) print e.g. "FreeBASIC Compiler - Version $VER ($DATECODE), built for linux-x86 (32bit)"
    # older versions printed "FreeBASIC Compiler - Version $VER ($DATECODE) for linux"
    # older still printed "FreeBASIC Compiler - Version $VER ($DATECODE) for linux (target:linux)"
    fbcinfo = get_command_output(fbc, ["-version"])
    version, date = re.findall("Version ([0-9.]+) ([0-9()-]+)", fbcinfo)[0]
    FBC.fullversion = version + ' ' + date
    # Convert e.g. 1.04.1 into 1041
    FBC.version = (lambda x,y,z: int(x)*1000 + int(y)*10 + int(z))(*version.split('.'))

    fbtarget = re.findall("target:([a-z]*)", fbcinfo)  # Old versions of fbc.
    if len(fbtarget) == 0:
        # New versions of fbc. Format is os-cpufamily, and it is the
        # directory name where libraries are kept in non-standalone builds.
        fbtarget = re.findall(" built for ([a-zA-Z0-9-_]+)", fbcinfo)
        if len(fbtarget) == 0:
            raise Exception("Couldn't determine fbc default target")
    fbtarget = fbtarget[0]
    if fbtarget == 'win64':
        # Special case (including new versions of fbc)
        FBC.default_target, FBC.default_arch = 'win32', 'x86_64'
    elif '-' in fbtarget:
        # New versions of fbc
        FBC.default_target, FBC.default_arch = fbtarget.split('-')
    else:
        # Old versions of fbc, and special case for dos, win32, xbox
        FBC.default_target, FBC.default_arch = fbtarget, 'x86'

    return FBC

########################################################################

def read_codename_and_branch(rootdir):
    """Retrieve codename, branch name and svn revision.
    Note: if branch_rev is -1, the current svn revision should be used."""
    f = open(os.path.join(rootdir, 'codename.txt'), 'rb')
    lines = []
    for line in f:
        line = line.decode('utf8')
        if not line.startswith('#'):
            lines.append(line.rstrip())
    f.close()
    if len(lines) != 3:
        exit('Expected three noncommented lines in codename.txt')
    codename = lines[0]
    branch_name = lines[1]
    branch_rev = int(lines[2])
    return codename, branch_name, branch_rev

def runtime_lib_names(win32, mac, android, frameworks = None, libdir = None):
    "Determine library filenames used for runtime linking"
    libs = {}
    libnames = ['SDL', 'SDL_mixer', 'SDL2', 'SDL2_mixer']
    if win32:
        for libname in libnames:
            libs[libname] = libname + '.dll'
    elif mac:
        for libname in libnames:
            if frameworks == None or libname in frameworks:
                # Libraries inside a .framework have no extension.
                # (This file will normally be a symlink)
                libs[libname] = libname + '.framework/' + libname
            else:
                # Using a package manager such a Macports, Brew, Nix
                libs[libname] = libname + '.dylib'
        # Don't need to check libdir or resolve symlinks
    else:
        # These are passed to dylib_noload, which requires full filenames
        # Defaults (these are symlinks)
        for libname in libnames:
            libs[libname] = 'lib' + libname + '.so'
        # For some reason the SDL 1.2 Android port uses different names
        if android:
            libs['SDL'] = 'libsdl-1.2.so'
            libs['SDL_mixer'] = 'libsdl_mixer.so'

        if libdir:
            # Use the actual specific library names (e.g. in linux/$arch/), reading through symlinks,
            # which aren't included in 'player' packages because they cause trouble on Windows.
            for libname, fname in libs.items():
                link = os.path.join(libdir, fname)
                if os.path.islink(link):
                    libs[libname] = os.path.basename(os.readlink(link))
    return libs

def verprint(mod, builddir, rootdir):
    """
    Generate backendinfo.bi, globals.bas, distver.bat, buildinfo.ini.

    mod:      The SConscript module
    rootdir:  the directory containing this script
    builddir: the directory where object files should be placed
    """
    class AttributeDict:
        def __init__(self, d):
            self.__dict__ = d
    mod = AttributeDict(mod)   # Allow mod.member instead of mod['member']

    def openw(whichdir, filename):
        if not os.path.isdir (whichdir):
            os.mkdir (whichdir)
        return open (os.path.join (whichdir, filename), 'wb')

    def write_file(filename, text):
        with openw(rootdir, filename) as f:
            f.write(text.encode('latin-1'))

    rev, build_date = query_svn_rev_and_date(rootdir)
    date = build_date.strftime('%Y%m%d')

    codename, branch_name, branch_rev = read_codename_and_branch(rootdir)
    if branch_rev <= 0:
        branch_rev = rev

    backendinfo = ["' This file is autogenerated by ohrbuild.verprint()\n"]

    # Backends
    for gfx in mod.gfx:
        if gfx in mod.gfx_map.keys():
            backendinfo.append('#DEFINE GFX_%s_BACKEND' % gfx.upper())
        else:
            exit("Unrecognised gfx backend " + gfx)
    for m in mod.music:
        if m in mod.music_map.keys():
            backendinfo.append('#DEFINE MUSIC_%s_BACKEND' % m.upper())
            backendinfo.append('#DEFINE MUSIC_BACKEND "%s"' % m)
        else:
            exit("Unrecognised music backend " + m)
    tmp = ['gfx_choices(%d) = @%s_stuff' % (i, v) for i, v in enumerate(mod.gfx)]
    backendinfo.append("#DEFINE GFX_CHOICES_INIT  " +\
      " :  ".join (['redim gfx_choices(%d)' % (len(mod.gfx) - 1)] + tmp))

    # Library filenames
    libs = runtime_lib_names(mod.win32, mod.mac, mod.android, mod.frameworks, mod.libdir)
    backendinfo += [
        '#DEFINE LIBSDL_NAME "%(SDL)s"' % libs,
        '#DEFINE LIBSDL2_NAME "%(SDL2)s"' % libs,
        '#DEFINE LIBSDL_MIXER_NAME "%(SDL_mixer)s"' % libs,
        '#DEFINE LIBSDL2_MIXER_NAME "%(SDL2_mixer)s"' % libs,
    ]

    if not mod.gengcc or mod.CC.fullversion == mod.FBCC.fullversion:
        ccversion = mod.CC.fullversion
    else:
        # Using two different C/C++ compilers!
        ccversion = mod.CC.fullversion + ' + ' + mod.FBCC.fullversion

    archinfo = mod.arch
    if mod.arch == '(see target)':
        archinfo = mod.target

    data = {
        'codename': codename, 'date': date, 'arch': archinfo,
        'rev': rev, 'branch_rev': branch_rev, 'branch_name': branch_name,
        'name':   'OHRRPGCE',
        'gfx':    'gfx_' + "+".join(mod.gfx),
        'music':  'music_' + "+".join(mod.music),
        'gfx_list':   ' '.join(mod.gfx),
        'music_list': ' '.join(mod.music),
        'asan':   'AddrSan ' if mod.asan else '',
        'portable': 'portable ' if mod.portable else '',
        'pdb':    'pdb ' if mod.pdb else '',
        'win95':  'Win95 ' if mod.win95 else '',
        'sse2':   'SSE2 ' if (mod.arch == 'x86' and mod.sse2) else '',
        'ccver':  ccversion,
        'fbver':  mod.FBC.fullversion,
        'uname':  platform.uname()[1],
    }
    data['long_version'] = (
        '%(name)s %(codename)s %(date)s.%(rev)s %(gfx)s/%(music)s '
        'FreeBASIC %(fbver)s %(ccver)s %(arch)s %(sse2)s%(asan)s%(win95)s%(portable)s%(pdb)s '
        'Built on %(uname)s'
    ) % data

    globals_bas = [
        "' This file is autogenerated by ohrbuild.verprint()",
        '',
        '#include "common_base.bi"',
        'DIM short_version as string : short_version = "%(name)s %(codename)s %(date)s"' % data,
        'DIM version_code as string : version_code = "%(name)s Editor version %(codename)s"' % data,
        'DIM version_build as string : version_build = "%(date)s.%(rev)s %(gfx)s %(music)s"' % data,
        'DIM version_arch as string : version_arch = "%(arch)s"' % data,
        'DIM version_revision as integer = %(rev)d' % data,
        'DIM version_date as integer = %(date)s' % data,
        'DIM version_branch as string : version_branch = "%(branch_name)s"' % data,
        'DIM version_branch_revision as integer = %(branch_rev)s' % data,
        ('DIM long_version as string : long_version = "%(long_version)s"') % data,
        ('DIM supported_gfx_backends as string : supported_gfx_backends = "%(gfx_list)s "' % data),
    ]

    buildinfo = [
        "[buildinfo]",
        "packaging_version=1",
        "long_version=%(long_version)s",
        "build_date=%(date)s",
        "svn_rev=%(rev)s",
        "code_name=%(codename)s",
        "arch=%(arch)s",
        "gfx=%(gfx_list)s",
        "music=%(music_list)s",
    ]

    write_file(builddir + 'backendinfo.bi',
               '\n'.join (backendinfo) + '\n')
    write_file(builddir + 'globals.bas',
               '\n'.join (globals_bas) + '\n')
    write_file(rootdir + 'buildinfo.ini',
               '\n'.join(buildinfo) % data + '\n')
    write_file('distver.bat',
               ('SET OHRVERCODE=%s\n' % codename +
                'SET OHRVERBRANCH=%s\n' % branch_name +
                'SET OHRVERDATE=%s\n' % build_date.strftime('%Y-%m-%d') +
                'SET SVNREV=%s' % rev))

########################################################################
# Embedding data files

def generate_datafiles_c(source, target, env):
    """Generates datafiles.c ('target') which contains contents of all the files in 'source',
    plus a table of the embedded files."""

    def symname(path):
        return '_data_' + os.path.basename(path).replace('.', '_').replace(' ', '_')

    #ret = 'struct EmbeddedFileInfo {const char *path; const char *data; int length;};\n\n'
    ret = '#include "../filelayer.hpp"\n\n'

    # ld can directly turn files into .o modules, but it's not much trouble to do it ourselves
    for path in source:
        path = str(path)
        with open(path, 'rb') as datafile:
            ret += 'const char %s[] = {\n' % symname(path)
            data = datafile.read()
            for offset in range(0, len(data), 40):
                row = data[offset : offset + 40]
                ret += '  ' + ','.join(str(byte) for byte in bytearray(row)) + ',\n'
            ret += '};\n\n'

    ret += 'EmbeddedFileInfo *embedded_files_table = (EmbeddedFileInfo[]){\n'
    for idx, path in enumerate(source):
        path = str(path).replace('\\', '/')
        ret += '  {"%s", %s, %d},\n' % (path, symname(path), os.stat(path).st_size)
    ret += '  {NULL, NULL, 0},\n'
    ret += '};\n'

    with open(str(target[0]), 'w') as outf:
        outf.write(ret)

########################################################################
# Android

def android_source_actions (env, sourcelist, rootdir, destdir):
    """Returns a pair (source_nodes, actions) for android-source=1 builds.
    The actions symlink & copy a set of C and C++ files to destdir (which is android/tmp/),
    including all C/C++ sources and C-translations of .bas files.
    """
    source_files = []
    source_nodes = []
    for node in sourcelist:
        assert len(node.sources) == 1
        # If it ends with .bas then we can't use the name of the source file,
        # since it doesn't have the game- or edit- prefix if any;
        # use the name of the resulting target instead, which is an .o
        if node.sources[0].name.endswith('.bas'):
            source_files.append (node.abspath[:-2] + '.c')
            # 'node' is for an .o file, but actually we pass -r to fbc, so it
            # produces a .c instead of an .o output. SCons doesn't care that no .o is generated.
            source_nodes += [node]
        else:
            # For any .c file that lives in rootdir, node.sources[0] is a path in build/
            # (to a nonexistent file), and I have no idea why, while .srcnode() is the
            # actual source file path
            if os.path.isfile(node.sources[0].abspath):
                print(node.sources[0].abspath)
                source_files.append (node.sources[0].abspath)
            else:
                source_files.append (node.sources[0].srcnode().abspath)
            source_nodes += node.sources

    # hacky. Copy the right source files to a temp directory because the Android.mk used
    # by the SDL port selects too much.
    # The more correct way to do this would be to use VariantDir to get scons
    # to automatically copy all sources to destdir, but that requires teaching it
    # that -gen gcc generates .c files. (Actually, I think it knows that now)
    actions = ['rm -fr %s/*' % destdir]
    # This actually creates the symlinks before the C/C++ files are generated, but that's OK
    processed_dirs = set()
    for src in source_files:
        relsrc = src.replace(rootdir, '').replace('build' + os.path.sep, '')
        srcdir, _ = os.path.split(relsrc)
        newdir = os.path.join(destdir, srcdir)
        if srcdir not in processed_dirs:
            # Create directory and copy all headers in it
            processed_dirs.add(srcdir)
            actions += ['mkdir -p ' + newdir]
            # Glob doesn't support {,} syntax
            # I couldn't figure out how to use SourceFileScanner to find headers
            for header in env.Glob(pathjoin(srcdir, '*.h')) + env.Glob(pathjoin(srcdir + '*.hpp')):
                actions += ['ln -s %s %s/' % (header, newdir)]
        actions += ['ln -s %s %s' % (src, newdir)]
    # Cause build.sh to re-generate Settings.mk, since extraconfig.cfg may have changed
    actions += ['touch %s/android/AndroidAppSettings.cfg' % rootdir]
    return source_nodes, actions

########################################################################
# Manipulating binaries

# ___fb_ctx is decorated version on Windows
keep_symbols = ['__fb_ctx', '___fb_ctx']

def strip_nonfunction_symbols(binary, target_prefix, builddir, env):
    """Modifies a binary in-place, stripping symbols for global variables
    and undefined symbols (e.g. left behind by --gc-sections)"""
    nm = WhereIs(target_prefix + "nm")
    syms = get_command_output(nm, [binary], False)
    symfilename = os.path.relpath(builddir + binary + '.unwanted_symbols')
    with open(symfilename, 'w') as symfile:
        for line in syms.split('\n'):
            toks = line.strip().split(' ')
            if len(toks) == 3:
                address, symtype, symbol = toks
            else:
                symtype, symbol = toks
            assert len(symtype) == 1
            # Remove the following symbols:
            # U: undefined symbols
            # b/B, d/D, r/R: local/global variables (uninitialised, initalised, readonly)
            #    These are no use to the crash handler, only to gdb.
            # i: DLL junk (Windows only), not needed in a linked binary
            if symtype in 'UbBdDrRi':
                if symbol not in keep_symbols:
                    symfile.write(symbol + '\n')
    objcopy = WhereIs(target_prefix + "objcopy")
    env.Execute(objcopy + ' --strip-symbols ' + symfilename + ' ' + binary)


########################################################################
# SCons cache

def init_cache_dir(cache_dir):
   """If it doesn't already exist, initialise the cache with prefix_len=1.
   This is a completely unnecessary step; it just speeds up cache pruning a bit by not creating 256 directories.
   Equivalent to  "scons-configure-cache --prefix-len 1 build/cache/" """
   if os.path.isdir(cache_dir):
       return
   os.makedirs(cache_dir)
   with open(os.path.join(cache_dir, 'config'), 'w') as config:
       config.write('{"prefix_len": 1}')

def prune_cache_dir(cache_dir, cache_size_limit):
    """Prune the cache dir to be approximately less than the size limit, in bytes."""
    # Adapted from https://github.com/garyo/scons-wiki/wiki/LimitCacheSizeWithProgress
    now = time.time()
    hashprefix = ''
    # Uncomment on only iterate over a random 1/4th of the cache
    #cache_size_limit /= 4
    #hashprefix = '[%s]' % ''.join(random.sample("0123456789ABCDEF", 4))

    # Gather a list of (path, (size, atime)) for each cached file
    file_stat = [(path, os.stat(path)[6:8]) for path in
                 glob.glob(os.path.join(cache_dir, hashprefix + '*', '*'))]

    # Sort the cache files by most sensible to keep (lower weight: smaller and more recent) first,
    # creating a list with entries (weight, path, size, timeago).
    time_scale = 60*60
    file_stat = [(size ** 0.35 * (1 + (now - atime) / time_scale), path, size, now - atime) for (path, (size, atime)) in file_stat]
    file_stat.sort()

    # Search for the first entry where the storage limit is reached and delete the rest
    partialsum = 0
    pruned, prunedsize = 0, 0
    for mark, (weight,path,size,timeago) in enumerate(file_stat):
        partialsum += size
        #print("size=  %10d weight= %.1f hoursago= %.2f" % (size, weight, timeago/(60*60)))
        if partialsum > cache_size_limit:
            os.remove(path)
            pruned += 1
            prunedsize += size
    if pruned:
        print("Pruned %d file(s) (%.0fMB) from cache" % (pruned, prunedsize/1024./1024.))
    #print("done in %f" % (time.time() - now))
