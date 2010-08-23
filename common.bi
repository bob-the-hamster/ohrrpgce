
'OHRRPGCE - Some Custom/Game common code
'
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#ifndef COMMON_BI
#define COMMON_BI

#include "util.bi"
#include "udts.bi"
#include "music.bi"
#include "browse.bi"
#include "const.bi"

DECLARE SUB fadein ()
DECLARE SUB fadeout (red as integer, green as integer, blue as integer)
DECLARE FUNCTION usemenu OVERLOAD (pt as integer, top as integer, first as integer, last as integer, size as integer) as integer
DECLARE FUNCTION usemenu OVERLOAD (state AS MenuState) as integer
DECLARE FUNCTION usemenu OVERLOAD (state AS MenuState, enabled() AS INTEGER) as integer
DECLARE FUNCTION usemenu OVERLOAD (state AS MenuState, menudata() AS SimpleMenu) as integer
DECLARE SUB standardmenu OVERLOAD (menu() as string, state AS MenuState, x as integer, y as integer, page as integer, edge as integer=NO, hidecursor as integer=NO, wide AS INTEGER=999, highlight AS INTEGER=NO)
DECLARE SUB standardmenu OVERLOAD (menu() as string, size as integer, vis as integer, pt as integer, top as integer, x as integer, y as integer, page as integer, edge as integer=NO, wide AS INTEGER=999, highlight AS INTEGER=NO)
DECLARE SUB clamp_menu_state (BYREF state AS MenuState)
DECLARE SUB start_new_debug ()
DECLARE SUB end_debug ()
DECLARE SUB debug (s as string)
DECLARE SUB debuginfo (s as string)
DECLARE SUB visible_debug (s as string)
DECLARE FUNCTION soundfile (sfxnum as integer) as string
DECLARE FUNCTION filesize (file as string) as string
DECLARE FUNCTION getfixbit(bitnum AS INTEGER) AS INTEGER
DECLARE SUB setfixbit(bitnum AS INTEGER, bitval AS INTEGER)
DECLARE FUNCTION aquiretempdir () as string
DECLARE SUB writebinstring OVERLOAD (savestr as string, array() as integer, offset as integer, maxlen as integer)
DECLARE SUB writebinstring OVERLOAD (savestr as string, array() as short, offset as integer, maxlen as integer)
DECLARE SUB writebadbinstring (savestr as string, array() as integer, offset as integer, maxlen as integer, skipword as integer=0)
DECLARE FUNCTION readbinstring OVERLOAD (array() as integer, offset as integer, maxlen as integer) as string
DECLARE FUNCTION readbinstring OVERLOAD (array() as short, offset as integer, maxlen as integer) as string
DECLARE FUNCTION readbadbinstring (array() as integer, offset as integer, maxlen as integer, skipword as integer=0) as string
DECLARE FUNCTION read32bitstring overload (array() as integer, offset as integer) as string
DECLARE FUNCTION read32bitstring overload (strptr as integer ptr) as string
DECLARE FUNCTION readbadgenericname (index as integer, filename as string, recsize as integer, offset as integer, size as integer, skip as integer) as string
DECLARE SUB copylump(package as string, lump as string, dest as string, ignoremissing AS INTEGER = 0)

ENUM RectTransTypes
 transUndef = -1
 transOpaque = 0
 transFuzzy
 transHollow
END ENUM

DECLARE SUB centerfuz (x as integer, y as integer, w as integer, h as integer, c as integer, p as integer)
DECLARE SUB centerbox (x as integer, y as integer, w as integer, h as integer, c as integer, p as integer)
DECLARE SUB edgeboxstyle (x as integer, y as integer, w as integer, h as integer, boxstyle as integer, p as integer, fuzzy as integer=NO, supress_borders as integer=NO)
DECLARE SUB center_edgeboxstyle (x as integer, y as integer, w as integer, h as integer, boxstyle as integer, p as integer, fuzzy as integer=NO, supress_borders as integer=NO)
DECLARE SUB edgebox OVERLOAD (x as integer, y as integer, w as integer, h as integer, col as integer, bordercol as integer, p as integer, trans as RectTransTypes=transOpaque, border as integer=-1)
DECLARE SUB edgebox OVERLOAD (x, y, w, h, col, bordercol, BYVAL fr AS Frame Ptr, trans AS RectTransTypes=transOpaque, border=-1)
DECLARE SUB emptybox (x as integer, y as integer, w as integer, h as integer, col as integer, thick as integer, p as integer)
DECLARE FUNCTION isbit (bb() as INTEGER, BYVAL w as INTEGER, BYVAL b as INTEGER) as INTEGER
DECLARE FUNCTION scriptname (num as integer, trigger as integer = 0) as string
DECLARE Function seconds2str(byval sec as integer, f as string = " %m: %S") as string

DECLARE SUB loaddefaultpals (fileset AS INTEGER, poffset() AS INTEGER, sets AS INTEGER)
DECLARE SUB savedefaultpals (fileset AS INTEGER, poffset() AS INTEGER, sets AS INTEGER)
DECLARE SUB guessdefaultpals (fileset AS INTEGER, poffset() AS INTEGER, sets AS INTEGER)
DECLARE FUNCTION getdefaultpal(fileset as integer, index as integer) as integer

DECLARE SUB setbinsize (id as integer, size as integer)
DECLARE FUNCTION curbinsize (id as integer) as integer
DECLARE FUNCTION defbinsize (id as integer) as integer
DECLARE FUNCTION getbinsize (id as integer) as integer
DECLARE FUNCTION dimbinsize (id as integer) as integer
DECLARE FUNCTION maplumpname (map as integer, oldext as string) as string
DECLARE SUB fatalerror (e as string)
DECLARE FUNCTION xstring (s as string, x as integer) as integer
DECLARE FUNCTION defaultint (n AS INTEGER, default_caption AS STRING="default") AS STRING
DECLARE FUNCTION caption_or_int (n AS INTEGER, captions() AS STRING) AS STRING
DECLARE SUB poke8bit (array16() as integer, index as integer, val8 as integer)
DECLARE FUNCTION peek8bit (array16() as integer, index as integer) as integer

DECLARE SUB loadpalette(pal() as RGBcolor, palnum as integer)
DECLARE SUB savepalette(pal() as RGBcolor, palnum as integer)
DECLARE SUB convertpalette(oldpal() as integer, newpal() as RGBcolor)

DECLARE FUNCTION createminimap OVERLOAD (map() AS TileMap, tilesets() AS TilesetData ptr, BYREF zoom AS INTEGER = -1) AS Frame PTR
DECLARE FUNCTION createminimap OVERLOAD (layer AS TileMap, tileset AS TilesetData ptr, BYREF zoom AS INTEGER = -1) AS Frame PTR
DECLARE SUB animatetilesets (tilesets() AS TilesetData ptr)
DECLARE SUB cycletile (tanim_state() AS TileAnimState, tastuf() AS INTEGER)
DECLARE SUB loadtilesetdata (tilesets() AS TilesetData ptr, BYVAL layer AS INTEGER, BYVAL tilesetnum AS INTEGER, BYVAL lockstep AS INTEGER = YES)
DECLARE SUB unloadtilesetdata (BYREF tileset AS TilesetData ptr)
DECLARE FUNCTION layer_tileset_index(BYVAL layer AS INTEGER) AS INTEGER
DECLARE SUB loadmaptilesets (tilesets() AS TilesetData ptr, gmap() AS INTEGER, BYVAL resetanimations as integer = YES)
DECLARE SUB unloadmaptilesets (tilesets() AS TilesetData ptr)
DECLARE SUB writescatter (s as string, lhold as integer, start as integer)
DECLARE SUB readscatter (s as string, lhold as integer, start as integer)
DECLARE FUNCTION finddatafile(filename as string) as string
DECLARE SUB updaterecordlength (lumpf as string, byval bindex as integer, byval headersize as integer = 0, byval repeating as integer = NO)
DECLARE SUB writepassword (p as string)
DECLARE FUNCTION readpassword () as string
DECLARE SUB upgrade (font() as integer)
DECLARE SUB rpgversion (v as integer)
DECLARE SUB fix_sprite_record_count(BYVAL pt_num AS INTEGER)
DECLARE SUB fix_record_count(BYREF last_rec_index AS INTEGER, BYREF record_byte_size AS INTEGER, lumpname AS STRING, info AS STRING, skip_header_bytes AS INTEGER=0, count_offset AS INTEGER=0)
DECLARE SUB loadglobalstrings ()
DECLARE FUNCTION readglobalstring (index as integer, default as string, maxlen as integer=10) as string
DECLARE SUB load_default_master_palette (master_palette() AS RGBColor)
DECLARE SUB dump_master_palette_as_hex (master_palette() AS RGBColor)

DECLARE FUNCTION readattackname (index as integer) as string
DECLARE FUNCTION readenemyname (index as integer) as string
DECLARE FUNCTION readitemname (index as integer) as string
DECLARE FUNCTION readshopname (shopnum as integer) as string
DECLARE FUNCTION getsongname (num AS INTEGER, prefixnum AS INTEGER = 0) as string
DECLARE FUNCTION getsfxname (num AS INTEGER) as string
DECLARE FUNCTION getheroname (hero_id AS INTEGER) AS STRING
DECLARE FUNCTION getmenuname(record AS INTEGER) AS STRING
DECLARE FUNCTION getmapname (m as integer) as string
DECLARE SUB getstatnames(statnames() AS STRING)

DECLARE FUNCTION getdisplayname (default as string) as string

DECLARE SUB playsongnum (songnum as integer)

DECLARE FUNCTION find_helper_app (appname AS STRING) AS STRING
DECLARE FUNCTION find_madplay () AS STRING
DECLARE FUNCTION find_oggenc () AS STRING
DECLARE FUNCTION can_convert_mp3 () AS INTEGER
DECLARE FUNCTION can_convert_wav () AS INTEGER
DECLARE SUB mp3_to_ogg (in_file AS STRING, out_file AS STRING, quality AS INTEGER = 5)
DECLARE SUB mp3_to_wav (in_file AS STRING, out_file AS STRING)
DECLARE SUB wav_to_ogg (in_file AS STRING, out_file AS STRING, quality AS INTEGER = 5)

DECLARE FUNCTION intgrabber (n AS INTEGER, min AS INTEGER, max AS INTEGER, less AS INTEGER=75, more AS INTEGER=77) AS INTEGER
DECLARE FUNCTION zintgrabber (n AS INTEGER, min AS INTEGER, max AS INTEGER, less AS INTEGER=75, more AS INTEGER=77) AS INTEGER
DECLARE FUNCTION xintgrabber (n AS INTEGER, pmin AS INTEGER, pmax AS INTEGER, nmin AS INTEGER, nmax AS INTEGER, less AS INTEGER=75, more AS INTEGER=77) AS INTEGER
DECLARE SUB reset_console (top AS INTEGER = 0, h AS INTEGER = 200, c AS INTEGER = 0)
DECLARE SUB show_message (s AS STRING)
DECLARE SUB append_message (s AS STRING)

DECLARE SUB position_menu (menu AS MenuDef, page AS INTEGER)
DECLARE SUB draw_menu (menu AS MenuDef, state AS MenuState, page AS INTEGER)
DECLARE SUB init_menu_state (BYREF state AS MenuState, menu AS MenuDef)
DECLARE FUNCTION count_menu_items (menu AS MenuDef) as integer
DECLARE FUNCTION find_empty_menu_item (menu AS MenuDef) as integer
DECLARE FUNCTION get_menu_item_caption (mi AS MenuDefItem, menu AS MenuDef) AS STRING
DECLARE FUNCTION get_special_menu_caption(subtype AS INTEGER, edit_mode AS INTEGER= NO) AS STRING
DECLARE SUB create_default_menu(menu AS MenuDef)
DECLARE FUNCTION anchor_point(anchor AS INTEGER, size AS INTEGER) AS INTEGER
DECLARE FUNCTION read_menu_int (menu AS MenuDef, intoffset AS INTEGER) as integer
DECLARE SUB write_menu_int (menu AS MenuDef, intoffset AS INTEGER, n AS INTEGER)
DECLARE FUNCTION read_menu_item_int (mi AS MenuDefItem, intoffset AS INTEGER) as integer
DECLARE SUB write_menu_item_int (mi AS MenuDefItem, intoffset AS INTEGER, n AS INTEGER)
DECLARE SUB position_menu_item (menu AS MenuDef, cap AS STRING, i AS INTEGER, BYREF where AS XYPair)
DECLARE FUNCTION append_menu_item(BYREF menu AS MenuDef, caption AS STRING, t AS INTEGER=0, sub_t AS INTEGER=0) as integer
DECLARE SUB remove_menu_item OVERLOAD(BYREF menu AS MenuDef, BYVAL mi AS MenuDefItem ptr)
DECLARE SUB remove_menu_item OVERLOAD(BYREF menu AS MenuDef, BYVAL mislot AS INTEGER)
DECLARE SUB swap_menu_items(BYREF menu1 AS MenuDef, BYVAL mislot1 AS INTEGER, BYREF menu2 AS MenuDef, BYVAL mislot2 AS INTEGER)

DECLARE FUNCTION bound_arg(n AS INTEGER, min AS INTEGER, max AS INTEGER, argname AS ZSTRING PTR, context AS ZSTRING PTR=nulzstr, fromscript AS INTEGER=YES) AS INTEGER
DECLARE SUB reporterr(msg AS STRING, errlvl AS INTEGER = 5)

DECLARE FUNCTION load_tag_name (index AS INTEGER) AS STRING
DECLARE SUB save_tag_name (tagname AS STRING, index AS INTEGER)
DECLARE FUNCTION tag_condition_caption(n AS INTEGER, prefix AS STRING="Tag", zerocap AS STRING="", onecap AS STRING="", negonecap AS STRING="") AS STRING
DECLARE FUNCTION tag_set_caption(n AS INTEGER, prefix AS STRING="Set Tag") AS STRING
DECLARE FUNCTION onoroff (n AS INTEGER) AS STRING
DECLARE FUNCTION yesorno (n AS INTEGER, yes_cap AS STRING="YES", no_cap AS STRING="NO") AS STRING

DECLARE FUNCTION enter_or_space () AS INTEGER

DECLARE SUB write_npc_int (npcdata AS NPCType, intoffset AS INTEGER, n AS INTEGER)
DECLARE FUNCTION read_npc_int (npcdata AS NPCType, intoffset AS INTEGER) AS INTEGER

DECLARE FUNCTION xreadbit (bitarray() AS INTEGER, bitoffset AS INTEGER, intoffset AS INTEGER=0) AS INTEGER

DECLARE SUB draw_scrollbar OVERLOAD (state AS MenuState, rect AS RectType, count AS INTEGER, boxstyle AS INTEGER=0, page AS INTEGER)
DECLARE SUB draw_scrollbar OVERLOAD (state AS MenuState, rect AS RectType, boxstyle AS INTEGER=0, page AS INTEGER)
DECLARE SUB draw_scrollbar OVERLOAD (state AS MenuState, menu AS MenuDef, page AS INTEGER)
DECLARE SUB draw_fullscreen_scrollbar(state AS MenuState, boxstyle AS INTEGER=0, page AS INTEGER)

DECLARE SUB notification (show_msg AS STRING)

DECLARE FUNCTION get_text_box_height(BYREF box AS TextBox) AS INTEGER
DECLARE FUNCTION last_inv_slot() AS INTEGER

DECLARE FUNCTION decode_backslash_codes(s AS STRING) AS STRING
DECLARE FUNCTION escape_nonprintable_ascii(s AS STRING) AS STRING

DECLARE SUB set_homedir()
DECLARE FUNCTION get_help_dir() AS STRING
DECLARE FUNCTION load_help_file(helpkey AS STRING) AS STRING
DECLARE SUB save_help_file(helpkey AS STRING, text AS STRING)

'These were added from other, less-appropriate places
DECLARE FUNCTION filenum(n AS INTEGER) AS STRING

'Sprite loading convenience functions
DECLARE SUB load_sprite_and_pal (BYREF img AS GraphicPair, BYVAL spritetype, BYVAL index AS INTEGER, BYVAL palnum AS INTEGER=-1)
DECLARE SUB unload_sprite_and_pal (BYREF img AS GraphicPair)

'Global variables
EXTERN sourcerpg as string
EXTERN as string game, tmpdir, exename, workingdir, homedir
EXTERN uilook() as integer
EXTERN as integer vpage, dpage
EXTERN buffer() as integer
EXTERN fadestate as integer
EXTERN master() as RGBcolor
EXTERN keyv() as integer
EXTERN gen() as integer
EXTERN fmvol as integer
EXTERN sprite_sizes() AS SpriteSize
EXTERN statnames() as string
EXTERN cmdline_args() as string
EXTERN log_dir as string
EXTERN orig_dir as string

#ENDIF
