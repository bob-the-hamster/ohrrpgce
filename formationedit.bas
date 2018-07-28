'OHRRPGCE CUSTOM - Enemy/Hero Formation/Formation Set Editors
'(C) Copyright 1997-2018 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability

#include "config.bi"
#include "const.bi"
#include "udts.bi"
#include "custom.bi"
#include "allmodex.bi"
#include "common.bi"
#include "loading.bi"
#include "customsubs.bi"
#include "slices.bi"
#include "thingbrowser.bi"


'Local SUBs
DECLARE SUB individual_formation_editor ()
DECLARE SUB formation_set_editor ()
DECLARE SUB draw_formation_slices OVERLOAD (eform as Formation, rootslice as Slice ptr, selected_slot as integer, page as integer)
DECLARE SUB draw_formation_slices OVERLOAD (eform as Formation, hform as HeroFormation, rootslice as Slice ptr, selected_slot as integer, page as integer, byval heromode as bool=NO)
DECLARE SUB load_formation_slices(ename() as string, form as Formation, rootslice as Slice ptr ptr)
DECLARE SUB hero_formation_editor ()
DECLARE SUB formation_init_added_enemy(byref slot as FormationSlot)

DECLARE SUB formation_set_editor_load_preview(state as MenuState, byref form_id as integer, formset as FormationSet, form as Formation, ename() as string, byref rootslice as Slice Ptr)

' Formation editor slice lookup codes
CONST SL_FORMEDITOR_BACKDROP = 100
CONST SL_FORMEDITOR_ENEMY = 200  '+0 to +7 for 8 slots
CONST SL_FORMEDITOR_LAST_ENEMY = 299  'End of range indicating an enemy slot
CONST SL_FORMEDITOR_CURSOR = 300
CONST SL_FORMEDITOR_HERO_AREA = 399  'container that holds heroes
CONST SL_FORMEDITOR_HERO = 400  '+0 to +3 for 4 slots


'Total-level menu
SUB formation_editor
 DIM menu(3) as string
 menu(0) = "Return to Main Menu"
 menu(1) = "Edit Individual Enemy Formations..."
 menu(2) = "Construct Formation Sets..."
 menu(3) = "Edit Hero Formations..."

 DIM state as MenuState
 state.size = 24
 state.last = UBOUND(menu)

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN EXIT DO
  IF keyval(scF1) > 1 THEN show_help "formation_main"
  usemenu state
  IF enter_space_click(state) THEN
   IF state.pt = 0 THEN EXIT DO
   IF state.pt = 1 THEN individual_formation_editor
   IF state.pt = 2 THEN formation_set_editor
   IF state.pt = 3 THEN hero_formation_editor
  END IF

  clearpage dpage
  standardmenu menu(), state, 0, 0, dpage

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
END SUB

SUB formation_set_editor
 DIM form as Formation
 DIM formset as FormationSet
 DIM set_id as integer = 1, form_id as integer
 DIM menu(23) as string
 DIM rootslice as Slice ptr
 DIM as string ename(7)
 DIM state as MenuState
 state.last = UBOUND(menu)
 state.size = 24
 DIM menuopts as MenuOptions
 menuopts.edged = YES
 menuopts.itemspacing = -1

 LoadFormationSet formset, set_id
 formation_set_editor_load_preview state, form_id, formset, form, ename(), rootslice

 setkeys
 DO
  setwait 55
  setkeys
  IF keyval(scESC) > 1 THEN
   SaveFormationSet formset, set_id
   EXIT DO
  END IF
  IF keyval(scF1) > 1 THEN show_help "formation_sets"
  IF usemenu(state) THEN 
   formation_set_editor_load_preview state, form_id, formset, form, ename(), rootslice
  END IF
  IF enter_space_click(state) THEN
   IF state.pt = 0 THEN
    SaveFormationSet formset, set_id
    EXIT DO
   END IF
  END IF
  IF state.pt = 1 THEN
   DIM remember_id as integer = set_id
   IF intgrabber(set_id, 1, 255) THEN
    SaveFormationSet formset, remember_id
    LoadFormationSet formset, set_id
   END IF
  END IF
  IF state.pt = 2 THEN intgrabber formset.frequency, 0, 200
  IF state.pt = 3 THEN tag_grabber formset.tag, state
  IF state.pt >= 4 THEN
   IF intgrabber(formset.formations(state.pt - 4), -1, gen(genMaxFormation)) THEN
    formation_set_editor_load_preview state, form_id, formset, form, ename(), rootslice
   END IF
  END IF
  IF state.pt >= 4 AND form_id >= 0 THEN
   draw_formation_slices form, rootslice, -1, dpage
  ELSE
   clearpage dpage
  END IF
  menu(0) = "Previous Menu"
  menu(1) = CHR(27) & "Formation Set " & set_id & CHR(26)
  menu(2) = "Battle Frequency: " & formset.frequency & " (" & step_estimate(formset.frequency, 40, 160, "-", " steps") & ")"
  menu(3) = tag_condition_caption(formset.tag, "Only if tag", "No tag check")
  FOR i as integer = 0 TO 19
   IF formset.formations(i) = -1 THEN
    menu(4 + i) = "Empty"
   ELSE
    menu(4 + i) = "Formation " & formset.formations(i)
   END IF
  NEXT i

  standardmenu menu(), state, 0, 0, dpage, menuopts

  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP
 DeleteSlice @rootslice
 EXIT SUB

END SUB

SUB formation_set_editor_load_preview(state as MenuState, byref form_id as integer, formset as FormationSet, form as Formation, ename() as string, byref rootslice as slice Ptr)
 IF state.pt >= 4 THEN
  '--have form selected
  form_id = formset.formations(state.pt - 4)
  IF form_id >= 0 THEN
   '--form not empty
   LoadFormation form, form_id
   load_formation_slices ename(), form, @rootslice
  END IF
 END IF
END SUB

SUB hero_formation_editor ()
 DIM hero_form_id as integer = 0
 DIM test_form_id as integer = 0
 DIM ename(7) as string
 DIM eform as Formation
 DIM hform as HeroFormation
 DIM default_hform as HeroFormation
 DIM rootslice as Slice ptr
 DIM as integer i
 DIM positioning_mode as bool = NO
 DIM as integer bgwait, bgctr

 LoadFormation eform, test_form_id
 load_formation_slices ename(), eform, @rootslice

 DIM menu(6) as string
 DIM state as MenuState
 state.pt = 0
 state.top = 0
 state.first = 0
 state.last = UBOUND(menu)
 state.size = 20
 DIM menuopts as MenuOptions
 menuopts.edged = YES

 CONST first_hero_item = 3
 'slot -1 indicates no hero selected
 DIM slot as integer = state.pt - first_hero_item
 IF slot < 0 THEN slot = -1
 
 default_hero_formation default_hform
 load_hero_formation hform, hero_form_id

 setkeys
 DO
  setwait 55
  setkeys
  IF positioning_mode = YES THEN
   '--hero positioning mode
   IF keyval(scESC) > 1 OR enter_or_space() THEN setkeys: positioning_mode = NO
   IF readmouse.release AND mouseRight THEN setkeys: positioning_mode = NO
   IF keyval(scF1) > 1 THEN show_help "hero_formation_editor_placement"
   DIM as integer thiswidth = 0, thisheight = 0, movespeed = 1
   IF keyval(scShift) THEN movespeed = 8
   WITH hform.slots(slot)
    DIM hrect as Slice ptr = LookupSlice(SL_FORMEDITOR_HERO + slot, rootslice)
    IF hrect THEN
     thiswidth = hrect->Width
     thisheight = hrect->Height
    END IF
    IF keyval(scUp) > 0 THEN .pos.y -= movespeed
    IF keyval(scDown) > 0 THEN .pos.y += movespeed
    IF keyval(scLeft) > 0 THEN .pos.x -= movespeed
    IF keyval(scRight) > 0 THEN .pos.x += movespeed
    IF readmouse.dragging AND mouseLeft THEN
     .pos += (readmouse.pos - readmouse.lastpos)
    END IF
    'Hero positions are the bottom center of the sprite
    .pos.x = bound(.pos.x, -500, gen(genResolutionX) + 500)
    .pos.y = bound(.pos.y, -500, gen(genResolutionY) + 500)
   END WITH
  END IF
  IF positioning_mode = NO THEN
   '--menu mode
   IF keyval(scESC) > 1 THEN
    EXIT DO
   END IF
   IF keyval(scF1) > 1 THEN show_help "hero_formation_editor"
   usemenu state
   slot = state.pt - first_hero_item
   IF slot < 0 THEN slot = -1

   IF enter_space_click(state) THEN
    IF state.pt = 0 THEN
     EXIT DO
    END IF
    IF slot <> -1 THEN 'a hero slot
     positioning_mode = YES
    END IF
   END IF
   IF slot <> -1 THEN
    IF keyval(scCtrl) > 0 ANDALSO keyval(scD) > 1 THEN
     'Revert to default
     hform.slots(slot).pos.x = default_hform.slots(slot).pos.x
     hform.slots(slot).pos.y = default_hform.slots(slot).pos.y
    END IF
   END IF
   IF state.pt = 2 THEN
    IF intgrabber(test_form_id, 0, gen(genMaxFormation)) THEN
     'Test with a different enemy formation
     LoadFormation eform, test_form_id
     load_formation_slices ename(), eform, @rootslice
     bgwait = 0
     bgctr = 0
    END IF
   END IF
   IF state.pt = 1 THEN '---SELECT A DIFFERENT HERO FORMATION
    DIM as integer remember_id = hero_form_id
    IF intgrabber_with_addset(hero_form_id, 0, last_hero_formation_id(), 32767, "hero formation") THEN
     save_hero_formation hform, remember_id
     load_hero_formation hform, hero_form_id
     save_hero_formation hform, hero_form_id
    END IF
   END IF'--DONE SELECTING DIFFERENT HERO FORMATION
  END IF

  ' Draw screen

  IF eform.background_frames > 1 AND eform.background_ticks > 0 THEN
   bgwait = (bgwait + 1) MOD eform.background_ticks   'FIXME: off-by-one bug here
   IF bgwait = 0 THEN
    loopvar bgctr, 0, eform.background_frames - 1
    DIM sl as Slice ptr = LookupSlice(SL_FORMEDITOR_BACKDROP, rootslice)
    ChangeSpriteSlice sl, , (eform.background + bgctr) MOD gen(genNumBackdrops)
   END IF
  END IF
  draw_formation_slices eform, hform, rootslice, slot, dpage, YES

  IF positioning_mode THEN
   edgeprint "Arrow keys or mouse-drag", 0, 0, uilook(uiText), dpage
   edgeprint "ESC or right-click when done", 0, pBottom, uilook(uiText), dpage
   edgeprint "x=" & hform.slots(slot).pos.x & " y=" & hform.slots(slot).pos.y, pRight, 0, uilook(uiMenuItem), dpage
  ELSE
   menu(0) = "Previous Menu"
   menu(1) = CHR(27) + "Hero Formation " & hero_form_id & CHR(26)
   menu(2) = "Preview Enemy Formation: " & test_form_id
   FOR i as integer = 0 TO 3
    menu(first_hero_item + i) = "Hero Slot " & i & "(x=" & hform.slots(i).pos.x & " y=" & hform.slots(i).pos.y & ")"
   NEXT i
   standardmenu menu(), state, 0, 0, dpage, menuopts
  END IF
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 save_hero_formation hform, hero_form_id
 DeleteSlice @rootslice
END SUB

SUB individual_formation_editor ()
 DIM form_id as integer = 0
 DIM form as Formation
 DIM ename(7) as string
 DIM rootslice as Slice ptr
 DIM as integer i
 DIM positioning_mode as bool = NO
 DIM as integer bgwait, bgctr

 LoadFormation form, form_id
 load_formation_slices ename(), form, @rootslice
 IF form.music >= 0 THEN playsongnum form.music
 DIM last_music as integer = form.music

 DIM menu(16) as string
 DIM state as MenuState
 state.pt = 0
 state.top = 0
 state.first = 0
 state.last = UBOUND(menu)
 state.size = 20
 DIM menuopts as MenuOptions
 menuopts.edged = YES
 
 CONST first_enemy_item = 9
 'slot -1 indicates no enemy selected
 DIM slot as integer = state.pt - first_enemy_item
 IF slot < 0 THEN slot = -1

 setkeys
 DO
  setwait 55
  setkeys
  IF positioning_mode = YES THEN
   '--enemy positioning mode
   IF keyval(scESC) > 1 OR enter_or_space() THEN setkeys: positioning_mode = NO
   IF readmouse.release AND mouseRight THEN setkeys: positioning_mode = NO
   IF keyval(scF1) > 1 THEN show_help "formation_editor_placement"
   DIM as integer movespeed = 1
   IF keyval(scShift) THEN movespeed = 8
   WITH form.slots(slot)
    DIM sprite as Slice ptr = LookupSlice(SL_FORMEDITOR_ENEMY + slot, rootslice)
    DIM size as XYPair
    IF sprite THEN size = sprite->Size
    ' Note that enemy positions are the top-left corner of the sprite
    ' (which needs to be changed)
    IF keyval(scUp) > 0 THEN .pos.y -= movespeed
    IF keyval(scDown) > 0 THEN .pos.y += movespeed
    IF keyval(scLeft) > 0 THEN .pos.x -= movespeed
    IF keyval(scRight) > 0 THEN .pos.x += movespeed
    IF readmouse.dragging AND mouseLeft THEN
     .pos += (readmouse.pos - readmouse.lastpos)
    END IF
    ' FIXME: battles are still stuck at 320x200 for the moment, but switch to this later
    ' .pos.x = bound(.pos.x, -size.w\2, gen(genResolutionX) - size.w\2)
    ' .pos.y = bound(.pos.y, -size.h\2, gen(genResolutionY) - size.h\2)
    .pos.x = bound(.pos.x, -size.w\2, 320 - size.w\2)
    .pos.y = bound(.pos.y, -size.h\2, 200 - size.h\2)
   END WITH
  END IF
  IF positioning_mode = NO THEN
   '--menu mode
   IF keyval(scESC) > 1 THEN
    EXIT DO
   END IF
   IF keyval(scF1) > 1 THEN show_help "formation_editor"
   IF cropafter_keycombo(state.pt = 1) THEN cropafter form_id, gen(genMaxFormation), 0, game + ".for", 80
   usemenu state
   slot = state.pt - first_enemy_item
   IF slot < 0 THEN slot = -1

   IF enter_space_click(state) THEN
    IF state.pt = 0 THEN
     EXIT DO
    END IF
    IF state.pt = 2 THEN
     DIM backdropb as BackdropSpriteBrowser
     form.background = backdropb.browse(form.background)
     bgwait = 0
     bgctr = 0
     load_formation_slices ename(), form, @rootslice
    END IF
    IF state.pt = 5 THEN
     form.music = song_picker_or_none(form.music + 1) - 1
     state.need_update = YES
    END IF
    IF slot <> -1 THEN 'an enemy
     DIM browse_for_enemy as bool = NO
     DIM in_slot as integer = form.slots(slot).id
     IF in_slot >= 0 THEN
      'This slot has an enemy already
      DIM choices(1) as string = {"Reposition enemy", "Change Which Enemy"}
      SELECT CASE multichoice("Slot " & slot, choices())
       CASE 0: positioning_mode = YES
       CASE 1: browse_for_enemy = YES
      END SELECT
     ELSE
      'Empty slot
      browse_for_enemy = YES
     END IF
     IF browse_for_enemy THEN
      DIM oldenemy as integer = in_slot
      form.slots(slot).id = enemy_picker_or_none(in_slot + 1) - 1
      IF oldenemy <> form.slots(slot).id THEN
       load_formation_slices ename(), form, @rootslice
       IF oldenemy = -1 THEN
        formation_init_added_enemy form.slots(slot)
       END IF
      END IF
     END IF
    END IF
   END IF
   IF state.pt = 2 THEN
    IF intgrabber(form.background, 0, gen(genNumBackdrops) - 1) THEN
     bgwait = 0
     bgctr = 0
     load_formation_slices ename(), form, @rootslice
    END IF
   END IF
   IF state.pt = 3 THEN
    'IF intgrabber(form.background_frames, 1, 50) THEN
    DIM temp as integer = form.background_frames - 1
    IF xintgrabber(temp, 2, 50) THEN
     IF form.background_frames = 1 THEN form.background_ticks = 8  'default to 8 ticks because 1 tick can be really painful
     form.background_frames = temp + 1
     IF bgctr >= form.background_frames THEN
      bgctr = 0
      load_formation_slices ename(), form, @rootslice
     END IF
    END IF
   END IF
   IF state.pt = 4 THEN
    IF intgrabber(form.background_ticks, 0, 1000) THEN
     bgwait = 0
    END IF
   END IF
   IF state.pt = 5 THEN
    IF intgrabber(form.music, -2, gen(genMaxSong)) THEN
     state.need_update = YES
    END IF
   END IF
   IF state.pt = 6 THEN
    tag_set_grabber(form.victory_tag, state)
   END IF
   IF state.pt = 7 THEN
    intgrabber(form.death_action, -1, 0)
   END IF
   IF state.pt = 8 THEN
    intgrabber(form.hero_form, 0, last_hero_formation_id())
   END IF
   IF state.pt = 1 THEN '---SELECT A DIFFERENT FORMATION
    DIM as integer remember_id = form_id
    IF intgrabber_with_addset(form_id, 0, gen(genMaxFormation), 32767, "formation") THEN
     SaveFormation form, remember_id
     IF form_id > gen(genMaxFormation) THEN
      gen(genMaxFormation) = form_id
      ClearFormation form
      form.music = gen(genBatMus) - 1
      SaveFormation form, form_id
     END IF
     LoadFormation form, form_id
     load_formation_slices ename(), form, @rootslice
     state.need_update = YES
     bgwait = 0
     bgctr = 0
    END IF
   END IF'--DONE SELECTING DIFFERENT FORMATION
   IF slot <> -1 THEN
    WITH form.slots(slot)
     DIM oldenemy as integer = .id
     IF form.slots(slot).id >= 0 AND enter_space_click(state) THEN
      'Pressing enter should go to placement mode (handled above)
     ELSEIF enemygrabber(.id, state, 0, -1) THEN
      'This would treat the x/y position as being the bottom middle of enemies, which makes much more
      'sense, but that would change where enemies of different sizes are spawned in slots in existing games
      'See the Plan for battle formation improvements
      '.pos.x += w(slot) \ 2
      '.pos.y += h(slot)
      load_formation_slices ename(), form, @rootslice
      formation_init_added_enemy form.slots(slot)
     END IF
    END WITH
   END IF
  END IF
  
  IF state.need_update THEN
   IF form.music >= 0 THEN
    IF form.music <> last_music THEN
     playsongnum form.music
    END IF
   ELSE
    music_stop
   END IF
   last_music = form.music
   state.need_update = NO
  END IF

  ' Draw screen

  IF form.background_frames > 1 AND form.background_ticks > 0 THEN
   bgwait = (bgwait + 1) MOD form.background_ticks
   IF bgwait = 0 THEN
    loopvar bgctr, 0, form.background_frames - 1
    DIM sl as Slice ptr = LookupSlice(SL_FORMEDITOR_BACKDROP, rootslice)
    ChangeSpriteSlice sl, , (form.background + bgctr) MOD gen(genNumBackdrops)
   END IF
  END IF
  draw_formation_slices form, rootslice, slot, dpage

  IF positioning_mode THEN
   edgeprint "Arrow keys or mouse-drag", 0, 0, uilook(uiText), dpage
   edgeprint "ESC or right-click when done", 0, pBottom, uilook(uiText), dpage
   edgeprint "x=" & form.slots(slot).pos.x & " y=" & form.slots(slot).pos.y, pRight, 0, uilook(uiMenuItem), dpage
  ELSE
   menu(0) = "Previous Menu"
   menu(1) = CHR(27) + "Formation " & form_id & CHR(26)
   menu(2) = "Backdrop: " & form.background
   IF form.background_frames <= 1 THEN
    menu(3) = "Backdrop Animation: none"
    menu(4) = " Ticks per Backdrop Frame: -NA-"
   ELSE
    menu(3) = "Backdrop Animation: " & form.background_frames & " frames"
    menu(4) = " Ticks per Backdrop Frame: " & form.background_ticks
   END IF
   menu(5) = "Battle Music:"
   IF form.music = -2 THEN
     menu(5) &= " -same music as map-"
   ELSEIF form.music = -1 THEN
     menu(5) &= " -silence-"
   ELSEIF form.music >= 0 THEN
     menu(5) &= " " & form.music & " " & getsongname(form.music)
   END IF
   menu(6) = "Victory Tag: " & tag_choice_caption(form.victory_tag)
   menu(7) = "On Death: "
   IF form.death_action = 0 THEN
    menu(7) &= "gameover/death script"
   ELSEIF form.death_action = -1 THEN
    menu(7) &= "continue game"
   END IF
   menu(8) = "Hero Formation: " & form.hero_form

   FOR i as integer = 0 TO 7
    menu(first_enemy_item + i) = "Enemy:" + ename(i)
   NEXT i
   standardmenu menu(), state, 0, 0, dpage, menuopts
  END IF
  SWAP vpage, dpage
  setvispage vpage
  dowait
 LOOP

 SaveFormation form, form_id
 music_stop
 DeleteSlice @rootslice
END SUB

SUB formation_init_added_enemy(byref slot as FormationSlot)
 'default to middle of field
 IF slot.pos.x = 0 AND slot.pos.y = 0 THEN
  slot.pos.x = 70
  slot.pos.y = 95
 END IF
END SUB

'Deletes previous rootslice if any, then creates a bunch of sprite slices for enemies
'(but doesn't position them: that's done in draw_formation_slices), and rectangles for
'hero positions.
'Also loads enemy names.
SUB load_formation_slices(ename() as string, form as Formation, rootslice as Slice ptr ptr)
 DIM sl as Slice ptr
 DeleteSlice rootslice

 ' Root is backdrop
 *rootslice = NewSliceOfType(slSprite)
 sl = *rootslice
 ChangeSpriteSlice sl, sprTypeBackdrop, form.background
 sl->Lookup = SL_FORMEDITOR_BACKDROP
 sl->AutoSort = slAutoSortBottomY

 'Hero Area
 DIM h_area as Slice Ptr
 h_area = NewSliceOfType(slContainer, *rootslice)
 WITH *(h_area)
  .Lookup = SL_FORMEDITOR_HERO_AREA
  .X = 240
  .Y = 82
  .Width = 56
  .Height = 100
 END WITH
 ' Heroes
 FOR i as integer = 0 TO 3
  sl = NewSliceOfType(slRectangle, h_area)
  sl->Lookup = SL_FORMEDITOR_HERO + i
  ChangeRectangleSlice sl, , boxlook(0).bgcol, boxlook(0).edgecol
  sl->AnchorHoriz = 1
  sl->AnchorVert = 2
  sl->X = i * 8 + 16 'overridden by hero formation
  sl->Y = i * 20 + 40 'overridden by hero formation
  sl->Width = 32
  sl->Height = 40
  'Break ties with heroes behind
  sl->Sorter = i
 NEXT

 ' Enemies
 FOR i as integer = 0 TO 7
  ename(i) = "-EMPTY-"
  IF form.slots(i).id >= 0 THEN
   DIM enemy as EnemyDef
   loadenemydata enemy, form.slots(i).id
   WITH enemy
    ename(i) = form.slots(i).id & ":" & .name
    sl = NewSliceOfType(slSprite, *rootslice)
    ChangeSpriteSlice sl, sprTypeSmallEnemy + bound(.size, 0, 2), .pic, .pal
    sl->Lookup = SL_FORMEDITOR_ENEMY + i
    sl->Sorter = 100 + i
   END WITH
  END IF
 NEXT i

 ' Cursor (defaults to invisible)
 sl = NewSliceOfType(slText, *rootslice)
 sl->AlignHoriz = 1  'mid
 sl->AnchorHoriz = 1  'mid
 sl->Lookup = SL_FORMEDITOR_CURSOR
END SUB

SUB draw_formation_slices(eform as Formation, rootslice as Slice ptr, selected_slot as integer, page as integer)
 DIM hform as HeroFormation
 load_hero_formation hform, eform.hero_form
 draw_formation_slices eform, hform, rootslice, selected_slot, page, NO
END SUB

SUB draw_formation_slices(eform as Formation, hform as HeroFormation, rootslice as Slice ptr, selected_slot as integer, page as integer, byval heromode as bool=NO)
 STATIC flash as integer
 flash = (flash + 1) MOD 256
 DIM cursorsl as Slice ptr = LookupSlice(SL_FORMEDITOR_CURSOR, rootslice)
 cursorsl->Visible = NO

 ' Set enemy positions (and maybe parent of cursor slice)
 DIM sl as Slice ptr = rootslice->FirstChild
 WHILE sl
  IF sl->Lookup >= SL_FORMEDITOR_ENEMY AND sl->Lookup <= SL_FORMEDITOR_LAST_ENEMY THEN
   'Is an enemy
   DIM enemy_slot as integer = sl->Lookup - SL_FORMEDITOR_ENEMY
   DIM fslot as FormationSlot ptr = @eform.slots(enemy_slot)
   IF fslot->id < 0 THEN debugc errPromptBug, "Formation enemy slice corresponds to an empty slot"
   sl->X = fslot->pos.x
   sl->Y = fslot->pos.y
   IF NOT heromode THEN
    IF enemy_slot = selected_slot AND cursorsl <> NULL THEN
     cursorsl->Visible = YES
     SetSliceParent cursorsl, sl
     ChangeTextSlice cursorsl, CHR(25), flash
    END IF
   END IF
  END IF
  sl = sl->NextSibling
 WEND
 
 ' Set hero positions (and maybe parent of cursor slice)
 DIM h_area as Slice ptr = LookupSlice(SL_FORMEDITOR_HERO_AREA, rootslice)
 DIM hrect as Slice Ptr
 FOR i as integer = 0 TO 3
  hrect = LookupSlice(SL_FORMEDITOR_HERO + i, h_area)
  hrect->X = hform.slots(i).pos.x
  hrect->Y = hform.slots(i).pos.y
  IF heromode THEN
   IF i = selected_slot AND cursorsl <> NULL THEN
    cursorsl->Visible = YES
    SetSliceParent cursorsl, hrect
    ChangeTextSlice cursorsl, CHR(25), flash
   END IF
  END IF
 NEXT i

 clearpage page
 DrawSlice rootslice, page
END SUB
