'OHRRPGCE - Some Custom/Game common code
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
'
' This header can be included by Game, Custom, or any utility,
' and contains functions which have two implementations: in
' common.rbas (for Game and Custom, and in common_base.bas (all else).

#ifndef COMMON_BASE_BI
#define COMMON_BASE_BI

#include "config.bi"
#include "const.bi"

type SliceFwd as Slice

declare sub debug (msg as const zstring ptr)
declare sub debuginfo (msg as const zstring ptr)
declare sub debugerror (msg as const zstring ptr)
declare sub fatalerror (msg as const zstring ptr)
declare sub fatalbug (msg as const zstring ptr)
declare sub visible_debug (msg as const zstring ptr)
declare sub reporterr (msg as zstring ptr, errlvl as scriptErrEnum = serrBadOp, context as zstring ptr = NULL, context_slice as SliceFwd ptr = NULL)

extern "C"
declare sub early_debuginfo (msg as const zstring ptr)
declare sub onetime_debug (errorlevel as errorLevelEnum = errDebug, msg as const zstring ptr)

declare sub showerror_internal (callsite as any ptr, msg as const zstring ptr, isfatal as bool = NO, isbug as bool = NO)
declare sub debugc_internal (callsite as any ptr, errorlevel as errorLevelEnum, msg as const zstring ptr)

'In miscc.c
declare sub showbug (msg as const zstring ptr)
declare sub showerror (msg as const zstring ptr, isfatal as bool = NO, isbug as bool = NO)
declare sub debugc (errorlevel as errorLevelEnum, msg as const zstring ptr)
end extern

'Called by fatalerror
extern cleanup_function as sub ()

'Global variables
EXTERN workingdir as string
extern "C"
EXTERN app_name as zstring ptr
EXTERN app_log_filename as zstring ptr
EXTERN app_archive_filename as zstring ptr
end extern

'The following are defined in autogenerated build/globals.bas
EXTERN short_version as string
EXTERN version_code as string
EXTERN version_build as string
EXTERN version_buildname as string
EXTERN version_arch as string
EXTERN version_revision as integer
EXTERN version_date as integer
EXTERN version_release_tag as string
EXTERN version_branch as string
EXTERN version_branch_revision as integer
EXTERN long_version as string
EXTERN supported_gfx_backends as string

#endif
