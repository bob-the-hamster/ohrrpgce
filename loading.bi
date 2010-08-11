'OHRRPGCE - loading.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from loading.bas

#IFNDEF LOADING_BI
#DEFINE LOADING_BI

DECLARE SUB LoadNPCD(file as string, dat() as NPCType)
DECLARE SUB LoadNPCD_fixedlen(file as string, dat() as NPCType, BYREF arraylen as integer)
DECLARE SUB SaveNPCD(file as string, dat() as NPCType)
DECLARE SUB SaveNPCD_fixedlen(file as string, dat() as NPCType, BYVAL arraylen as integer)
declare sub setnpcd(npcd as npctype, offset as integer, value as integer)
declare function getnpcd(npcd as npctype, offset as integer) as integer
declare sub CleanNPCDefinition(dat as NPCType)
declare sub CleanNPCD(dat() as NPCType)
declare sub loadnpcl(file as string, dat() as npcinst)
declare sub savenpcl(file as string, dat() as npcinst)
declare sub sernpcl(npc() as npcinst, z as integer, buffer() as integer, num as integer, xoffset as integer, yoffset as integer)
declare sub desernpcl(npc() as npcinst, z as integer, buffer() as integer, num as integer, xoffset as integer, yoffset as integer)
declare sub cleannpcl(dat() as npcinst, byval num as integer=-1)

declare Sub SaveInventory16bit(invent() AS InventSlot, BYREF z AS INTEGER, buf() AS INTEGER, BYVAL first AS INTEGER=0, BYVAL last AS INTEGER=-1)
declare Sub LoadInventory16Bit(invent() AS InventSlot, BYREF z AS INTEGER, buf() AS INTEGER, BYVAL first AS INTEGER=0, BYVAL last AS INTEGER=-1)
declare sub serinventory8bit(invent() as inventslot, z as integer, buf() as integer)
declare sub deserinventory8bit(invent() as inventslot, z as integer, buf() as integer)
declare sub cleaninventory(invent() as inventslot)

declare sub UnloadTilemap(map as TileMap)
declare sub UnloadTilemaps(layers() as TileMap)
declare sub LoadTilemap(map as TileMap, filename as string)
declare sub LoadTilemaps(layers() as TileMap, filename as string)
declare sub SaveTilemap(tmap as TileMap, filename as string)
declare sub SaveTilemaps(tmaps() as TileMap, filename as string)
declare sub CleanTilemap(map as TileMap, BYVAL wide as integer, BYVAL high as integer, BYVAL layernum as integer = 0)
declare SUB CleanTilemaps(layers() as TileMap, BYVAL wide as integer, BYVAL high as integer, BYVAL numlayers as integer)

declare SUB DeserDoorLinks(filename as string, array() as doorlink)
declare Sub SerDoorLinks(filename as string, array() as doorlink, withhead as integer = 1)
declare sub CleanDoorLinks(array() as doorlink)
declare Sub DeSerDoors(filename as string, array() as door, record as integer)
declare Sub SerDoors(filename as string, array() as door, record as integer)
declare Sub CleanDoors(array() as door)
declare Sub LoadStats(fh as integer, sta as stats ptr)
declare Sub SaveStats(fh as integer, sta as stats ptr)
declare Sub LoadStats2(fh as integer, lev0 as stats ptr, lev99 as stats ptr)
declare Sub SaveStats2(fh as integer, lev0 as stats ptr, lev99 as stats ptr)

declare Sub DeSerHeroDef(filename as string, hero as herodef ptr, record as integer)
declare Sub SerHeroDef(filename as string, hero as herodef ptr, record as integer)
DECLARE SUB loadherodata (hero as herodef ptr, index as integer)
DECLARE SUB saveherodata (hero as herodef ptr, index as integer)

declare Sub ClearMenuData(dat AS MenuDef)
declare Sub ClearMenuItem(mi AS MenuDefItem)
declare Sub DeleteMenuItems(menu AS MenuDef)
declare Sub LoadMenuData(menu_set AS MenuSet, dat AS MenuDef, record AS INTEGER, ignore_items AS INTEGER=NO)
declare Sub SaveMenuData(menu_set AS MenuSet, dat AS MenuDef, record AS INTEGER)
declare Sub SortMenuItems(menu AS MenuDef)
declare Sub MenuBitsToArray (menu AS MenuDef, bits() AS INTEGER)
declare Sub MenuBitsFromArray (menu AS MenuDef, bits() AS INTEGER)
declare Sub MenuItemBitsToArray (mi AS MenuDefItem, bits() AS INTEGER)
declare Sub MenuItemBitsFromArray (mi AS MenuDefItem, bits() AS INTEGER)

declare Sub LoadVehicle OVERLOAD (file AS STRING, vehicle AS VehicleData, record AS INTEGER)
declare Sub LoadVehicle OVERLOAD (file AS STRING, veh() as integer, vehname as string, record AS INTEGER)
declare Sub SaveVehicle OVERLOAD (file AS STRING, veh() as integer, vehname as string, record AS INTEGER)
declare Sub SaveVehicle OVERLOAD (file AS STRING, vehicle AS VehicleData, record AS INTEGER)
declare Sub ClearVehicle (vehicle AS VehicleData)

declare Sub SaveUIColors (colarray() AS INTEGER, palnum AS INTEGER)
declare Sub LoadUIColors (colarray() AS INTEGER, palnum AS INTEGER=-1)
declare Sub DefaultUIColors (colarray() AS INTEGER)
declare Sub OldDefaultUIColors (colarray() AS INTEGER)
declare Sub GuessDefaultUIColors (colarray() AS INTEGER)

declare Sub LoadTextBox (BYREF box AS TextBox, record AS INTEGER)
declare Sub SaveTextBox (BYREF box AS TextBox, record AS INTEGER)
declare Sub ClearTextBox (BYREF box AS TextBox)

DECLARE SUB loadoldattackdata (array() as integer, index as integer)
DECLARE SUB saveoldattackdata (array() as integer, index as integer)
DECLARE SUB loadnewattackdata (array() as integer, index as integer)
DECLARE SUB savenewattackdata (array() as integer, index as integer)
DECLARE SUB loadattackdata OVERLOAD (array() as integer, BYVAL index as integer)
DECLARE SUB loadattackdata OVERLOAD (BYREF atkdat as AttackData, BYVAL index as integer)
DECLARE SUB convertattackdata(buf() AS INTEGER, BYREF atkdat AS AttackData)
DECLARE SUB saveattackdata (array() as integer, index as integer)

DECLARE SUB loadtanim (n as integer, tastuf() as integer)
DECLARE SUB savetanim (n as integer, tastuf() as integer)

DECLARE SUB getpal16 (array() as integer, aoffset as integer, foffset as integer, autotype as integer=-1, sprite as integer=0)
DECLARE SUB storepal16 (array() as integer, aoffset as integer, foffset as integer)

DECLARE SUB loaditemdata (array() as integer, index as integer)
DECLARE SUB saveitemdata (array() as integer, index as integer)

DECLARE SUB loadenemydata OVERLOAD (array() as integer, index as integer, altfile as integer = 0)
DECLARE SUB loadenemydata OVERLOAD (enemy AS EnemyDef, index AS INTEGER, altfile AS INTEGER = 0)

DECLARE SUB saveenemydata OVERLOAD (array() as integer, index as integer, altfile as integer = 0)
DECLARE SUB saveenemydata OVERLOAD (enemy AS EnemyDef, index as integer, altfile as integer = 0)

DECLARE SUB save_string_list(array() AS STRING, filename AS STRING)
DECLARE SUB load_string_list(array() AS STRING, filename AS STRING)

DECLARE FUNCTION load_map_pos_save_offset(BYVAL mapnum AS INTEGER) AS XYPair

#ENDIF
