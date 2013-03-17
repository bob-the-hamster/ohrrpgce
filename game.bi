'OHRRPGCE - game.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from game.bas

#IFNDEF GAME_BI
#DEFINE GAME_BI

#INCLUDE "game_udts.bi"

declare sub prepare_map (byval afterbat as integer=NO, byval afterload as integer=NO)
declare sub displayall()
declare function valid_item_slot(byval item_slot as integer) as integer
declare function valid_item(byval itemid as integer) as integer
declare function valid_hero_party(byval who as integer, byval minimum as integer=0) as integer
declare function really_valid_hero_party(byval who as integer, byval maxslot as integer=40, byval errlvl as scriptErrEnum = serrBadOp) as integer
declare function valid_stat(byval statid as integer) as integer
declare function valid_menuslot(byval menuslot as integer) as integer
declare function valid_menuslot_and_mislot(byval menuslot as integer, byval mislot as integer) as integer
declare function valid_plotstr(byval n as integer, byval errlvl as scriptErrEnum = serrBound) as integer
declare function valid_formation(byval form as integer) as integer
declare function valid_formation_slot(byval form as integer, byval slot as integer) as integer
declare function valid_zone(byval id as integer) as integer
declare function valid_door(byval id as integer) as integer
declare function valid_tile_pos(byval x as integer, byval y as integer) as integer
declare sub loadmap_gmap(byval mapnum as integer)
declare sub loadmap_npcl(byval mapnum as integer)
declare sub loadmap_npcd(byval mapnum as integer)
declare sub loadmap_tilemap(byval mapnum as integer)
declare sub loadmap_passmap(byval mapnum as integer)
declare sub loadmap_foemap(byval mapnum as integer)
declare sub loadmap_zonemap(byval mapnum as integer)
declare sub loadmaplumps (byval mapnum as integer, byval loadmask as integer)
declare sub menusound(byval s as integer)
declare sub usemenusounds (byval deckey as integer = scUp, byval inckey as integer = scDown)
declare sub dotimer(byval l as integer)
declare function dotimerbattle() as integer
declare function count_sav(filename as string) as integer
declare function add_menu (byval record as integer, byval allow_duplicate as integer=no) as integer
declare sub remove_menu (byval slot as integer, byval run_on_close as integer=YES)
declare sub bring_menu_forward (byval slot as integer)
declare function menus_allow_gameplay () as integer
declare function menus_allow_player () as integer
declare sub player_menu_keys ()
declare sub check_menu_tags ()
declare sub tag_updates (byval npc_visibility as integer=YES)
declare function game_usemenu (state as menustate) as integer
declare function find_menu_id (byval id as integer) as integer
declare function find_menu_handle (byval handle as integer) as integer
declare function find_menu_item_handle_in_menuslot (byval handle as integer, byval menuslot as integer) as integer
declare function find_menu_item_handle (byval handle as integer, byref found_in_menuslot as integer) as integer
declare function assign_menu_item_handle (byref mi as menudefitem) as integer
declare function assign_menu_handles (byref menu as menudef) as integer
declare function menu_item_handle_by_slot(byval menuslot as integer, byval mislot as integer, byval visible_only as integer=yes) as integer
declare function find_menu_item_slot_by_string(byval menuslot as integer, s as string, byval mislot as integer=0, byval visible_only as integer=yes) as integer
declare function allowed_to_open_main_menu () as integer
declare function random_formation (byval set as integer) as integer
declare sub init_default_text_colors()
DECLARE FUNCTION activate_menu_item(mi as MenuDefItem, byval menuslot as integer) as integer
DECLARE SUB init_text_box_slices(txt as TextBoxState)
DECLARE SUB cleanup_text_box ()
DECLARE SUB recreate_map_slices()
DECLARE SUB refresh_map_slice()
DECLARE SUB refresh_map_slice_tilesets()
DECLARE SUB refresh_walkabout_layer_sort()
DECLARE FUNCTION vehicle_is_animating() as integer
DECLARE SUB reset_vehicle(v as vehicleState)
DECLARE SUB dump_vehicle_state()
DECLARE SUB usenpc(byval cause as integer, byval npcnum as integer)
DECLARE SUB sfunctions (byval cmdid as integer)
DECLARE FUNCTION first_free_slot_in_party() as integer
DECLARE FUNCTION first_free_slot_in_active_party() as integer
DECLARE FUNCTION first_free_slot_in_reserve_party() as integer
DECLARE FUNCTION free_slots_in_party() as integer
DECLARE SUB update_walkabout_slices()
DECLARE SUB update_walkabout_hero_slices()
DECLARE SUB update_walkabout_npc_slices()
DECLARE SUB update_walkabout_pos (byval walkabout_cont as slice ptr, byval x as integer, byval y as integer, byval z as integer)
DECLARE FUNCTION should_hide_hero_caterpillar() as integer
DECLARE FUNCTION should_show_normal_caterpillar() as integer
DECLARE SUB change_npc_def_sprite (byval npc_id as integer, byval walkabout_sprite_id as integer)
DECLARE SUB change_npc_def_pal (byval npc_id as integer, byval palette_id as integer)
DECLARE FUNCTION create_walkabout_slices(byval parent as Slice Ptr) as Slice Ptr
DECLARE SUB create_walkabout_shadow (byval walkabout_cont as Slice Ptr)
DECLARE SUB delete_walkabout_shadow (byval walkabout_cont as Slice Ptr)
DECLARE SUB reset_game_state ()
DECLARE SUB cleanup_game_slices ()
DECLARE FUNCTION hero_layer() as Slice Ptr
DECLARE FUNCTION npc_layer() as Slice Ptr
DECLARE SUB queue_fade_in (byval delay as integer = 0)
DECLARE SUB check_for_queued_fade_in ()
DECLARE FUNCTION find_door (byval tilex as integer, byval tiley as integer) as integer
DECLARE FUNCTION find_doorlink (byval door_id as integer) as integer

DECLARE SUB update_hero_zones (byval who as integer)
DECLARE SUB update_npc_zones (byval npcref as integer)
DECLARE SUB process_zone_eachstep_triggers (who as string, byval zones as integer vector)
DECLARE SUB process_zone_entry_triggers (who as string, byval oldzones as integer vector, byval newzones as integer vector)

#ENDIF
