'OHRRPGCE - Some utility code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'
' This file contains utility subs and functions which would be useful for
' any FreeBasic program. Nothing in here can depend on Allmodex, nor on any
' gfx or music backend, nor on any other part of the OHR

CONST STACK_SIZE_INC = 512 ' in integers

#include "compat.bi"
#include "util.bi"

#if __FB_LANG__ <> "fb"
OPTION EXPLICIT
#endif

'DECLARE SUB debug (str$)

FUNCTION bound (BYVAL n as integer, BYVAL lowest as integer, BYVAL highest as integer) as integer
bound = n
IF n < lowest THEN bound = lowest
IF n > highest THEN bound = highest
END FUNCTION

FUNCTION bound (BYVAL n AS DOUBLE, BYVAL lowest AS DOUBLE, BYVAL highest AS DOUBLE) AS DOUBLE
bound = n
IF n < lowest THEN bound = lowest
IF n > highest THEN bound = highest
END FUNCTION

FUNCTION large (BYVAL n1 as integer, BYVAL n2 as integer) as integer
large = n1
IF n2 > n1 THEN large = n2
END FUNCTION

FUNCTION loopvar (BYVAL value as integer, BYVAL min as integer, BYVAL max as integer, BYVAL inc as integer) as integer
dim as integer a = value + inc
IF a > max THEN loopvar = a - ((max - min) + 1): EXIT FUNCTION
IF a < min THEN loopvar = a + ((max - min) + 1): EXIT FUNCTION
loopvar = a
END FUNCTION

FUNCTION small (BYVAL n1 as integer, BYVAL n2 as integer) as integer
small = n1
IF n2 < n1 THEN small = n2
END FUNCTION

FUNCTION range (number AS INTEGER, percent AS INTEGER) AS INTEGER
 DIM a AS INTEGER
 a = (number / 100) * percent
 RETURN number + INT(RND * (a * 2)) - a
END FUNCTION

FUNCTION rpad (s AS STRING, pad_char AS STRING, size AS INTEGER) AS STRING
 DIM result AS STRING
 result = LEFT(s, size)
 WHILE LEN(result) < size: result = result & pad_char: WEND
 RETURN result
END FUNCTION

FUNCTION is_int (s AS STRING) AS INTEGER
 'Even stricter than str2int (doesn't accept "00")
 DIM n AS INTEGER = VALINT(s)
 RETURN (n <> 0 ANDALSO n <> VALINT(s + "1")) ORELSE s = "0"
END FUNCTION

FUNCTION str2int (stri as string, default as integer=0) as integer
 'Use this in contrast to QuickBasic's VALINT.
 'it is stricter, and returns a default on failure
 DIM n AS INTEGER = 0
 DIM s AS STRING = LTRIM(stri)
 IF s = "" THEN RETURN default
 DIM sign AS INTEGER = 1

 DIM ch AS STRING
 DIM c AS INTEGER
 FOR i AS INTEGER = 1 TO LEN(s)
  ch = MID(s, i, 1)
  IF ch = "-" AND i = 1 THEN
   sign = -1
   CONTINUE FOR
  END IF
  c = ASC(ch) - 48
  IF c >= 0 AND c <= 9 THEN
   n = n * 10 + (c * sign)
  ELSE
   RETURN default
  END IF
 NEXT i

 RETURN n
END FUNCTION

FUNCTION trimpath(filename as string) as string
'return the file/directory name without path
dim i as integer
for i = 0 to len(filename) -1 
	if filename[i] = asc("\") or filename[i] = asc("/") then filename[i] = asc(SLASH)
next
IF filename <> "" ANDALSO filename[LEN(filename) - 1] = asc(SLASH) THEN
 filename = MID(filename, 1, LEN(filename) - 1)
END IF
IF INSTR(filename,SLASH) = 0 THEN RETURN filename
FOR i = LEN(filename) TO 1 STEP -1
 IF MID(filename, i, 1) = SLASH THEN i += 1 : EXIT FOR
NEXT
RETURN MID(filename, i)
END FUNCTION

FUNCTION trimfilename (filename as string) as string
'return the path without the filename
dim i as integer
for i = 0 to len(filename) -1 
	if filename[i] = asc("\") or filename[i] = asc("/") then filename[i] = asc(SLASH)
next
IF INSTR(filename,SLASH) = 0 THEN RETURN ""
FOR i = LEN(filename) TO 1 STEP -1
 IF MID(filename, i, 1) = SLASH THEN i -= 1 : EXIT FOR
NEXT
RETURN MID(filename, 1, i)
END FUNCTION

FUNCTION trimextension (filename as string) as string
'return the filename without extension
dim as integer i
IF INSTR(filename,".") = 0 THEN RETURN filename
FOR i = LEN(filename) TO 1 STEP -1
 IF MID(filename, i, 1) = "." THEN i -= 1 : EXIT FOR
NEXT
RETURN MID(filename, 1, i)
END FUNCTION

FUNCTION justextension (filename as string) as string
'return only the extension (everything after the *last* period)
FOR i as integer = LEN(filename) TO 1 STEP -1
 dim as string char = MID(filename, i, 1)
 IF char = "." THEN RETURN RIGHT(filename, LEN(filename) - i)
 IF char = SLASH THEN RETURN ""
NEXT
RETURN ""
END FUNCTION

FUNCTION anycase (filename as string) as string
 'make a filename case-insensitive
#IFDEF __FB_LINUX__
 DIM ascii AS INTEGER
 dim as string result = ""
 FOR i as integer = 1 TO LEN(filename)
  ascii = ASC(MID(filename, i, 1))
  IF ascii >= 65 AND ascii <= 90 THEN
   result = result + "[" + CHR(ascii) + CHR(ascii + 32) + "]"
  ELSEIF ascii >= 97 AND ascii <= 122 THEN
   result = result + "[" + CHR(ascii - 32) + CHR(ascii) + "]"
  ELSE
   result = result + CHR(ascii)
  END IF
 NEXT i
 RETURN result
#ELSE
 'Windows filenames are always case-insenstitive
 RETURN filename
#ENDIF
END FUNCTION

SUB touchfile (filename as string)
dim as integer fh = FREEFILE
OPEN filename FOR BINARY AS #fh
CLOSE #fh
END SUB

FUNCTION rotascii (s as string, o as integer) as string
 dim as string temp = ""
 FOR i as integer = 1 TO LEN(s)
  temp = temp + CHR(loopvar(ASC(MID(s, i, 1)), 0, 255, o))
 NEXT i
 RETURN temp
END FUNCTION

FUNCTION escape_string(s AS STRING, chars AS STRING) AS STRING
 DIM i AS INTEGER
 DIM c AS STRING
 DIM result AS STRING
 result = ""
 FOR i = 1 to LEN(s)
  c = MID$(s, i, 1)
  IF INSTR(chars, c) THEN
   result = result & "\"
  END IF
  result = result & c
 NEXT i
 RETURN result
END FUNCTION

SUB createstack (st as Stack)
  WITH st
    .size = STACK_SIZE_INC - 4
    .bottom = allocate(STACK_SIZE_INC * sizeof(integer))
    IF .bottom = 0 THEN
      'oh dear
      'debug "Not enough memory for stack"
      EXIT SUB
    END IF
    .pos = .bottom
  END WITH
END SUB

SUB destroystack (st as Stack)
  IF st.bottom <> 0 THEN
    deallocate st.bottom
    st.size = -1
  END IF
END SUB

SUB checkoverflow (st as Stack, byval amount as integer = 1)
  WITH st
    IF .pos - .bottom + amount >= .size THEN
      .size += STACK_SIZE_INC
      IF .size > STACK_SIZE_INC * 4 THEN .size += STACK_SIZE_INC
      'debug "new stack size = " & .size & " * 4  pos = " & (.pos - .bottom) & " amount = " & amount
      'debug "nowscript = " & nowscript & " " & scrat(nowscript).id & " " & scriptname$(scrat(nowscript).id) 

      DIM newptr as integer ptr
      newptr = reallocate(.bottom, .size * sizeof(integer))
      IF newptr = 0 THEN
        'debug "stack: out of memory"
        EXIT SUB
      END IF
      .pos += newptr - .bottom
      .bottom = newptr
    END IF
  END WITH
END SUB

FUNCTION sign_string(n AS INTEGER, neg_str AS STRING, zero_str AS STRING, pos_str AS STRING) AS STRING
 IF n < 0 THEN RETURN neg_str
 IF n > 0 THEN RETURN pos_str
 RETURN zero_str
END FUNCTION

FUNCTION zero_default(n as integer, zerocaption AS STRING="default", displayoffset AS INTEGER = 0) AS STRING
 IF n = 0 THEN RETURN zerocaption
 RETURN "" & (n + displayoffset)
END FUNCTION

'returns a copy of the string with separators inserted; use together with split()
Function wordwrap(Byval z as string, byval wid as integer, byval sep as string = chr(10)) as string
 dim as string ret, in
 in = z
 if len(in) <= wid then return in
 
 dim as integer i, j
 do
  for i = 1 to small(wid + 1, len(in))
   if mid(in, i, 1) = sep then
    ret &= left(in, i - 1) & sep
    in = mid(in, i + 1)
    continue do
   end if
  next
  
  if i > len(in) then
   ret &= in
   in = ""
   exit do
  end if
  
  
  
  for j = i - 1 to 1 step -1
   if mid(in, j, 1) = " " then
    'bingo!
    ret &= left(in, j - 1) & sep
    in = mid(in, j + 1)
    continue do
   end if
  next
  if j = 0 then 'words too long, we need to cut it off
   ret &= left(in, wid) & sep
   in = mid(in, wid + 1)
  end if
 loop while in <> ""
 
 return ret
 
end function

'Splits a line at the separators; use together with wordwrap() to do wrapping
sub split(byval z as string, ret() as string, sep as string = chr(10))
 redim ret(0)
 dim as integer i = 0, i2 = 1, j = 0
 dim as string in = z
 i = instr(i2, in, sep)
 if i = 0 then
  ret(0) = in
  exit sub
 end if
 do
  redim preserve ret(j) 
  if i = 0 then 
   ret(j) = mid(in, i2)
   exit do
  else
   ret(j) = mid(in, i2, i - i2)
  end if
  i2 = i + 1
  i = instr(i2, in, sep)
  j+=1
 loop
end sub

function textwidth(byval z as string) as integer
 dim lines() as string
 split(z, lines())
 dim ret as integer = 0
 for i as integer = 0 to ubound(lines)
  if len(lines(i)) > ret then ret = len(lines(i))
 next
 return ret * 8
end function

SUB str_array_append (array() AS STRING, s AS STRING)
 REDIM PRESERVE array(UBOUND(array) + 1) AS STRING
 array(UBOUND(array)) = s
END SUB

SUB int_array_append (array() AS INTEGER, k AS INTEGER)
 REDIM PRESERVE array(UBOUND(array) + 1) AS INTEGER
 array(UBOUND(array)) = k
END SUB

FUNCTION int_array_find (array() AS INTEGER, value AS INTEGER) AS INTEGER
 FOR i AS INTEGER = LBOUND(array) TO UBOUND(array)
  IF array(i) = value THEN RETURN i
 NEXT
 RETURN -1
END FUNCTION

'I've compared the speed of the following two. For random data, the quicksort is faster
'for arrays over length about 80. For arrays which are 90% sorted appended with 10% random data,
'the cut off is about 600 (insertion sort did ~5x better on nearly-sort data at the 600 mark)

'Returns, in indices() (assumed to already have been dimmed large enough), indices for
'visiting the data (an array of some kind of struct containing an integer) in ascending order.
'start points to the integer in the first element, stride is the size of an array element, in integers
'Insertion sort. Running time is O(n^2). Much faster on nearly-sorted lists. STABLE
SUB sort_integers_indices(indices() as integer, BYVAL start as integer ptr, BYVAL number as integer, BYVAL stride as integer)
 IF number = 0 THEN number = UBOUND(indices) + 1
 DIM keys(number - 1) as integer
 DIM as integer i, temp
 FOR i = 0 TO number - 1
  keys(i) = *start
  start = CAST(integer ptr, CAST(byte ptr, start) + stride) 'yuck
 NEXT

 indices(0) = 0
 FOR j as integer = 1 TO number - 1
  temp = keys(j)
  FOR i = j - 1 TO 0 STEP -1
   IF keys(i) <= temp THEN EXIT FOR
   keys(i + 1) = keys(i)
   indices(i + 1) = indices(i)
  NEXT
  keys(i + 1) = temp
  indices(i + 1) = j
 NEXT
END SUB

'CRT Quicksort. Running time is *usually* O(n*log(n)). NOT STABLE
/' Uncomment if you want to use (working fine)
FUNCTION integer_compare CDECL (BYVAL a as integer ptr, BYVAL b as integer ptr) as integer
 IF *a < *b THEN RETURN -1
 IF *a > *b THEN RETURN 1
END FUNCTION

SUB qsort_integers_indices(indices() as integer, BYVAL start as integer ptr, BYVAL number as integer, BYVAL stride as integer)
 IF number = 0 THEN number = UBOUND(indices) + 1
 DIM keys(number - 1, 1) as integer
 DIM as integer i
 FOR i = 0 TO number - 1
  keys(i,0) = *start
  keys(i,1) = i
  start = CAST(integer ptr, CAST(byte ptr, start) + stride)
 NEXT

 qsort(@keys(0,0), number, 2*sizeof(integer), CAST(FUNCTION CDECL(BYVAL as any ptr, BYVAL as any ptr) as integer, @integer_compare))

 FOR i = 0 TO number - 1
  indices(i) = keys(i,1)
 NEXT
END SUB
'/

'These cache functions store a 'resetter' string, which causes search_string_cache
'to automatically empty the cache when its value changes (eg, different game).
'Note that you can resize the cache arrays as you want at any time.
FUNCTION search_string_cache (cache() as IntStrPair, byval key as integer, resetter as string) as string
 IF cache(0).s <> resetter THEN
  cache(0).s = resetter
  cache(0).i = 0  'used to loop through the indices when writing
  
  FOR i as integer = 1 TO UBOUND(cache)
   cache(i).i = -1099999876
   cache(i).s = ""
  NEXT
 END IF

 FOR i as integer = 1 TO UBOUND(cache)
  IF cache(i).i = key THEN RETURN cache(i).s
 NEXT
END FUNCTION

SUB add_string_cache (cache() as IntStrPair, byval key as integer, value as string)
 DIM i as integer
 FOR i = 1 TO UBOUND(cache)
  IF cache(i).i = -1099999876 THEN
   cache(i).i = key
   cache(i).s = value
   EXIT SUB
  END IF
 NEXT
 'overwrite an existing entry, in a loop
 i = 1 + (cache(0).i MOD UBOUND(cache))
 cache(i).i = key
 cache(i).s = value
 cache(0).i = i
END SUB

SUB remove_string_cache (cache() as IntStrPair, byval key as integer)
 FOR i as integer = 1 TO UBOUND(cache)
  IF cache(i).i = key THEN
   cache(i).i = -1099999876
   cache(i).s = ""
   EXIT SUB
  END IF
 NEXT
END SUB

#define ROT(a,b) ((a shl b) or (a shr (32 - b)))

'Fairly fast (in original C) string hash, ported from from fb2c++ (as strihash,
'original was case insensitive) which I wrote and tested myself
FUNCTION strhash(byval strp as zstring ptr, byval leng as integer) as unsigned integer
 DIM as unsigned integer hash = &hbaad1dea

 IF (leng and 3) = 3 THEN
  hash xor= *strp shl 16
  strp += 1
 END IF
 IF (leng and 3) >= 2 THEN
  hash xor= *strp shl 8
  strp += 1
 END IF
 IF (leng and 3) >= 1 THEN
  hash xor= *strp
  strp += 1
  hash = (hash shl 5) - hash
  hash xor= ROT(hash, 19)
 END IF

 leng \= 4
 WHILE leng
  hash += *cast(unsigned integer ptr, strp)
  strp += 4
  hash = (hash shl 5) - hash  ' * 31
  hash xor= ROT(hash, 19)
  leng -= 1
 WEND
 'No need to be too thorough, will get rehashed if needed anyway
 hash += ROT(hash, 2)
 hash xor= ROT(hash, 27)
 hash += ROT(hash, 16)
 RETURN hash
END FUNCTION

FUNCTION strhash(hstr as string) as unsigned integer
 RETURN strhash(hstr, len(hstr))
END FUNCTION
