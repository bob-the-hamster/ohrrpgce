# -*- mode:python -*-
"""For build options and OHRRPGCE-specific help run
 scons -h
For SCons usage information run
 scons --help
"""

import os
import sys
import atexit
import ohrbuild

var_dir = ARGUMENTS.get('builddir', 'build')

if sys.platform.startswith('win'):
    # Avoid warning when using the default environment (e.g. calling CacheDir) if Visual Studio isn't installed
    DefaultEnvironment(tools = ['mingw'])

# Use a cache for object files
# SCons has no builtin pruning of or limit on the cache, it just grows forever, so do it ourselves
cache_dir = os.path.join(var_dir, 'cache')
cache_size_limit = float(os.environ.get('SCONS_CACHE_SIZE', 100)) * 1024*1024
if cache_size_limit:
    ohrbuild.init_cache_dir(cache_dir)  # This is completely optional
    CacheDir(cache_dir)
    atexit.register(ohrbuild.prune_cache_dir, cache_dir, cache_size_limit)

SConscript('SConscript', variant_dir = var_dir, duplicate = False)
