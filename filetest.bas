'OHRRPGCE - Testcases for file IO
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

' These tests focus on OPENFILE and other basic functions in filelayer.cpp and util.bas,
' but even OPENFILE tests are not comprehensive (e.g. don't actually test the messaging,
' mechanism, or ACCESS_READ_WRITE, or ACCESS_ANY, etc)

#include "config.bi"
#include "common_base.bi"
#include "testing.bi"
#include "lumpfile.bi"
#include "util.bi"
#include "lib/lodepng_gzip.bi"

#ifdef __FB_UNIX__
	'FB's "crt/unistd.bi" header is missing chmod
	extern "C"
	declare function chmod (path as const zstring ptr, mode as long) as long
	end extern
#endif

dim shared fh as integer
dim shared num_errors as integer = 0

#define DBG(x)
'#define DBG(x) ?x

#if defined(__FB_UNIX__)
	' Mac, Linux
        #define UNREADABLE_FILE "_testunreadable.tmp"
#elseif defined(__FB_WIN32__)
	' Don't have an easy example of an unreadable file
#endif

startTest(OPEN)
	fh = freefile
	' Need to be in a writable dir
	if open("_writetest.tmp" access write as fh) then fail
	print #fh, "text"
	if close(fh) then fail
endTest

' Hook everything
function openhook_filter(filename as string, writable as boolint, writes_allowed as boolint) as FilterActionEnum
	DBG("openhook_filter(" & filename & ", " & writable & ", " & writes_allowed & ")")
	if writes_allowed = NO and writable then
		DBG("(disallowed)")
		num_errors += 1
		return FilterActionEnum.deny
	end if
	return FilterActionEnum.hook
end function

' Allow writing to hooked files
set_OPEN_hook @openhook_filter, YES

startTest(explicitReadNonexistentFiles)
	' Cleanup from previous failure
	safekill "_nonexistent_file.tmp"

	if openfile("_nonexistent_file.tmp", for_binary + access_read, fh) = 0 then
		? "Opening nonexistent file should have failed"
		fail
	end if
endTest

startTest(cantCloseInvalidFiles)
	if close(fh) = 0 then fail
endTest

startTest(writeToFile)
	' Opening a file without explicitly asking for read or write results
	' in a writable file handle.
	if openfile("_testfile.tmp", for_binary, fh) then fail
	print #fh, "hello"
	print #fh, "bye"
	if close(fh) then fail
	'Some data for gzip to chew on
	if openfile("_testgz.tmp", for_binary, fh) then fail
	put #fh, , string(100000, "l")
	for i as integer = 1 to 1000
		put #fh, 1 + i * 10, "hello" & i
	next
	if close(fh) then fail
endTest

startTest(readFile)
	if openfile("_testfile.tmp", for_binary + access_read, fh) then fail

	dim as string line1, line2
	input #fh, line1
	input #fh, line2
	close fh
	if line1 <> "hello" then fail
	if line2 <> "bye" then fail

	if openfile("_testgz.tmp", for_binary + access_read, fh) then fail
	if lof(fh) <> 100000 then fail
	dim as string buffer = space(10)
	get #fh, 87, buffer
	if buffer <> "llllhello9" then fail
	close fh
endTest

startTest(openForReadWriteOk)
	if openfile("_testfile.tmp", for_binary + access_read_write, fh) then fail
	' The length is 10 on unix and 12 on windows
	if lof(fh) <> 10 andalso lof(fh) <> 12 then fail
	close fh
	' Should be the same, default is access_read_write
	if openfile("_testfile.tmp", for_binary, fh) then fail
	if lof(fh) <> 10 andalso lof(fh) <> 12 then fail
	close fh
endTest

startTest(openForWriteTruncates)
	if openfile("_testfile.tmp", for_binary + access_write, fh) then fail
	if lof(fh) <> 0 then fail
	close fh
	if real_isfile("_testfile.tmp") = NO then fail
endTest

startTest(makeReadOnly)
	' setwriteable only implemented on Windows
	#ifdef __FB_WIN32__
		' Cleanup previous run
		if isfile("_testreadonly.tmp") then
			setwriteable("_testreadonly.tmp", YES)
			safekill("_testreadonly.tmp")
		end if

		if openfile("_testreadonly.tmp", for_binary, fh) then fail
		if close(fh) then fail
		if setwriteable("_testreadonly.tmp", NO) = NO then fail
	#else
		skip_test
	#endif
endTest

startTest(makeUnreadable)
	#ifdef __FB_UNIX__
		if real_isfile("_testunreadable.tmp") then
			safekill("_testunreadable.tmp")
		end if
		touchfile "_testunreadable.tmp"
		if chmod("_testunreadable.tmp", &o000) then fail
	#else
		skip_test
	#endif
endTest

startTest(get_file_type)
	if get_file_type("") <> fileTypeDirectory then fail  ' "" is the current directory
	if get_file_type("_testfile.tmp") <> fileTypeFile then fail
	if get_file_type(curdir & SLASH & "_testfile.tmp") <> fileTypeFile then fail
	if get_file_type("_nonexistent_file.tmp") <> fileTypeNonexistent then fail
	if get_file_type("_nonexistent_file.tmp") <> fileTypeNonexistent then fail  ' Didn't create it
	if get_file_type("_nonexistent_file.tmp" SLASH) <> fileTypeNonexistent then fail
	if get_file_type(curdir) <> fileTypeDirectory then fail
	if get_file_type(curdir & SLASH & "..") <> fileTypeDirectory then fail
	if get_file_type("/foo/bar/") <> fileTypeNonexistent then fail  ' Not a valid path
	' Will print an error message on Unix (is a file, not a dir)
	#ifdef __FB_UNIX__
		? !"\nIgnore 1 error:"
	#endif
	if get_file_type("_testfile.tmp" SLASH "file") <> fileTypeNonexistent then fail
	' Read-only and special files/dirs
	#ifdef UNREADABLE_FILE
		if get_file_type(UNREADABLE_FILE) <> fileTypeFile then fail
	#endif
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if get_file_type("/bin/sh") <> fileTypeFile then fail
		if get_file_type("/bin/") <> fileTypeDirectory then fail
		if get_file_type("/dev/tty") <> fileTypeOther then fail
	#elseif defined(__FB_WIN32__)
		if get_file_type("_testreadonly.tmp") <> fileTypeFile then fail
		if get_file_type("C:\windows\") <> fileTypeDirectory then fail   'Note: not actually readonly
		' Oops, this doesn't actually work, I guess GetFileAttributes can't be used for devices
		'if get_file_type("\\.\C:") <> fileTypeOther then fail  ' Drive device
	#endif
endTest

startTest(fileisreadable)
	? !"\nIgnore ""no filename"" warning:"
	if fileisreadable("") then fail
	if fileisreadable("_testfile.tmp") = NO then fail
	if fileisreadable("_nonexistent_file.tmp") then fail
	if fileisreadable(CURDIR) then fail   ' OPENing a directory works on Linux
	if fileisreadable("_nonexistent_dir.tmp" & SLASH) then fail
	' Read-only and unreadable files
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if fileisreadable("/bin/sh") = NO then fail
	#elseif defined(__FB_WIN32__)
		if fileisreadable("_testreadonly.tmp") = NO then fail
	#endif

	' isfile is just an alias for fileisreadable, so should behave the same
	#ifdef UNREADABLE_FILE
                'FIXME: Prints "Error 2" (file not found) on BSD and Linux
		if fileisreadable(UNREADABLE_FILE) then fail
	#endif
endTest

startTest(real_isfile)
	? !"\nIgnore ""no filename"" warning:"
	if real_isfile("") then fail
	if real_isfile("_testfile.tmp") = NO then fail
	if real_isfile("_nonexistent_file.tmp") then fail
	if real_isfile(CURDIR) then fail   ' OPENing a directory works on Linux
	if real_isfile("_nonexistent_dir.tmp" & SLASH) then fail
	' Read-only and unreadable files
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if real_isfile("/bin/sh") = NO then fail
	#elseif defined(__FB_WIN32__)
		if real_isfile("_testreadonly.tmp") = NO then fail
	#endif
	#ifdef UNREADABLE_FILE
                'FIXME: Prints "Error 2" (file not found) on BSD and Linux
		if real_isfile(UNREADABLE_FILE) = NO then fail
	#endif
endTest

startTest(fileiswriteable)
	? !"\nIgnore ""no filename"" warning:"
	if fileiswriteable("") then fail
	if fileiswriteable("_testfile.tmp") = NO then fail
	if fileiswriteable("_nonexistent_file.tmp") = NO then fail
	if isfile("_nonexistent_file.tmp") then fail   ' Should not have created it
	if fileiswriteable(CURDIR) then fail
	' A read-only file
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if fileiswriteable("/bin/sh") then fail
	#elseif defined(__FB_WIN32__)
		if fileiswriteable("_testreadonly.tmp") then fail
	#endif
endTest

'This exercises opening files for write and deleting them
startTest(diriswriteable)
	#ifdef __FB_UNIX__
		? !"\nIgnore 3 errors:"
	#endif
	if diriswriteable("_testfile.tmp") then fail   ' Will print three error messages on Unix
	if diriswriteable("/tmp/doesnt/exist/surely") then fail
	' We already checked curdir is writable
	if diriswriteable(".") = NO then fail
	if diriswriteable("") = NO then fail
	if diriswriteable("_nonexistent_file.tmp") then fail  ' Shouldn't work if not created yet
	if diriswriteable("_nonexistent_file.tmp" SLASH) then fail
	if get_file_type("_nonexistent_file.tmp") <> fileTypeNonexistent then fail  ' Shouldn't have created
	' A read-only directory
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if diriswriteable("/bin/") then fail
	#elseif defined(__FB_WIN32__)
		' On NTFS under Windows, the readonly attribute on a folder does nothing, have to use ACLs
		' or a different filesystem to prevent new files!
		'if diriswriteable("C:\windows") then fail
	#endif
endTest

startTest(isdir)
	if isdir("") = NO then fail  'Current directory
	if isdir("_testfile.tmp") then fail
	if isdir("/tmp/doesnt/exist/surely") then fail
	if isdir(".") = NO then fail
	if isdir(absolute_path(CURDIR)) = NO then fail
	if isdir("_nonexistent_file.tmp") then fail
	if isdir("_nonexistent_file.tmp" SLASH) then fail
	if get_file_type("_nonexistent_file.tmp") <> fileTypeNonexistent then fail  ' Shouldn't have created
	' Read-only directories
	#if defined(__FB_UNIX__) and not defined(MINIMAL_OS)
		if isdir("/bin/") = NO then fail
		if isdir("/") = NO then fail
	#elseif defined(__FB_WIN32__)
		' Under Windows, these aren't readonly, don't have any examples of read-only directories!
		if isdir("C:\windows") = NO then fail
		if isdir("C:\") = NO then fail
	#endif
endTest

startTest(makeWritable)
	' setwriteable only implemented on Windows
	#ifdef __FB_WIN32__
		if setwriteable("_testreadonly.tmp", YES) = NO then fail
		if fileisreadable("_testreadonly.tmp") = NO then fail
		if safekill("_testreadonly.tmp") = NO then fail
	#else
		skip_test
	#endif
endTest

startTest(unreadableCleanup)
	#ifndef __FB_WIN32__
		if safekill("_testunreadable.tmp") = NO then fail
		if real_isfile("_testunreadable.tmp") then fail
	#else
		skip_test
	#endif
endTest

sub error_counter cdecl (byval errorlevel as ErrorLevelEnum, byval msg as zstring ptr)
	DBG("(error reported: " & *msg & ")")
	if errorlevel > errShowBug then
		? "unexpected error (errlvl=" & errorlevel & "): " & *msg
		end 1
	end if
	num_errors += 1
end sub

set_debug_hook(@error_counter)

' Now disallow writes
set_OPEN_hook @openhook_filter, NO

startTest(openForWriteFails)
	if openfile("_testfile.tmp", for_binary + access_write, fh) = 0 then
		? "should have failed"
		fail
	end if
	if num_errors <> 1 then fail
endTest

' Opening a file without explicitly asking for read or write now results
' in a read-only open.
startTest(implicitlyReadonly)
	num_errors = 0
	' Can open existing files
	if openfile("_testfile.tmp", for_binary, fh) then fail
	' They're opened for reading only
	print #fh, "something"
	if num_errors < 1 then fail  ' A single print can cause multiple write errors
	' A write-error does not close the file
	if close(fh) then fail

	' Can't open non-existing files, that requires opening for writing
	num_errors = 0
	if openfile("_nonexistent_file.tmp", for_binary, fh) = 0 then fail
	' NOTE: We don't get an error message printed here, because the hook filter doesn't
	' know that the file doesn't exist; instead FB returns 'file not found'
endTest

' Partial test only
startTest(killDir)
	? !"\nIgnore 1 error:"
	killdir("_testfile.tmp")  'Is a file
	if real_isfile("_testfile.tmp") = NO then fail
endTest

startTest(killFile)
	if killfile("_testfile.tmp") = NO then fail
	if killfile("_writetest.tmp") = NO then fail
	if fileisreadable("_testfile.tmp") then fail
endTest

clear_OPEN_hook

startTest(canWriteAgain)
	num_errors = 0
	if openfile("_testfile.tmp", for_binary, fh) then fail
	print #fh, "something else"
	if close(fh) then fail
	if killfile("_testfile.tmp") = NO then fail
	if num_errors <> 0 then fail
endTest

set_debug_hook(NULL)

startTest(touchfile)
	touchfile "_writetest.tmp"
	if real_isfile("_writetest.tmp") = NO then fail
endTest

startTest(lazyclose)
	string_to_file "text", "_writetest.tmp"

	if openfile("_writetest.tmp", for_binary + access_read, fh) then fail
	seek fh, 3
	if seek(fh) <> 3 then fail
	if lazyclose(fh) then fail

	'Reopen resets position
	if openfile("_writetest.tmp", for_binary + access_read, fh) then fail
	if seek(fh) <> 1 then fail
	dim istr as string
	input #fh, istr
	if istr <> "text" then fail
	if lazyclose(fh) then fail

	'Check double-close detection
	print "Ignore two BUG errors:"
	if lazyclose(fh) = 0 then fail
	if close(fh) = 0 then fail

	'Will open a new file since the mode differs (fh will be closed).
	dim fh2 as integer
	if openfile("_writetest.tmp", for_binary + access_write, fh2) then fail  'truncates
	if lof(fh2) <> 0 then fail
	put #fh2, , "output"
	if lazyclose(fh2) then fail

	'Check lazyclosing a file written to flushes changes
	fh = freefile
	if open("_writetest.tmp" for binary access read as fh) then fail
	if lof(fh) <> 6 then fail
	input #fh, istr
	if istr <> "output" then fail
	if close(fh) then fail
endTest

dim shared as string gz_infile, gz_outfile, gz_outfile2
'gz_infile = trimextension(command(0)) & DOTEXE
gz_infile = "_testgz.tmp"
gz_outfile = "_testfile.tmp.gz"
gz_outfile2 = "_testfile.tmp"

startTest(gzipWrite)
	'Read
	dim indata as string = read_file(gz_infile)
	'Compress
	dim outdata as byte ptr
	dim outdatasize as size_t
	dim starttime as double = timer
	if compress_gzip(strptr(indata), len(indata), @outdata, @outdatasize) then fail
	? !"\n  lodepng compressed in " & cint((timer - starttime) * 1e3) & " ms"
	? "  lodepng compressed size = " & outdatasize
	'Write
	dim fil as FILE ptr
	fil = fopen(strptr(gz_outfile), "wb")
	if fil = NULL then fail
	if fwrite(outdata, 1, outdatasize, fil) <> outdatasize then fail
	fclose(fil)
	deallocate outdata
	#ifdef MINIMAL_OS
	'Don't test decompression with gzip
	#else
	'Decompress
	starttime = timer
	if safe_shell("gzip -d " & gz_outfile) then fail
	? "  gzip decompressed in " & cint((timer - starttime) * 1e3) & " ms"
	'Read result and check
	dim indata2 as string = read_file(gz_outfile2)
	if indata <> indata2 then fail
	safekill(gz_outfile2)
	#endif
endTest

startTest(gzipRead)
	dim starttime as double
	#ifdef MINIMAL_OS
	'Reuse gz_outfile created by gzipWrite instead of file created by gzip
	#else
	'Compress
	starttime = timer
	if safe_shell("gzip -9 -c " & gz_infile & " > " & gz_outfile) then fail
	? "  gzip compressed in " & cint((timer - starttime) * 1e3) & " ms"
	#endif
	'Read
	dim gzipdata as string = read_file(gz_outfile)
	? "  gzip compressed size = " & len(gzipdata)
	'Decompress
	dim outdata as byte ptr
	dim outdatasize as size_t
	starttime = timer
	if decompress_gzip(strptr(gzipdata), len(gzipdata), @outdata, @outdatasize) then fail
	? "  lodepng decompressed in " & cint((timer - starttime) * 1e3) & " ms"
	? "  original size = " & outdatasize
	'Read original and result and check
	dim indata as string = read_file(gz_infile)
	if outdatasize <> len(indata) then fail
	if memcmp(strptr(indata), outdata, outdatasize) then fail
	deallocate outdata
	if safekill(gz_infile) = NO then fail
	if safekill(gz_outfile) = NO then fail
endTest

startTest(rename)
        string_to_file "output", "_testfile.tmp"
        if filelen("_testfile.tmp") <> 6 then fail
        'Test replacing an existing file
        touchfile "_testfile2.tmp"
        if renamefile("_testfile.tmp", "_testfile2.tmp") = NO then fail
        if real_isfile("_testfile.tmp") then fail
        if real_isfile("_testfile2.tmp") = NO then fail
        if filelen("_testfile2.tmp") <> 6 then fail
endTest

' Can't use filetest_helper under Emscripten
#ifndef MINIMAL_OS

sub before_spawn()
        safekill "_syncfile.tmp"
end sub

function _wait_spawn() as bool
        for tick as integer = 1 to 100
                if real_isfile("_syncfile.tmp") then
                        killfile "_syncfile.tmp"
                        return YES
                end if
                sleep 10
        next
        print "Error: wait_spawn timeout"
        return NO
end function

#define wait_spawn  if _wait_spawn() = NO then fail

dim shared hproc as ProcessHandle

startTest(renameReplaceOpenFile)
        'Precond: _testfile2.tmp contains "output"

        before_spawn
        hproc = open_process("." SLASH "filetest_helper" DOTEXE, "_testfile3.tmp 300 -write -q", NO, YES)  'show_output=YES
        wait_spawn

        #ifdef __FB_WIN32__
                print "Ignore one error (access denied)"
                'Should fall back to a copy+delete, with delete succeeding
        #endif
        dim ttt as double = timer
        if renamefile("_testfile2.tmp", "_testfile3.tmp") = NO then fail
        print "renamefile took " & cint(1e3 * (timer - ttt)) & "ms"

        if filelen("_testfile3.tmp") <> 6 then fail
        if real_isfile("_testfile2.tmp") then fail
	cleanup_process @hproc
endTest

startTest(renameMoveOpenFile)
        'Precond: _testfile3.tmp contains "output"

        before_spawn
        hproc = open_process("." SLASH "filetest_helper" DOTEXE, "_testfile3.tmp 400 -readonly -q", NO, YES)
        wait_spawn

        #ifdef __FB_WIN32__
                print "Ignore two errors (MoveFile & DeleteFile: cannot access)"
                'Should fall back to a copy+delete, with delete failing
        #endif
        if renamefile("_testfile3.tmp", "_testfile4.tmp") = NO then fail

        if filelen("_testfile4.tmp") <> 6 then fail
        #ifdef __FB_UNIX__
                if real_isfile("_testfile3.tmp") then fail   'Will still exist on Windows
        #endif
	cleanup_process @hproc
endTest

startTest(renameShareDeleteFile)
        'Precond: _testfile4.tmp contains "output"

        'FILE_SHARE_DELETE files can be moved without error on Windows
        before_spawn
        hproc = open_process("." SLASH "filetest_helper" DOTEXE, "_testfile4.tmp 300 -sharedelete -q", NO, YES)
        wait_spawn

        if renamefile("_testfile4.tmp", "_testfile5.tmp") = NO then fail

        if filelen("_testfile5.tmp") <> 6 then fail
        'On Windows this produces an Access denied error if filetest_helper still running, but doesn't fail
        if real_isfile("_testfile4.tmp") then fail
	cleanup_process @hproc
endTest

#ifdef __FB_WIN32__
'This only tests renaming a locked file on Windows;
'renamefile doesn't work on locked files on Unix, and filetest_helper doesn't lock them.
startTest(renameLockedFile)
        'Precond: _testfile5.tmp contains "output"

        before_spawn
        hproc = open_process("." SLASH "filetest_helper" DOTEXE, "_testfile5.tmp 500 -lock -q", NO, YES)
        wait_spawn

        #ifdef __FB_WIN32__
                print "Ignore many errors (MoveFile & copy: cannot access)"
        #endif
        dim ttt as double = timer
        if renamefile("_testfile5.tmp", "_testfile6.tmp") = NO then fail
        print "renamefile took " & cint(1e3 * (timer - ttt)) & "ms"

        if filelen("_testfile6.tmp") <> 6 then fail
        if real_isfile("_testfile5.tmp") then fail

        safekill "_testfile6.tmp"
        safekill "_testfile3.tmp"
	cleanup_process @hproc
endTest
#endif

#endif  ' ifndef MINIMAL_OS

? "All tests passed."
