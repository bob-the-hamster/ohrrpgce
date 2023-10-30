'OHRRPGCE - RELOAD testcases
'(C) Copyright 1997-2020 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.
'
'Compile with "scons reloadtest", run by "scons test"


#include "config.bi"
#include "testing.bi"
#include "reload.bi"
#include "reloadext.bi"
#include "lumpfile.bi"

Using Reload
Using Reload.Ext


dim shared doc as DocPtr, doc2 as DocPtr

#if 0
startTest(testStringTables)
	TestStringTables()
endTest
#endif

#if 0
startTest(bitsetTest)
	doc = CreateDocument()
	if doc = null then fail
	
	dim nod as NodePtr = CreateNode(doc, "root")
	if nod = null then fail
	
	SetRootNode(doc, nod)
	
	CreateBitset(nod)
	
	SerializeBin("test.rld", doc)
	
	FreeDocument(doc)
	
	doc = null
endTest
#endif

CONST VLITestFile as string = "reloadtest_vli.bin"

#macro WRITE_VLIS()
	for idx as integer = -10000 to 10000
		WriteVLI fil, idx
	next

	WriteVLI fil, 1000000
	WriteVLI fil, 100000000
	WriteVLI fil, 10000000000
	WriteVLI fil, 1000000000000
	WriteVLI fil, 100000000000000
	WriteVLI fil, 10000000000000000
	WriteVLI fil, 9223372036854775807  '2^63 - 1

	WriteVLI fil, -1000000
	WriteVLI fil, -100000000
	WriteVLI fil, -10000000000
	WriteVLI fil, -1000000000000
	WriteVLI fil, -100000000000000
	WriteVLI fil, -10000000000000000
	WriteVLI fil, -9223372036854775807
	WriteVLI fil, -9223372036854775808
#endmacro

#macro READ_VLIS()
	for idx as integer = -10000 to 10000
		if ReadVLI(fil) <> idx then fail
	next

	if ReadVLI(fil) <> 1000000 then fail
	if ReadVLI(fil) <> 100000000 then fail
	if ReadVLI(fil) <> 10000000000 then fail
	if ReadVLI(fil) <> 1000000000000 then fail
	if ReadVLI(fil) <> 100000000000000 then fail
	if ReadVLI(fil) <> 10000000000000000 then fail
	if ReadVLI(fil) <> 9223372036854775807 then fail

	if ReadVLI(fil) <> -1000000 then fail
	if ReadVLI(fil) <> -100000000 then fail
	if ReadVLI(fil) <> -10000000000 then fail
	if ReadVLI(fil) <> -1000000000000 then fail
	if ReadVLI(fil) <> -100000000000000 then fail
	if ReadVLI(fil) <> -10000000000000000 then fail
	if ReadVLI(fil) <> -9223372036854775807 then fail
	if ReadVLI(fil) <> -9223372036854775808 then fail
#endmacro

startTest(VLIEncoding)
	dim bytes(9) as ubyte
	dim fil as integer = freefile
	if open(VLITestFile for binary as fil) then fail
	WriteVLI fil, &b0
	WriteVLI fil, &b111111
	WriteVLI fil, &b1000000
	WriteVLI fil, &b10011001010110101
	WriteVLI fil, &b0111111111111111111111111111111111111111111111111111111111111111  '2^63 - 1
	WriteVLI fil, &b1111111111111111111111111111111111111111111111111110011011000111  'negative
	WriteVLI fil, &b1111111111111111111111111111111111111111111111111100000100000010  'negative
	WriteVLI fil, -1
	WriteVLI fil, -64
	WriteVLI fil, -65
	WriteVLI fil, &b1000000000000000000000000000000000000000000000000000000000000000  '-2^63
	get #fil, 1, bytes()
	if bytes(0) <> &b00000000 then fail
	get #fil, 2, bytes()
	if bytes(0) <> &b00111111 then fail
	get #fil, 3, bytes()
	if bytes(0) <> &b10000000 then fail
	if bytes(1) <> &b00000001 then fail
	get #fil, 5, bytes()
	if bytes(0) <> &b10110101 then fail
	if bytes(1) <> &b11001010 then fail
	if bytes(2) <> &b00001001 then fail
	get #fil, 8, bytes()
	if bytes(0) <> &b10111111 then fail
	if bytes(1) <> &b11111111 then fail
	if bytes(2) <> &b11111111 then fail
	if bytes(3) <> &b11111111 then fail
	if bytes(4) <> &b11111111 then fail
	if bytes(5) <> &b11111111 then fail
	if bytes(6) <> &b11111111 then fail
	if bytes(7) <> &b11111111 then fail
	if bytes(8) <> &b11111111 then fail
	if bytes(9) <> &b00000001 then fail  'Only 1 bit used
	get #fil, 18, bytes()
	if bytes(0) <> &b11111000 then fail
	if bytes(1) <> &b01100100 then fail  'Exactly fits in 2 bytes
	get #fil, 20, bytes()
	if bytes(0) <> &b11111101 then fail
	if bytes(1) <> &b11111011 then fail
	if bytes(2) <> &b00000001 then fail  'Just doesn't fit in 2 bytes
	get #fil, 23, bytes()
	if bytes(0) <> &b01000000 then fail
	get #fil, 24, bytes()
	if bytes(0) <> &b01111111 then fail
	get #fil, 25, bytes()
	if bytes(0) <> &b11000000 then fail
	if bytes(1) <> &b00000001 then fail
	get #fil, 27, bytes()
	if bytes(0) <> &b11111111 then fail
	if bytes(1) <> &b11111111 then fail
	if bytes(2) <> &b11111111 then fail
	if bytes(3) <> &b11111111 then fail
	if bytes(4) <> &b11111111 then fail
	if bytes(5) <> &b11111111 then fail
	if bytes(6) <> &b11111111 then fail
	if bytes(7) <> &b11111111 then fail
	if bytes(8) <> &b11111111 then fail
	if bytes(9) <> &b00000001 then fail  'Only 1 bit used
	close fil
endTest

' Test overloads of ReadVLI/WriteVLI using FB files are compatible
startTest(VLIFBFile)
	safekill VLITestFile
	dim fil as integer = freefile
	if open(VLITestFile for binary as fil) then fail

	WRITE_VLIS()

	seek fil, 1

	READ_VLIS()

	if seek(fil) <> lof(fil) + 1 then fail
	close fil
	killfile VLITestFile
endTest

' Test overloads of ReadVLI/WriteVLI using VFile/BufferedFile are compatible
startTest(VLICFile)
	scope
		dim fil as BufferedFile ptr
		fil = Buffered_open(VLITestFile)
		if fil = NULL then fail

		WRITE_VLIS()

		Buffered_close(fil)
	end scope

	scope
		dim fil as VFile ptr
		fil = vfopen(VLITestFile, "rb")
		if fil = NULL then fail

		READ_VLIS()

		if vftell(fil) <> filelen(VLITestFile) then fail
		vfclose(fil)
	end scope
endTest

' Test that the two sets of ReadVLI/WriteVLI overloads are compatible
startTest(VLIOverloadsCompatible)
	dim fil as integer = freefile
	if open(VLITestFile for binary as fil) then fail

	READ_VLIS()

	if seek(fil) <> lof(fil) + 1 then fail
	close fil
	killfile VLITestFile
endTest

startTest(createDocument)
	doc = CreateDocument()
	if doc = null then fail
endTest

startTest(addRootNode)
	dim nod as NodePtr = CreateNode(doc, "root")
	
	if nod = 0 then fail
	
	SetRootNode(doc, nod)
	
	if DocumentRoot(doc) <> nod then fail
endTest

startTest(addSmallInteger)
	dim nod2 as NodePtr = CreateNode(doc, "smallInt")
	
	if nod2 = 0 then fail
	
	dim i as integer = int(Rnd * 20)
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltInt then fail
	if GetInteger(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 1 then fail
	
endTest

startTest(addLargeInteger)
	dim nod2 as NodePtr = CreateNode(doc, "largeInt")
	
	if nod2 = 0 then fail
	
	dim i as longint = int(Rnd * 200000000000) + 5000000000 'we want something > 32 bits ;)
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltInt then fail
	if GetInteger(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 2 then fail
	
endTest

startTest(addSmallNegativeInteger)
	dim nod2 as NodePtr = CreateNode(doc, "smallNegativeInt")
	
	if nod2 = 0 then fail
	
	dim i as integer = int(Rnd * 20) - 40
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltInt then fail
	if GetInteger(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 3 then fail
	
endTest

startTest(addLargeNegativeInteger)
	dim nod2 as NodePtr = CreateNode(doc, "largeNegativeInt")
	
	if nod2 = 0 then fail
	
	dim i as longint = int(Rnd * 200000000000) - 500000000000 'we want something > 32 bits ;)
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltInt then fail
	if GetInteger(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 4 then fail
	
endTest

startTest(addFloat)
	dim nod2 as NodePtr = CreateNode(doc, "floatingPoint")
	
	if nod2 = 0 then fail
	
	dim i as Double = Rnd * 20000000
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltFloat then fail
	if GetFloat(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 5 then fail
	
endTest

startTest(addString)
	dim nod2 as NodePtr = CreateNode(doc, "string")
	
	if nod2 = 0 then fail
	
	dim i as String = "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
	SetContent(nod2, i)
	
	if NodeType(nod2) <> rltString then fail
	if GetString(nod2) <> i then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 6 then fail
	
endTest

startTest(addBitset)
	dim nod2 as NodePtr = CreateNode(doc, "bitset")
	
	if nod2 = 0 then fail
	
	SetContent(nod2, " ") 'this is the brute force method...
	
	if GetBitset(nod2, 5) = 0 then fail

	CreateBitset(nod2)
	
	if GetBitset(nod2, 5) <> 0 then fail
	
	SetBitset(nod2, 10, 1)
	
	if GetBitset(nod2, 10) = 0 then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 7 then fail
	
endTest

startTest(addEmpty)
	dim nod2 as NodePtr = CreateNode(doc, "empty")
	
	if nod2 = 0 then fail
	
	if NodeType(nod2) <> rltNull then fail
	
	AddChild(DocumentRoot(doc), nod2)
	
	if NumChildren(DocumentRoot(doc)) <> 8 then fail
endTest

startTest(addNested)
	dim nod as NodePtr = CreateNode(doc, "nestedTop")
	
	if nod = 0 then fail
	
	AddChild(DocumentRoot(doc), nod)
	
	dim nod2 as NodePtr
	
	for i as integer = 0 to int(Rnd * 7) + 3
		nod2 = CreateNode(doc, "level" & i)
		SetContent(nod2, 42 + i)
		if nod2 = 0 then fail
		AddChild(nod, nod2)
		nod = nod2
	next
	
	if NumChildren(DocumentRoot(doc)) <> 9 then fail
endTest

startTest(helperFunctions)
	dim nod as nodeptr = SetChildNode(DocumentRoot(doc), "helper")
	SetContent(nod, 1)

	AppendChildNode(nod, "@attr1", "fish")
	SetChildNode(nod, "int", 12345)
	SetChildNode(nod, "float", 1234.5678)
	SetChildNode(nod, "string", "1 2 3 4 5 6 7 8 9 0")
	SetChildNode(nod, "null")
	
	if GetChildNodeInt(nod, "int") <> 12345 then fail
	if GetChildNodeFloat(nod, "float") <> 1234.5678 then fail
	if GetChildNodeStr(nod, "string") <> "1 2 3 4 5 6 7 8 9 0" then fail
	if not GetChildNodeExists(nod, "null") then fail
	if not GetChildNodeBool(nod, "int") then fail
	
	AppendChildNode(nod, "appended", 54321)
	AppendChildNode(nod, "appended", 43.21)
	AppendChildNode(nod, "appended", "A B C D E F G H I J")
	AppendChildNode(nod, "appended")
	AppendChildNode(nod, "")
	AppendChildNode(nod, "whitespace", !"   white \n space ")
	AppendChildNode(nod, "worse_whitespace", !"   \n\n  ")
	AppendChildNode(nod, "empty_str", "")
	AppendChildNode(nod, "", "")
	AppendChildNode(nod, "", 1)
	AppendChildNode(nod, "like_an_int", "1")
	AppendChildNode(nod, "binary", "123" + CHR(0) + CHR(0) + "#123")
	AppendChildNode(nod, "eatXML", "<dummy>&")
endTest

startTest(bitsetArray)
	dim nod2 as nodeptr = CreateNode(doc, "bitsettest")
	
	dim bs(100) as integer, bs2(100) as integer
	
	for i as integer = 0 to 99
		bs(i) = int(rnd * 65535) 'add some random bits
	next
	
	SaveBitsetArray(nod2, bs(), 100)
	
	LoadBitsetArray(nod2, bs2(), 100)
	
	for i as integer = 0 to 99
		if bs(i) <> bs2(i) then fail
	next
	
endTest

startTest(testNodeByPath)
	dim as NodePtr nod1, nod2, created1, created2
	nod1 = SetChildNode(DocumentRoot(doc), "party")
	AppendChildNode(nod1, "slot", 0)
	AppendChildNode(nod1, "slot", 0)
	AppendChildNode(nod1, "slot", 0)
	nod1 = AppendChildNode(nod1, "slot", 3)
	nod1 = SetChildNode(nod1, "stats")
	nod2 = AppendChildNode(nod1, "stat", 0)
	AppendChildNode(nod1, "stat", 1)
	SetChildNode(nod2, "max", 100)
	SetChildNode(nod2, "cur", 95)
	
	nod1 = NodeByPath(doc, "/party/slot[3]/stats/stat[0]/max")
	if nod1 = null then fail
	if NodeName(nod1) <> "max" then fail
	if GetInteger(nod1) <> 100 then fail
	
	'test NodeByPath's create feature
	nod1 = NodeByPath(doc, "/foo/bar/baz", YES)
	if nod1 = null then fail
	nod1 = NodeByPath(doc, "/foo")
	if nod1 = null then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz/should_not_be_created")
	if nod1 <> null then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz/should_be_created", YES)
	if nod1 = null then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz")
	if nod1 = null then fail
	if GetChildNodeExists(nod1, "should_be_created") = NO then fail
	'Also test creation with subscript syntax
	nod1 = NodeByPath(doc, "/foo/bar/baz/also_should_not_be_created[2]")
	if nod1 <> null then fail
	created1 = NodeByPath(doc, "/foo/bar/baz/also_should_be_created[2]", YES)
	if created1 = null then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz")
	if GetChildNodeExists(nod1, "also_should_be_created") = NO then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz/also_should_be_created[2]")
	if nod1 <> created1 then fail
	if GetInteger(nod1) <> 2 then fail
	nod1 = NodeByPath(doc, "/foo/bar/baz/also_should_be_created[0]")
	if nod1 <> null then fail
	'Test for bug regression: This must create a new node, not overwrite nod1
	created2 = NodeByPath(doc, "/foo/bar/baz/also_should_be_created[0]", YES)
	if created2 = null then fail
	if GetInteger(created2) <> 0 then fail
	if created2 = created1 then fail
	if GetInteger(created1) <> 2 then fail
endTest

startTest(testProvisional)
	dim nod1 as NodePtr
	dim root as NodePtr = DocumentRoot(doc)
	dim numtoplevel as integer = NumChildren(root)
	MarkProvisional(FirstChild(root, "party"))
	nod1 = NodeByPath(doc, "/party/slot[3]/stats")
	MarkProvisional(nod1)
	nod1 = AppendChildNode(root, "prov1")
	MarkProvisional(nod1)
	RemoveProvisionalNodes(root)
	if NumChildren(root) <> numtoplevel then fail
	nod1 = AppendChildNode(root, "was_prov1", 3.141)
	MarkProvisional(nod1)
	nod1 = AppendChildNode(root, "was_prov2")
	AppendChildNode(nod1, "")
	MarkProvisional(nod1)
	nod1 = AppendChildNode(root, "prov2")
	MarkProvisional(nod1)
	RemoveProvisionalNodes(root)
	if NumChildren(root) <> numtoplevel + 1 then fail
endTest

startTest(testSetKeyValueNode)
	dim as NodePtr nod1
	dim root as NodePtr = DocumentRoot(doc)
	SetKeyValueNode(root, "a_dict", 0, 23)
	nod1 = SetKeyValueNode(root, "a_dict", 1, 24)
	SetChildNode(nod1, "something extra", "foo bar")
	SetKeyValueNode(root, "a_dict", 2, 22)
	nod1 = SetKeyValueNode(root, "a_dict", 1, -999)
	if NumChildren(nod1) then fail

	dim n as NodePtr
	dim count as integer = 0
	n = FirstChild(root, "a_dict")
	while n
		count += 1
		n = NextSibling(n, "a_dict")
	wend
	if count <> 3 then fail

	SetKeyValueNode(root, "dict2", 2, 22222, "id")
endTest

startTest(testGetKeyValueNode)
	dim as NodePtr nod1, nod2
	dim root as NodePtr = DocumentRoot(doc)
	nod1 = GetKeyValueNode(root, "a_dict", 1)
	if nod1 = NULL then fail
	if NodeName(nod1) <> "int" then fail
	if GetInteger(nod1) <> -999 then fail

	if ReadKeyValueNode(root, "a_dict", 0, 0) <> 23 then fail
	if ReadKeyValueNode(root, "a_dict", 1, 0) <> -999 then fail
	if ReadKeyValueNode(root, "a_dict", 2, 0) <> 22 then fail
	if ReadKeyValueNode(root, "a_dict", 3, -713) <> -713 then fail  'test defaulting
	if ReadKeyValueNode(root, "dict2", 2, 0, "id") <> 22222 then fail
endTest

startTest(testNodesIteration)
	dim iterdoc as Docptr
	iterdoc = CreateDocument()
	if iterdoc = null then fail
	
	dim node as NodePtr = CreateNode(iterdoc, "root")
	if node = null then fail
	SetRootNode(iterdoc, node)
	
	AppendChildNode(node, "vlad")
	AppendChildNode(node, "bob")
	AppendChildNode(node, "bob")
	AppendChildNode(node, "bob")
	AppendChildNode(node, "waldo")
	AppendChildNode(node, "bob")
	
	dim find as NodePtr
	
	find = FirstChild(node)
	if find = 0 then fail
	if NodeName(find) <> "vlad" then fail
	
	find = FirstChild(node, "waldo")
	if find = 0 then fail
	if NodeName(find) <> "waldo" then fail
	
	find = FirstChild(node, "bob")
	if find = 0 then fail
	while find
		if NodeName(find) <> "bob" then fail
		find = NextSibling(find, "bob")
	wend
	
	find = FirstChild(node, "waldo")
	if find = 0 then fail
	find = PrevSibling(find, "bob")
	if find = 0 then fail
	while find
		if NodeName(find) <> "bob" then fail
		find = PrevSibling(find, "bob")
	wend
	
	FreeDocument(iterdoc)
endTest

startTest(testSwapNodes)
	dim swapdoc as Docptr
	swapdoc = CreateDocument()
	if swapdoc = null then fail
	dim node as NodePtr = CreateNode(swapdoc, "root")
	if node = null then fail
	SetRootNode(swapdoc, node)
	
	AppendChildNode(node, "foo")
	AppendChildNode(node, "bar")
	node = NodeByPath(swapdoc, "/bar")
	AppendChildNode(node, "baz", 100)
	node = NodeByPath(swapdoc, "/foo")
	AppendChildNode(node, "cute")
	node = NodeByPath(swapdoc, "/foo/cute")
	AppendChildNode(node, "A", "kittens")
	AppendChildNode(node, "B", "puppies")
	
	dim nod1 as NodePtr
	dim nod2 as NodePtr
	nod1 = NodeByPath(swapdoc, "/foo")
	nod2 = NodeByPath(swapdoc, "/bar")
	
	SwapSiblingNodes(nod1, nod2)
	if FirstChild(DocumentRoot(swapdoc)) <> NodeByPath(swapdoc, "/bar")  then fail
	SwapSiblingNodes(nod1, nod2)
	if FirstChild(FirstChild(DocumentRoot(swapdoc))) <> NodeByPath(swapdoc, "/foo/cute")  then fail
	FreeDocument(swapdoc)
endTest

startTest(serializeXML)
	dim fh as integer = freefile
	open "unittest.xml" for output as fh
	serializeXML(doc, fh)
	close fh
	passed
endTest

dim shared skip_xml2reload as bool
if isfile("xml2reload" & DOTEXE) = NO then
	print
	print "NOTE: xml2reload not found; skipping some tests (you have to compile it manually)"
	print
	skip_xml2reload = YES
end if

sub toXMLAndBack(byval debugging as integer)
	dim fh as integer
	fh = freefile
	open "unittest.xml" for output as fh
	serializeXML(doc, fh, debugging)
	close fh

	safekill "unittest.rld"
	print
	print
	'Windows cmd doesn't like ./
	shell "." + SLASH + "xml2reload unittest.xml unittest.rld"
	print
end sub

startTest(loadFromXML)
	if skip_xml2reload then skip_test
	toXMLAndBack(NO)

	doc2 = LoadDocument("unittest.rld", optNoDelay)
	if doc2 = null then fail
	
	' dim fh as integer = freefile
	' open cons for output as fh
	' serializeXML(doc2, fh)
	' close fh
endTest

startTest(compareWithXML)
	if skip_xml2reload then skip_test
	'non-pedantic
	if CompareNodes(DocumentRoot(doc), DocumentRoot(doc2), NO, YES) = NO then fail
endTest

/'
'This normally fails because floating point nodes are loaded as strings.
'It's not important at all; type-accurate import/export would probably only be useful for chasing
'bugs in RELOAD internals
startTest(pedanticCompareWithXML)
	if skip_xml2reload then skip_test
	toXMLAndBack(YES)

	doc2 = LoadDocument("unittest.rld", optNoDelay)
	if doc2 = null then fail

	'pedantic
	if CompareNodes(DocumentRoot(doc), DocumentRoot(doc2), YES, YES) = NO then fail
endTest
'/


startTest(nodeAppendingSpeedTest1)
	dim root as NodePtr = DocumentRoot(doc)
	dim hub as NodePtr = AppendChildNode(root, "bigtree")
	dim nod as NodePtr
	for i as integer = 0 to 9999
		AppendChildNode(hub, "null")
		AppendChildNode(hub, "int", 42)
		if i mod 1000 = 0 then
			nod = AppendChildNode(hub, "marker" & i)
		end if
	next
	if NumChildren(hub) <> 20010 then fail
endTest

startTest(nodeFindingSpeedTest1)
	dim root as NodePtr = DocumentRoot(doc)
	dim hub as NodePtr = GetChildByName(root, "bigtree")
	if hub = null then fail
	dim nod as NodePtr
	for i as integer = 0 to 9999 step 1000
		nod = GetChildByName(hub, "marker" & i)
		if nod = null then fail
	next
endTest

startTest(setKeyValueSpeedTest1)
	dim root as NodePtr = DocumentRoot(doc)
	dim hub as NodePtr = AppendChildNode(root, "bigtree2")
	dim nod as NodePtr
	dim itemname as string = "item"
	for i as integer = 0 to 500
		SetKeyValueNode(hub, itemname, i, i * 2)
	next
	passed
endTest

startTest(nodeFindingSpeedTest2)
	dim root as NodePtr = DocumentRoot(doc)
	dim hub as NodePtr = GetChildByName(root, "bigtree2")
	dim nod as NodePtr
	dim itemname as string = "item"
	for i as integer = 500 to 0 step -1
		if ReadKeyValueNode(hub, itemname, i, -1) <> i * 2 then fail
	next
endTest

startTest(nodeAppendingSpeedTest2)
	dim hub as NodePtr = NodeByPath(doc, "/bigtree")
	dim nod as NodePtr
	for i as integer = 0 to 1999
		nod = AppendChildNode(hub, "something")
		AppendChildNode(nod, "datum1", i)
		AppendChildNode(nod, "datum2", i)
		AppendChildNode(nod, "datum3")
		AppendChildNode(nod, "datum4", i)
		AppendChildNode(nod, "datum5", i)
		AppendChildNode(nod, "datum6", "foo")
		AppendChildNode(nod, "datum7")
		AppendChildNode(nod, "datum8")
		AppendChildNode(nod, "datum9")
		AppendChildNode(nod, "datum10")
	next
	passed
endTest

startTest(nodeFindingSpeedTest3)
	dim nod as NodePtr = NodeByPath(doc, "/bigtree/something")
	if nod = NULL then fail
	for i as integer = 0 to 1999
		if nod = NULL then fail
		if GetChildNodeInt(nod, "datum1") <> i then fail
		GetChildNodeInt(nod, "datum2")
		GetChildByName(nod, "datum5")
		GetChildByName(nod, "datum6")
		GetChildByName(nod, "datum9")
		GetChildByName(nod, "datum10")
		nod = NextSibling(nod)
	next
endTest


startTest(writeFile)
	SerializeBin("unittest.rld", doc)
	
	if not isfile("unittest.rld") then fail
endTest

startTest(loadDocumentNoDelay)
	doc2 = LoadDocument("unittest.rld", optNoDelay)
	
	if doc2 = null then fail
endTest

startTest(compareDocumentsNoDelay)
	if CompareNodes(DocumentRoot(doc), DocumentRoot(doc2), YES, YES) = NO then fail
endTest

startTest(freeDocumentNoDelay)
	FreeDocument(doc2)
	doc2 = 0
	passed
endTest

startTest(loadAndCompareDocumentsDelay)
	doc2 = LoadDocument("unittest.rld")
	
	if doc2 = null then fail
	
	if CompareNodes(DocumentRoot(doc), DocumentRoot(doc2), YES, YES) = NO then fail
endTest

startTest(freeDocumentDelay)
	FreeDocument(doc2)
	doc2 = 0
	passed
endTest


startTest(cleanup)
	FreeDocument(doc)
	doc = 0
	FreeDocument(doc2)
	doc2 = 0
	passed
endTest

print "All passed."
