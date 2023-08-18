'OHRRPGCE - Game/Custom general menu code
'(C) Copyright 1997-2023 James Paige, Ralph Versteegen, and the OHRRPGCE Developers
'Dual licensed under the GNU GPL v2+ and MIT Licenses. Read LICENSE.txt for terms and disclaimer of liability.

#include "config.bi"
#include "udts.bi"
#include "const.bi"
#include "scrconst.bi"
#include "allmodex.bi"
#include "common.bi"
#include "menus.bi"
#include "loading.bi"

#IFDEF IS_GAME
 #include "scriptcommands.bi"
#ENDIF

'Local functions
DECLARE SUB LoadMenuItems(menu_set as MenuSet, dat as MenuDef, byval record as integer)
DECLARE SUB LoadMenuItem(byval f as integer, items() as MenuDefItem ptr, byval record as integer)
DECLARE SUB SaveMenuItems(menu_set as MenuSet, dat as MenuDef, byval record as integer)
DECLARE SUB SaveMenuItem(byval f as integer, mi as MenuDefItem, byval record as integer, byval menunum as integer, byval itemnum as integer)

'TypeTables
DEFINE_VECTOR_OF_CLASS(BasicMenuItem, BasicMenuItem)
DEFINE_VECTOR_OF_CLASS(SimpleMenuItem, SimpleMenuItem)
DEFINE_VECTOR_OF_CLASS(MenuDefItem, MenuDefItem)

' If > 0, enable mouse controls of menus even if running a game that has disabled that.
' This can be incremented while we are inside a debug/engine menu (to allow nesting).
DIM force_use_mouse as integer = 0


'==========================================================================================
'                                 Generic MenuState Stuff
'==========================================================================================

FUNCTION MenuState.empty() as bool
 RETURN last < first
END FUNCTION

'Whether there is a selected item
FUNCTION MenuState.pt_valid() as bool
 RETURN pt >= first AND pt <= last
END FUNCTION

'(Re-)initialise menu state, preserving .pt if valid
'.pt is moved to a selectable menu item.
SUB init_menu_state (byref state as MenuState, menu() as SimpleMenuItem, menuopts as MenuOptions = MenuOptions())
 WITH state
  DIM position_was_known as bool = .position_known
  'Position not known before it's actually drawn, fill with dummy data for now
  calc_menu_rect state, menuopts, .rect.xy
  .position_known = position_was_known

  .first = LBOUND(menu)
  .last = UBOUND(menu)
  IF .size <= 0 THEN .size = 20  'This is silly, which is why .autosize is (almost?) always used
  IF .empty() THEN
   .pt = .first - 1
  ELSE
   .pt = bound(.pt, .first, .last)  '.first <= .last
   IF menu(.pt).unselectable THEN
    .pt = .first - 1  'nothing selectable
    FOR i as integer = 0 TO UBOUND(menu)
     IF menu(i).unselectable = NO THEN .pt = i: EXIT FOR
    NEXT
   END IF
   'Menus with unselectable items have lookahead, which these +1,-1
   'attempt to simulate. Not perfect, but prevents some flickering
   '(TODO: modify correct_menu_state and all usemenu overloads to do this too)
   IF .pt <> -1 THEN .top = bound(.top, .pt - .size + 1, .pt - 1)
  END IF
  IF .position_known = NO ORELSE in_bound(.hover, .first, .last) = NO THEN
   .hover = .first - 1
  END IF
  .top = bound(.top, 0, large(.last - .size, 0))
 END WITH
END SUB

'(Re-)initialise menu state, preserving .pt if valid
'.pt is moved to a selectable menu item.
'
'menu may in fact be a vector of any type inheriting from BasicMenuItem.
'menu's typetable tells the size in bytes of each menu item
SUB init_menu_state (byref state as MenuState, byval menu as BasicMenuItem vector, menuopts as MenuOptions = MenuOptions())
 WITH state
  DIM position_was_known as bool = .position_known
  'Position not known before it's actually drawn, fill with dummy data for now
  calc_menu_rect state, menuopts, .rect.xy
  .position_known = position_was_known

  .first = 0
  .last = v_len(menu) - 1
  IF .size <= 0 THEN .size = 20
  IF .position_known = NO ORELSE in_bound(.hover, .first, .last) = NO THEN
   .hover = .first - 1
  END IF
  IF v_len(menu) = 0 THEN
   .pt = -1
  ELSE
   .pt = bound(.pt, .first, .last)  '.first <= .last
   IF v_at(menu, .pt)->unselectable THEN
    .pt = -1  'explicitly -1 when nothing selectable
    FOR i as integer = 0 TO v_len(menu) - 1
     IF v_at(menu, i)->unselectable = NO THEN .pt = i: EXIT FOR
    NEXT
   END IF
   'Menus with unselectable items have lookahead, which these +1,-1
   'attempt to simulate. Not perfect, but prevents some flickering
   '(TODO: modify correct_menu_state and all usemenu overloads to do this too)
   IF .pt <> -1 THEN .top = bound(.top, .pt - .size + 1, .pt - 1)
  END IF
  .top = bound(.top, 0, large(.last - .size, 0))
 END WITH
END SUB

SUB calc_menustate_size (byref state as MenuState)
 'For .autosized menus (standardmenu, not MenuDef) only!
 'Run this once per frame for a menu that should fill the whole screen vertically
 'Does not work unless .spacing is set correctly (set on call to standardmenu)
 'TODO: should pass the page to be drawn to to this sub.
 WITH state
  IF .spacing = 0 THEN
   ' This error is currently impossible
   IF .position_known = YES THEN debugc errBug, "calc_menustate_size: .spacing didn't get set"
   EXIT SUB
  END IF
  'By default, leave padding of 4 pixels at the top and 2 at the bottom
  IF .autosize_ignore_pixels = 0 AND .autosize_ignore_lines = 0 THEN .autosize_ignore_pixels = 6
  DIM ignorepix as integer = .autosize_ignore_pixels + .autosize_ignore_lines * large(.spacing, 10)
  .size = (vpages(dpage)->h - ignorepix) \ .spacing - 1
 END WITH
END SUB

'Simple... and yet, more options than a regular menu item
'Can also insert instead of appending... bad name
SUB append_simplemenu_item (byref menu as SimpleMenuItem vector, caption as zstring ptr, byval unselectable as bool = NO, byval col as integer = 0, byval dat as integer = 0, byval where as integer = -1)
 IF where = -1 THEN
  v_expand menu, 1
  where = v_len(menu) - 1
 END IF
 WITH menu[where]
  .text = *caption
  .col = col
  .bgcol = 0
  .unselectable = unselectable
  .disabled = NO
  .dat = dat
 END WITH
END SUB

'Is pos on menutext, which is the 'index'th menu item in the menu with given state?
FUNCTION menutext_hit_tester(menutext as string, state as MenuState, index as integer, pos as XYPair) as bool
 'IF NOT state.position_known THEN RETURN NO   'Unnecessary?
 DIM itempos as XYPair = state.rect.xy
 itempos.y += state.spacing * (index - state.top)
 RETURN rect_collide_point(XY_WH(itempos, textsize(menutext)), pos)
END FUNCTION

'A function usable as MenuState.hit_test if using standardmenu with a string array.
'Set state.hit_test_data = @menu(0)
FUNCTION stringmenu_hit_tester(state as MenuState, index as integer, pos as XYPair) as bool
 IF state.hit_test_data = NULL THEN RETURN NO
 DIM byref menutext as string = cptr(string ptr, state.hit_test_data)[index]
 RETURN menutext_hit_tester(menutext, state, index, pos)
END FUNCTION

FUNCTION find_menu_item_at_point (state as MenuState, pos as XYPair) as integer
 'If the on-screen position overlaps a MenuState, return the index of the menu item it is touching.
 'Return a value < state.first if it's not on any menu item.
 WITH state
  IF .position_known THEN
   DIM mpt as integer = rect_collide_point_vertical_chunk(.rect, pos, .spacing)
   IF mpt > -1 THEN
    mpt += .top
    ' Need to check against size, as there might be a few pixels inside .rect after
    ' the last visible menu item, where the next item isn't drawn
    IF mpt >= .first ANDALSO mpt <= .last ANDALSO mpt <= .top + .size THEN
     ' Optionally do a fine-grained test that it is horizontally on the menu item
     IF state.hit_test = NULL ORELSE state.hit_test(state, mpt, pos) THEN
      RETURN mpt  'Success
     END IF
    END IF
   END IF
  END IF
  RETURN .first - 1 'Mouse is not over a menu item!
 END WITH
END FUNCTION

' Updates state.hover, and returns YES if the mouse is over the menu.
' (You only need this if not calling usemenu or scrollmenu)
FUNCTION mouse_update_hover (state as MenuState) as bool
 DIM use_mouse as bool = YES
#IFDEF IS_GAME
 use_mouse = get_gen_bool("/mouse/mouse_menus") OR (force_use_mouse > 0)
#ENDIF
 IF use_mouse ANDALSO readmouse.active THEN
  state.hover = find_menu_item_at_point(state, readmouse.pos)
  RETURN state.hover >= state.first
 ELSE
  state.hover = state.first - 1
  RETURN NO
 END IF
END FUNCTION

' Updates state.pt for clicks/drags. This should be called only after mouse_update_hover has
' updated state.hover and returned YES, if state.hover is a selectable item.
SUB mouse_update_selection (state as MenuState)
 DIM buttons as integer = (readmouse.buttons OR readmouse.release)
 IF state.select_by_mouse_release THEN buttons = readmouse.release
 IF (buttons AND mouseLeft) ANDALSO readmouse.drag_dist < 10  THEN
  'Don't change selection while dragging, because dragging might be used
  'for scrolling (if mouse_drag_menu called)
  state.pt = state.hover
 ELSEIF (buttons AND mouseRight) ANDALSO readmouse.drag_dist < 10 THEN
  'Right button only selects if this is NOT a drag
  state.pt = state.hover
 ELSEIF state.drag_selecting AND buttons THEN
  'Popup menus do allow drag to select (and drag to confirm)
  state.pt = state.hover
 END IF
END SUB

'Handle just mouse controls, not keyboard. Doesn't support selectable()
'or .autosize!
SUB usemenu_mouse_only(state as MenuState)
 IF mouse_update_hover(state) THEN 'ANDALSO selectable(.hover) THEN
  mouse_update_selection(state)
 END IF
 mouse_scroll_menu state
END SUB

' This does a subset of what usemenu does, call this after modifying .pt, .last, .first or .size
' if not immediately calling usemenu.
SUB correct_menu_state (state as MenuState)
 WITH state
  IF .empty() THEN
   .pt = .first - 1
  ELSE
   .pt = bound(.pt, .first, .last)
  END IF
 END WITH
 correct_menu_state_top state
 mouse_update_hover state
END SUB

' Just fixup state.top
SUB correct_menu_state_top (state as MenuState)
 WITH state
  ' If the bottom of the menu is above the bottom of the screen, scroll up
  .top = large(small(.top, .last - .size), .first)
  ' Selected item must be visible (unless the menu is empty)
  IF .pt_valid() THEN .top = bound(.top, .pt - .size, .pt)
 END WITH
END SUB

' Adjust .top and .pt according to mouse wheel input.
SUB mouse_scroll_menu(byref state as MenuState)
 WITH state
  DIM lasttop as integer = large(.first, .last - .size)
  IF .hover >= .first THEN  'Mouse over the menu
   IF (readmouse().buttons AND mouseRight) = 0 THEN  'While right button down, scroll wheel affects intgrabber
    .top = bound(.top + (4 * readmouse().wheel_delta) \ 120, .first, lasttop)
    ' Make sure .pt is visible
    .pt = bound(.pt, .top, .top + .size)
   END IF
  END IF
 END WITH
END SUB

' By default, menus do not support scrolling by dragging the menu unless this is called.
SUB mouse_drag_menu(byref state as MenuState, byval button as MouseButton=mouseLeft, byval threshold as integer=10, byval magnify as double=1.0)
 WITH state
  IF .spacing = 0 THEN
   EXIT SUB
  END IF
  IF (readmouse.dragging AND button) = 0 THEN
   'No drag is happening
   .drag_start_top = .first - 1
  END IF
  DIM lasttop as integer = large(.first, .last - .size)
  IF .hover >= .first THEN  'Mouse over the menu
   IF (readmouse.dragging AND button) THEN
    IF .drag_start_top < .first THEN
     .drag_start_top = state.top
    END IF
    IF readmouse.drag_dist > threshold THEN
     DIM dist as integer = INT((readmouse.clickstart.y - readmouse.pos.y) / .spacing * magnify)
     .top = bound(.drag_start_top + dist, .first, lasttop)
     ' Make sure .pt is visible
     .pt = bound(.pt, .top, .top + .size)
    END IF
   END IF
  END IF
 END WITH
END SUB

FUNCTION usemenu (byref state as MenuState, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 WITH state
  IF .autosize THEN
   calc_menustate_size state
  END IF

  DIM oldptr as integer = .pt
  DIM oldtop as integer = .top

  IF .first < .last THEN
   IF keyval(deckey) > 1 THEN loopvar .pt, .first, .last, -1
   IF keyval(inckey) > 1 THEN loopvar .pt, .first, .last, 1
   IF keyval(scPageup) > 1 THEN .pt -= .size
   IF keyval(scPagedown) > 1 THEN .pt += .size
   IF keyval(scHome) > 1 THEN .pt = .first
   IF keyval(scEnd) > 1 THEN .pt = .last
  END IF
  correct_menu_state state  'Update .top and .pt

  usemenu_mouse_only state
  'IF mouse_update_hover(state) THEN mouse_update_selection(state)
  'mouse_scroll_menu state

  IF oldptr = .pt AND oldtop = .top THEN
   RETURN NO
  ELSE
   reset_menu_edit_state
   RETURN YES
  END IF

 END WITH
END FUNCTION

FUNCTION usemenu (byref pt as integer, byref top as integer, byval first as integer, byval last as integer, byval size as integer, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 'FIXME: eventually phase this out by making sure that all callers to usemenu have their own MenuState
 DIM state as MenuState
 WITH state
  .pt = pt
  .top = top
  .first = first
  .last = last
  .size = size
 END WITH
 DIM result as bool = usemenu(state, deckey, inckey)
 WITH state
  pt = .pt
  top = .top
  first = .first
  last = .last
  size = .size
 END WITH
 RETURN result
END FUNCTION

'a version for menus with unselectable items, skip items for which menudata[i].unselectable = YES
'menu may in fact be a vector of any type inheriting from BasicMenuItem.
'menu's typetable tells the size in bytes of each menu item
FUNCTION usemenu (state as MenuState, byval menudata as BasicMenuItem vector, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 IF state.empty() OR v_len(menudata) = 0 THEN
  correct_menu_state state
  RETURN NO
 END IF

 DIM selectable(v_len(menudata) - 1) as bool
 FOR idx as integer = 0 TO v_len(menudata) - 1
  selectable(idx) = NOT v_at(menudata, idx)->unselectable
 NEXT

 RETURN usemenu(state, selectable(), deckey, inckey)
END FUNCTION

'A version for MenuDef.
FUNCTION usemenu (state as MenuState, menu as MenuDef, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 IF state.empty() THEN
  correct_menu_state state
  RETURN NO
 END IF

 DIM selectable(state.last) as bool
 FOR idx as KBScancode = 0 TO state.last
  selectable(idx) = NOT menu.items[idx]->unselectable
 NEXT

 RETURN usemenu(state, selectable(), deckey, inckey)
END FUNCTION

'a version for menus with unselectable items, skip items for which selectable(i) = NO
FUNCTION usemenu (state as MenuState, selectable() as bool, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 IF state.empty() THEN
  correct_menu_state state
  RETURN NO
 END IF

 WITH state
  IF .autosize THEN
   calc_menustate_size state
  END IF
  'TODO: .size for MenuDef menus is usually correct, since it's set by init_menu_state and draw_menu, but it's
  'possible that the menu data has just been changed

  'Check there are selectable items
  DIM has_selectable as bool = NO
  FOR i as integer = .first TO .last
   IF selectable(i) THEN has_selectable = YES : EXIT FOR
  NEXT
  IF has_selectable = NO THEN
   .pt = .first - 1
   RETURN scrollmenu(state, deckey, inckey)
  END IF

  DIM as integer oldptr, oldtop, d, moved_d
  oldptr = .pt
  oldtop = .top
  d = 0
  moved_d = 0

  IF keyval(deckey) > 1 THEN d = -1
  IF keyval(inckey) > 1 THEN d = 1
  IF keyval(scPageup) > 1 THEN
   .pt = large(.pt - .size, .first)
   WHILE selectable(.pt) = 0 AND .pt > .first : loopvar(.pt, .first, .last, -1) : WEND
   IF selectable(.pt) = 0 THEN d = 1
   moved_d = -1
  END IF
  IF keyval(scPagedown) > 1 THEN
   .pt = small(.pt + .size, .last)
   WHILE selectable(.pt) = 0 AND .pt < .last : loopvar(.pt, .first, .last, 1) : WEND
   IF selectable(.pt) = 0 THEN d = -1
   moved_d = 1
  END IF
  IF keyval(scHome) > 1 THEN .pt = .last : d = 1
  IF keyval(scEnd) > 1 THEN .pt = .first : d = -1

  IF d THEN
   moved_d = d
   DO
    .top = bound(.top, .pt - .size, .pt)
    loopvar .pt, .first, .last, d
   LOOP WHILE selectable(.pt) = 0
  END IF

  IF moved_d THEN
   'we look ahead of the actual cursor, to bring unselectable items at the ends of the menu into view
   DIM lookahead as integer = .pt
   DO
    lookahead += moved_d
   LOOP WHILE bound(lookahead, .first, .last) = lookahead ANDALSO selectable(lookahead) = 0
   lookahead = bound(lookahead, .first, .last)
   .top = bound(.top, lookahead - .size, lookahead)
  END IF
  correct_menu_state state  'Update .top

  IF mouse_update_hover(state) ANDALSO selectable(.hover) THEN
   mouse_update_selection(state)
  END IF
  mouse_scroll_menu state

  IF oldptr = .pt AND oldtop = .top THEN
   RETURN NO
  ELSE
   reset_menu_edit_state
   RETURN YES
  END IF
 END WITH
END FUNCTION

'Standard controls for using and exiting a menu.
'Sets state.active = NO and returns either state.pt or escval to exit the menu
FUNCTION default_menu_controls(state as MenuState, escval as integer = -1) as integer
 IF keyval(ccCancel) > 1 THEN
  state.active = NO
  RETURN escval
 END IF
 IF readmouse.release AND (mouseLeft OR mouseRight) THEN
  IF NOT rect_collide_point(state.rect, readmouse.pos) THEN
   state.active = NO
   RETURN escval
  END IF
 END IF

 IF enter_space_click(state) THEN
  state.active = NO
  RETURN state.pt
 END IF

 usemenu state
END FUNCTION

'scrollmenu is like usemenu for menus where no menu item is selected:
'you just want to scroll a menu up and down (modifies .top; .pt is ignored).
'Returns true when view changed.
FUNCTION scrollmenu (state as MenuState, byval deckey as KBScancode = ccUp, byval inckey as KBScancode = ccDown) as bool
 WITH state
  IF .autosize THEN
   calc_menustate_size state
  END IF
  DIM oldtop as integer = .top
  DIM lasttop as integer = large(.first, .last - .size)
  IF keyval(deckey) > 1 THEN loopvar .top, .first, lasttop, -1
  IF keyval(inckey) > 1 THEN loopvar .top, .first, lasttop, 1
  IF keyval(scPageup) > 1 THEN .top = large(.first, .top - .size)
  IF keyval(scPagedown) > 1 THEN .top = small(lasttop, .top + .size)
  IF keyval(scHome) > 1 THEN .top = .first
  IF keyval(scEnd) > 1 THEN .top = lasttop
  mouse_update_hover(state)
  mouse_scroll_menu(state)
  RETURN (.top <> oldtop)
 END WITH
END FUNCTION

'shaded: both disabled and unselectable
SUB standard_to_basic_menu (menu() as string, byref state as MenuState, byref basicmenu as BasicMenuItem vector, byval shaded as bool ptr = NULL)
 v_new basicmenu, state.last - state.first + 1
 FOR i as integer = 0 TO state.last - state.first
  WITH basicmenu[i]
   .text = menu(state.first + i)
   .col = 0  'Default, usually uilook(uiMenuItem)
   IF shaded THEN
    .disabled = shaded[state.first + i]
    .unselectable = .disabled
   END IF
  END WITH
 NEXT
END SUB

' Overload for standardmenu. Not to be confused with calc_menustate_size, which only sets MenuState.size.
' Initialises/updates size and position data in MenuState, including .rect, and .size
' if .autosize is true.
' Used if you want to calculate the size of the menu before the first call to standardmenu,
' but unless you're using menuopts.calc_size, calling init_menu_state is sufficient.
' (Note: 'menu' is optional, needed only to calculate width.)
' Sets .position_known=YES to indicate that these members have been initialised,
' even if not called from standardmenu.
SUB calc_menu_rect(state as MenuState, menuopts as MenuOptions, pos as RelPosXY, page as integer = -1, menu as BasicMenuItem vector = NULL)
 IF page = -1 THEN page = vpage
 WITH state
  .spacing = 9 + menuopts.itemspacing

  ' TODO: calc_menu_rect used to call calc_menustate_size unconditionally. So still
  ' need to call it if .size is 0. But would be cleaner to just default .autosize to YES
  IF .autosize OR (.size = 0) THEN
   ' Calculate .size.
   ' usemenu also calls calc_menustate_size, but usemenu might not be called if the
   ' menu is inactive (more than one on-screen), and on the first tick with
   ' .autosize=YES before .spacing is set the correct .size won't be known either.
   ' (In that case, you should call init_menu_state, passing menuopts if used.)
   calc_menustate_size state
  END IF

  ' Width
  DIM wide as integer = menuopts.wide
  IF menuopts.calc_size ANDALSO menu THEN
   ' Widen the menu according to widest menu item
   ' (Note this is done unconditionally for MenuDef menus)
   FOR i as integer = 0 TO small(v_len(menu) - 1, .last)
    wide = large(wide, textwidth(v_at(menu, i)->text))
   NEXT
   ' Don't count a fullscreen scrollbar as being part of the menu. Probably doesn't matter.
   IF NOT menuopts.no_scrollbar AND NOT menuopts.fullscreen_scrollbar THEN wide += 6
  END IF
  .rect.wide = small(vpages(page)->w, wide)

  ' Height
  DIM num_menu_items as integer
  IF menuopts.calc_size THEN
   num_menu_items = small(.size, .last - .first) + 1
  ELSE
   num_menu_items = .size + 1  'Might be larger than actual number of items
  END IF
  .rect.high = small(vpages(page)->h, num_menu_items * .spacing)
  ' If autosized, maybe the menu rect, and therefore the scrollbar, should reach
  ' to the bottom of the screen regardless of autosize_ignore_lines/pixels? We
  ' use .fullscreen_scrollbar in several places because of that.
  'IF .autosize THEN .rect.high = vpages(page)->h

  ' Now position the menu, and clamp to screen size
  .rect.xy = relative_pos(pos, vpages(page)->size, .rect.wh)
  .position_known = YES
  .rect.wide = small(.rect.wide, vpages(page)->w - .rect.x)
  .rect.high = small(.rect.high, vpages(page)->h - .rect.y)
 END WITH
END SUB

SUB standardmenu (menu() as string, byref state as MenuState, x as RelPos = pMenuX, y as RelPos = pMenuY, page as integer, menuopts as MenuOptions)
 DIM basicmenu as BasicMenuItem vector
 standard_to_basic_menu menu(), state, basicmenu
 'Shift menu items so that state.first = 0
 DIM first as integer = state.first
 state.top -= first
 state.pt -= first
 state.hover -= first
 state.last -= first
 state.first = 0
 standardmenu basicmenu, state, x, y, page, menuopts
 state.top += first
 state.pt += first
 state.hover += first
 state.last += first
 state.first = first
 v_free basicmenu
END SUB

'Version which allows items to be "shaded" (they are both disabled/greyed out and
'unselectable (not affected by mouse hover)... which is often not what you want)
SUB standardmenu (menu() as string, byref state as MenuState, shaded() as bool, x as RelPos = pMenuX, y as RelPos = pMenuY, page as integer, menuopts as MenuOptions)
 BUG_IF(LBOUND(shaded) > LBOUND(menu) ORELSE UBOUND(shaded) < UBOUND(menu), "shaded() too small")
 DIM basicmenu as BasicMenuItem vector
 standard_to_basic_menu menu(), state, basicmenu, @shaded(0)
 'Shift menu items so that state.first = 0
 DIM first as integer = state.first
 state.top -= first
 state.pt -= first
 state.hover -= first
 state.last -= first
 state.first = 0
 standardmenu basicmenu, state, x, y, page, menuopts
 state.top += first
 state.pt += first
 state.hover += first
 state.last += first
 state.first = first
 v_free basicmenu
END SUB

'Draws an undecorated menu (just lines of coloured text, and optionally a scrollbar), as used throughout Custom.
'(The in-game user-customisable menus are drawn with draw_menu.)
'menu may in fact be a vector of any type inheriting from BasicMenuItem:
' standardmenu cast(BasicMenuItem vector, menu), ...
'The vector's internal typetable tells the size in bytes of each menu item
SUB standardmenu (byval menu as BasicMenuItem vector, state as MenuState, x as RelPos = pMenuX, y as RelPos = pMenuY, page as integer, menuopts as MenuOptions)

 'The following doesn't affect simple string array menus which are converted to BasicMenuItem menus
 BUG_IF(state.first <> 0, "state.first <> 0 not supported for BasicMenuItem menus!")

 calc_menu_rect state, menuopts, XY(x, y), page, menu
 DIM wide as integer = state.rect.wide
 'calc_menu_rect solved from RelPos to screen positions
 x = state.rect.x
 y = state.rect.y
 IF menuopts.edged THEN
  'Edged font is drawn at +1,+1
  IF x > 0 THEN x -= 1
  IF y > 0 THEN y -= 1
 END IF

 IF state.active THEN
  state.tog XOR= 1
 END IF

 IF NOT menuopts.no_scrollbar THEN
  IF menuopts.fullscreen_scrollbar THEN
   draw_fullscreen_scrollbar state, 0, page
  ELSE
   draw_scrollbar state, state.rect, 0, page
  END IF
 END IF

 DIM rememclip as ClipState = get_cliprect()
 shrinkclip x, , x + wide - 1, , vpages(page)

 FOR i as integer = state.top TO state.top + state.size
  IF i < v_len(menu) THEN
   WITH *v_at(menu, i)

    DIM linewidth as integer = textwidth(.text, IIF(menuopts.edged, fontEdged, fontPlain))
    IF .bgcol THEN
     'Note that BasicMenuItem.bgcol draws a rectangle across the width of the menu, while
     'menuopts.highlight/.drawbg or a text bg color is across the width of the text
     rectangle x + 0, y, wide, state.spacing, .bgcol, page
    END IF
    IF state.pt = i AND state.active AND menuopts.highlight_selection THEN
     rectangle x + 0, y, IIF(linewidth, linewidth, wide), state.spacing, uilook(uiHighlight), page
    ELSEIF menuopts.drawbg THEN
     trans_rectangle vpages(page), XYWH(x, y, linewidth, state.spacing), curmasterpal(uilook(uiBackground)), 0.55
    END IF

    DIM col as integer
    col = menu_item_color(state, i, .disabled, .unselectable, .col, .disabled_col, menuopts.normal_col, menuopts.disabled_col)

    DIM drawx as integer = x
    IF linewidth > wide AND state.active THEN
     IF menuopts.nevershowright = NO AND (state.pt = i OR menuopts.showright) THEN
      drawx = x + wide - linewidth
     END IF
    END IF
    IF menuopts.edged THEN
     edgeprint .text, drawx, y, col, page, YES
    ELSE
     textcolor col, 0
     printstr .text, drawx, y, page, YES
    END IF
    y += state.spacing
   END WITH
  END IF
 NEXT i

 get_cliprect() = rememclip
END SUB

'Determine the color to draw menu item index 'itemno' in menu 'state'.
'c_normal and c_disabled:
' The normal and disabled colors for the menu item.
' They can be 0, indicating to use the def_normal and def_disabled
' defaults instead, or < 0 to use a UI color (decoded with ColorIndex).
' This is a double-fallback, useful in some weird existing code.
'disabled: whether this item is disabled
'unselectable: whether this item is unselectable
FUNCTION menu_item_color(state as MenuState, itemno as integer, disabled as bool = NO, unselectable as bool = NO, c_normal as integer = 0, c_disabled as integer = 0, def_normal as integer = -uiMenuItem-1, def_disabled as integer = -uiDisabledItem-1) as integer
 DIM col as integer
 IF disabled THEN
  IF state.pt = itemno AND state.active THEN
   col = uilook(uiSelectedDisabled + state.tog)
  ELSE
   IF def_disabled = 0 THEN def_disabled = -uiDisabledItem - 1
   col = IIF(c_disabled, c_disabled, def_disabled)
  END IF
 ELSE
  IF state.pt = itemno AND state.active THEN
   col = uilook(uiSelectedItem + state.tog)
  ELSE
   IF def_normal = 0 THEN def_normal = -uiMenuItem - 1
   col = IIF(c_normal, c_normal, def_normal)
  END IF
 END IF
 col = ColorIndex(col)

 IF state.hover = itemno AND state.pt <> itemno AND state.active AND unselectable = NO THEN
  col = mouse_hover_tinted_color(col)
 END IF

 RETURN col
END FUNCTION

'==========================================================================================
'                                   Selection by typing
'==========================================================================================


CONST SELECT_TYPE_TIMEOUT as double = 0.7

'If the user typed something, returns YES and set select_query to a search string, to be used
'with e.g. INSTR or find_on_word_boundary_excluding, or select_on_word_boundary[_excluding]
'which handles all the details.
'Special care required on menus using strgrabber, or even intgrabber.
'Generally you should pass accept_numbers=NO on menus using intgrabber.
'Example usage:
'  setkeys YES
'
'  IF select_by_typing(selectst) THEN
'   select_on_word_boundary menu(), selectst, state
'  END IF
'
'  highlight_menu_typing_selection menu(), menu_display(), selectst, state
'  standardmenu menu_display(), state, , , dpage
'
FUNCTION select_by_typing(selectst as SelectTypeState, byval allow_numbers as bool = YES) as bool
 WITH selectst
  IF TIMER - .last_input_time > SELECT_TYPE_TIMEOUT THEN
   select_clear selectst
  END IF
  DIM intext as string = getinputtext
  IF LEN(intext) = 0 THEN RETURN NO
  'Only test first character for simplicity
  IF allow_numbers = NO ANDALSO (isdigit(intext[0]) ORELSE intext[0] = ASC("-")) THEN RETURN NO
  .last_input_time = TIMER

  .buffer += LCASE(intext)
  'If user has just typed the same character repeatedly, only search by that, otherwise by whole input
  '...unless the user is entering a number
  IF isdigit(.buffer[0]) THEN
   .query = .buffer
  ELSE
   .query = LEFT(.buffer, 1)
   FOR i as integer = 0 TO LEN(.buffer) - 1
    IF .buffer[i] <> .query[0] THEN
     .query = .buffer
     EXIT FOR
    END IF
   NEXT
  END IF
  RETURN YES
 END WITH
END FUNCTION

'Manually set select_by_typing state to inactive
SUB select_clear(selectst as SelectTypeState)
 selectst.buffer = ""
 selectst.query = ""
 selectst.highlight_at = 1
END SUB

'Copies contents of menu() to menu_display(), with text markup added to highlight
'text matching selectst.query.
'The calling menu should set selectst.query_at to the offset in menu(state.pt) which matches
'the query, or 0 if no match, after doing text matching after calling select_by_typing.
'Can also set query_at to -1 for an invisible match (no highlighting)
'(The select_on_word_boundary SUB handles this.)
'
'Idea: could highlight all matches rather than just one on the current line
SUB highlight_menu_typing_selection(menu() as string, menu_display() as string, selectst as SelectTypeState, state as MenuState)
 'If the user moves the cursor normally, reset
 '(Yes, this is a rather regretable function in which to put this)
 IF selectst.remember_pt <> state.pt THEN select_clear selectst
 selectst.remember_pt = state.pt

 FOR i as integer = LBOUND(menu) TO UBOUND(menu)
  menu_display(i) = menu(i)
  IF state.pt = i THEN
   menu_display(i) = highlight_menu_typing_selection_string(menu(i), selectst)
  END IF
 NEXT
END SUB

SUB highlight_menu_typing_selection(byref menu as BasicMenuItem vector, byref menu_display as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
 'Works with any type derived from BasicMenuItem.
 'If the user moves the cursor normally, reset
 '(Yes, this is a rather regretable function in which to put this)
 IF selectst.remember_pt <> state.pt THEN select_clear selectst
 selectst.remember_pt = state.pt

 IF state.first <> 0 OR v_len(menu) - 1 <> state.last THEN showbug "highlight_menu_typing_selection: bad MenuState"
 v_copy menu_display, menu

 IF state.pt >= 0 ANDALSO state.pt < v_len(menu_display) THEN
  v_at(menu_display, state.pt)->text = highlight_menu_typing_selection_string(v_at(menu, state.pt)->text, selectst)
 END IF
END SUB

'Internal function sometimes useful if a menu doesn't use a string array to store menu items
'Returns a modification of z with the part matching the search highlighted, using markup.
FUNCTION highlight_menu_typing_selection_string(z as string, selectst as SelectTypeState) as string
 WITH selectst
  'Initialisation
  IF .highlight_at = 0 THEN .highlight_at = 1

  IF .query_at THEN
   .highlight_at = .query_at
  END IF

  IF .highlight_at > 0 AND LEN(.query) > 0 THEN
   'Length of .query that matches the text
   DIM match_len as integer
   FOR i as integer = .highlight_at TO LEN(z)
    IF tolower(z[i - 1]) <> .query[i - .highlight_at] THEN EXIT FOR
    match_len += 1
   NEXT
   'In order to have something visible, highlight first character
   'on a failed match... unless it's part of a markup tag
   IF match_len = 0 ANDALSO LEFT(z, 2) <> "${" THEN match_len = 1

   'FIXME: should add a set of Custom-only UI colours instead of using these
   DIM col as integer
   IF .query_at THEN
    col = uilook(uiHighlight2)
   ELSE
    col = uilook(uiSelectedDisabled)
   END IF

   RETURN MID(z, 1, .highlight_at - 1) _
          & bgcol_text(MID(z, .highlight_at, match_len), col) _
          & MID(z, .highlight_at + match_len)
  END IF
  RETURN z
 END WITH
END FUNCTION


'==========================================================================================
'                               MenuSearch function family
'==========================================================================================


FUNCTION MenuSearcher.text(byval index as integer) as string
 IF this.menu_array THEN
  RETURN this.menu_array[index]
 ELSE
  RETURN v_at(this.menu_vector, index)->text
 END IF
END FUNCTION

FUNCTION MenuSearcher.selectable(byval index as integer) as bool
 IF this.menu_array THEN
  RETURN YES
 ELSE
  RETURN NOT v_at(this.menu_vector, index)->unselectable
 END IF
END FUNCTION

'Possibilities for MenuSearcher.findfunc

FUNCTION MenuSearcher_find_word_boundary(this as MenuSearcher, itemtext as string, query as string) as integer
 RETURN find_on_word_boundary_excluding(LCASE(itemtext), query, this.excludeword)
END FUNCTION

FUNCTION MenuSearcher_find_instr(this as MenuSearcher, itemtext as string, query as string) as integer
 RETURN INSTR(LCASE(itemtext), query)
END FUNCTION

'End possibilities

CONSTRUCTOR MenuSearcher(menu() as string)
 this.menu_array = @menu(0)
END CONSTRUCTOR

CONSTRUCTOR MenuSearcher(byval menu_vector as BasicMenuItem vector)
 this.menu_vector = menu_vector
END CONSTRUCTOR

'Internal generic implementation for select_* functions
SUB select_menuitem(searcher as MenuSearcher, selectst as SelectTypeState, state as MenuState)
 DIM index as integer = state.pt
 IF LEN(selectst.query) = 1 THEN loopvar index, state.first, state.last
 FOR ctr as integer = state.first TO state.last
  selectst.query_at = searcher.findfunc(searcher, searcher.text(index), selectst.query)
  IF selectst.query_at THEN
   'index may be an unselectable menu item. However moving the cursor to a selectable item
   'doesn't act nicely. Ideal solution would be to add and use selectst.highlight_pt, but
   'that's too much work to bother, so just allow selecting unselectable items for now.
   'WHILE NOT searcher.selectable(index)
   ' loopvar index, state.first, state.last
   'WEND
   state.pt = index
   reset_menu_edit_state
   selectst.remember_pt = state.pt
   EXIT FOR
  END IF
  loopvar index, state.first, state.last
 NEXT
END SUB

'Search menu() for a match to the typed query string using find_on_word_boundary_excluding.
'Use in combination with select_by_typing and optionally highlight_menu_typing_selection
SUB select_on_word_boundary_excluding(menu() as string, selectst as SelectTypeState, state as MenuState, excludeword as string)
 DIM searcher as MenuSearcher = MenuSearcher(menu())
 searcher.findfunc = @MenuSearcher_find_word_boundary
 searcher.excludeword = excludeword
 select_menuitem searcher, selectst, state
END SUB

SUB select_on_word_boundary(menu() as string, selectst as SelectTypeState, state as MenuState)
 select_on_word_boundary_excluding menu(), selectst, state, ""
END SUB

'Works with any type derived from BasicMenuItem.
SUB select_on_word_boundary_excluding(byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState, excludeword as string)
 DIM searcher as MenuSearcher = MenuSearcher(menu)
 searcher.findfunc = @MenuSearcher_find_word_boundary
 searcher.excludeword = excludeword
 select_menuitem searcher, selectst, state
END SUB

SUB select_on_word_boundary(byval menu as BasicMenuItem vector, selectst as SelectTypeState, state as MenuState)
 select_on_word_boundary_excluding menu, selectst, state, ""
END SUB

'Search menu() for a match to the typed query string using INSTR.
'Use in combination with select_by_typing and optionally highlight_menu_typing_selection
SUB select_instr(menu() as string, selectst as SelectTypeState, state as MenuState)
 DIM searcher as MenuSearcher = MenuSearcher(menu())
 searcher.findfunc = @MenuSearcher_find_instr
 select_menuitem searcher, selectst, state
END SUB


'==========================================================================================
'                                         MenuDef
'==========================================================================================


FUNCTION MenuDefItem.visible() as bool
 RETURN disabled = NO ORELSE hide_if_disabled = NO ORELSE override_hide = YES
END FUNCTION

CONSTRUCTOR MenuDef()
 dlist_construct itemlist, OFFSETOF(MenuDefItem, trueorder)
END CONSTRUCTOR

DESTRUCTOR MenuDef()
 DeleteMenuItems this
END DESTRUCTOR

SUB ClearMenuData(menu as MenuDef)
 menu.Destructor()
 menu.Constructor()
END SUB

'Initialise a MenuDef so that it looks like a plain menu, as drawn by standardmenu
SUB InitLikeStandardMenu(menu as MenuDef)
 ClearMenuData menu
 WITH menu
  .no_box = YES
  .textalign = alignLeft
  .alignhoriz = alignLeft
  .alignvert = alignTop
  .anchorhoriz = alignLeft
  .anchorvert = alignTop
  .min_chars = 9999  'Fill screen
  .bordersize = -pMenuX  'Draw at 4,4
  .withtags = YES
 END WITH
END SUB

SUB DeleteMenuItems(menu as MenuDef)
 DIM i as integer
 WITH menu
  FOR i = 0 TO .numitems - 1
   dlist_remove menu.itemlist, .items[i]
   DELETE .items[i]
  NEXT i
  DEALLOCATE(.items)
  .items = NULL
 END WITH
END SUB

'recreate a menu's items[] array, which sorts visible items to the top
SUB SortMenuItems(menu as MenuDef)
 DIM as integer i, j, lowest, found
 DIM mi as MenuDefItem ptr
 IF menu.numitems = 0 THEN
  DEALLOCATE(menu.items)
  menu.items = NULL
  EXIT SUB
 END IF
 menu.items = REALLOCATE(menu.items, SIZEOF(any ptr) * menu.numitems)
 'stick all visible items in .items[]
 i = 0
 mi = menu.first
 WHILE mi
  IF mi->visible THEN
   menu.items[i] = mi
   i += 1
  END IF
  mi = mi->trueorder.next
 WEND
 'append all invisible items
 mi = menu.first
 WHILE mi
  IF NOT mi->visible THEN
   menu.items[i] = mi
   i += 1
  END IF
  mi = mi->trueorder.next
 WEND
END SUB

FUNCTION getmenuname(byval record as integer) as string
 DIM as string ret
#IFDEF IS_GAME
 STATIC cache(32) as IntStrPair
 ret = search_string_cache(cache(), record, game_unique_id)
 IF ret <> "" THEN RETURN ret
#ENDIF

 DIM menu_set as MenuSet
 menu_set.menufile = workingdir + SLASH + "menus.bin"
 menu_set.itemfile = workingdir + SLASH + "menuitem.bin"
 DIM menu as MenuDef
 LoadMenuData menu_set, menu, record, YES
 ret = menu.name

#IFDEF IS_GAME
 add_string_cache cache(), record, ret
#ENDIF
 RETURN ret
END FUNCTION

'(Re-)initialise menu state, preserving .pt if valid
SUB init_menu_state (byref state as MenuState, menu() as string, menuopts as MenuOptions)
 WITH state
  IF .size = 0 THEN .autosize = YES
  DIM position_was_known as bool = .position_known
  'Position not known before it's actually drawn, fill with dummy data for now
  calc_menu_rect state, menuopts, .rect.xy
  .position_known = position_was_known

  .first = LBOUND(menu)
  .last = UBOUND(menu)
 END WITH
 ' Bound .pt and update .top
 correct_menu_state state
END SUB

'(Re-)initialise menu state, preserving .pt if valid or otherwise picking a new one.
'Also sorts the menu.
SUB init_menu_state (byref state as MenuState, menu as MenuDef)
 WITH state
  .first = 0
  .last = count_visible_menu_items(menu) - 1
  'Compute .size, assuming vpage
  calc_menustate_size state, menu, vpage
 END WITH
 ' Pick a suitable .pt
 sort_menu_and_select_selectable_item menu, state
 ' Update .top
 correct_menu_state_top state
END SUB

' Make sure .pt is valid, move it to the next selectable menu item if the current one is hidden/unselectable.
' This only works correctly if you haven't already called SortMenuItems!
' Does not update .top (not a substitute for correct_menu_state).
' Note that this is a substitue for what usemenu does, but is specific to MenuDef's
' troublesome shuffling of hidden of menu items to the end.
SUB sort_menu_and_select_selectable_item(menu as MenuDef, state as MenuState)
 WITH menu
  DIM selecteditem as MenuDefItem ptr
  IF state.pt >= 0 AND state.pt < .numitems THEN
   selecteditem = .items[state.pt]
  ELSE
   selecteditem = NULL
  END IF
  SortMenuItems menu
  ' First forwards look for the next visible and selectable item
  WHILE selecteditem ANDALSO (NOT selecteditem->visible OR selecteditem->unselectable)
   selecteditem = selecteditem->trueorder.next
  WEND
  IF selecteditem THEN
   FOR i as integer = 0 TO .numitems - 1
    IF .items[i] = selecteditem THEN
     state.pt = i
     EXIT SUB
    END IF
   NEXT i
  END IF
  ' otherwise pick the last visible and selectable one
  FOR i as integer = .numitems - 1 TO 0 STEP -1
   IF .items[i]->visible AND NOT .items[i]->unselectable THEN
    state.pt = i
    EXIT SUB
   END IF
  NEXT
  ' The menu has no selectable items
  state.pt = -1
 END WITH
END SUB

' Returns index in menu.items[]
FUNCTION append_menu_item(byref menu as MenuDef, caption as zstring ptr, byval t as integer=mtypeLabel, byval sub_t as integer=0, byval dataptr as any ptr=0) as integer
 DIM i as integer
 DIM item as MenuDefItem ptr
 item = NEW MenuDefItem
 WITH *item
  .caption = *caption
  .t = t
  .sub_t = sub_t
  .dataptr = dataptr
 END WITH

 dlist_append(menu.itemlist, item) 'updates .numitems

 'rather than call SortMenuItems, shuffle hidden items down a slot and insert new item
 menu.items = REALLOCATE(menu.items, menu.numitems * SIZEOF(any ptr))
 FOR i = menu.numitems - 2 TO 0 STEP -1  'last item in array is garbage
  IF menu.items[i]->visible = NO THEN
   SWAP menu.items[i], menu.items[i + 1]
  ELSE
   EXIT FOR
  END IF
 NEXT
 menu.items[i + 1] = item

 RETURN menu.numitems - 1
END FUNCTION

DESTRUCTOR MenuDefItem()
 v_free extravec
END DESTRUCTOR

SUB remove_menu_item(byref menu as MenuDef, byval mi as MenuDefItem ptr)
 dlist_remove menu.itemlist, mi
 DELETE mi
 'rebuild menu.items[]
 SortMenuItems menu
END SUB

SUB remove_menu_item(byref menu as MenuDef, byval mislot as integer)
 remove_menu_item menu, menu.items[mislot]
END SUB

SUB swap_menu_items(byref menu1 as MenuDef, byval mislot1 as integer, byref menu2 as MenuDef, byval mislot2 as integer)
 dlist_swap(menu1.itemlist, menu1.items[mislot1], menu2.itemlist, menu2.items[mislot2])
 SortMenuItems menu1
 SortMenuItems menu2
END SUB

PROPERTY MenuDefItem.extra(index as integer) as integer
 RETURN get_extra(extravec, index)
END PROPERTY

PROPERTY MenuDefItem.extra(index as integer, newval as integer)
 set_extra(extravec, index, newval)
END PROPERTY


'==========================================================================================
'                        Saving/Loading/(De)serializing MenuDefs
'==========================================================================================

SUB LoadMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer, byval ignore_items as integer=NO)
 ClearMenuData dat
 IF record > gen(genMaxMenu) OR record < 0 THEN EXIT SUB
 DIM f as integer
 OPENFILE(menu_set.menufile, FOR_BINARY + ACCESS_READ, f)
 SEEK #f, record * getbinsize(binMENUS) + 1
 WITH dat
  .record = record
  .name = ReadByteStr(f, 20)
  .age = 0
  .boxstyle = ReadShort(f)
  .textcolor = ReadShort(f)
  .maxrows = ReadShort(f)
  DIM bits(0) as integer
  bits(0) = ReadShort(f)
  MenuBitsFromArray dat, bits()
  .offset.x = ReadShort(f)
  .offset.y = ReadShort(f)
  .alignhoriz = alignCenter       ' Not saved
  .alignvert = alignCenter        ' ditto
  .anchorhoriz = ReadShort(f) + 1 ' On-disk enum is -1,0,1
  .anchorvert = ReadShort(f) + 1  ' ditto
  .textalign = ReadShort(f) + 1   ' ditto
  .min_chars = ReadShort(f)
  .max_chars = ReadShort(f)
  .bordersize = ReadShort(f)
  .on_close = ReadShort(f)
  .esc_menu = ReadShort(f)
  ReadShort(f)  'garbage INT
  .itemspacing = ReadShort(f)
  .disabled_textcolor = ReadShort(f)
 END WITH
 lazyclose f
 IF ignore_items = NO THEN 'This is disableable for performance when all you care about loading is the menu's name
  LoadMenuItems menu_set, dat, record
 END IF
END SUB

SUB LoadMenuItems(menu_set as MenuSet, menu as MenuDef, byval record as integer)
 DIM i as integer
 DIM f as integer
 DIM member as integer
 DIM actual_record_count as integer = 0
 'The items may appear out-of-order in menuitem.bin, so rather than just append them as
 'we find the, first we store them in this temp array:
 REDIM itemarray(0) as MenuDefItem ptr

 OPENFILE(menu_set.itemfile, FOR_BINARY + ACCESS_READ, f)
 'FIXME: this shouldn't be here, it's covered in upgrade() (but commented out currently)
 actual_record_count = LOF(f) / getbinsize(binMENUITEM)
 IF actual_record_count <> gen(genMaxMenuItem) + 1 THEN
  debug "menuitem.bin record count sanity check failed " & gen(genMaxMenuItem) & "->" & actual_record_count - 1
  gen(genMaxMenuItem) = actual_record_count - 1
 END IF
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = record + 1 THEN
   LoadMenuItem f, itemarray(), i
  END IF
 NEXT i
 lazyclose f

 'build the item list
 FOR i = 0 TO UBOUND(itemarray)
  IF itemarray(i) <> NULL THEN
   dlist_append(menu.itemlist, itemarray(i))
  ELSE
   'can't create a zero length FB array
   IF UBOUND(itemarray) <> 0 THEN
    debug "menu " & record & " item " & i & " could not be found in " & menu_set.itemfile
   END IF
  END IF
 NEXT
 'build the items[] array
 SortMenuItems menu
END SUB

SUB LoadMenuItem(byval f as integer, items() as MenuDefItem ptr, byval record as integer)
 DIM i as integer
 DIM bits(0) as integer
 DIM mi as MenuDefItem ptr
 DIM itemnum as integer
 mi = NEW MenuDefItem
 SEEK #f, record * getbinsize(binMENUITEM) + 1
 WITH *mi
  ReadShort(f) 'throw away member
  .caption = ReadByteStr(f, 38)
  itemnum = ReadShort(f)
  .t = ReadShort(f)
  .sub_t = ReadShort(f)
  .tag1 = ReadShort(f)
  .tag2 = ReadShort(f)
  .settag = ReadShort(f)
  .togtag = ReadShort(f)
  bits(0) = ReadShort(f)
  FOR i = 0 TO 2
   'Don't initialize the extra data vector unless needed
   DIM temp as integer = ReadShort(f)
   IF temp THEN .extra(i) = temp
  NEXT i
  .col = ReadShort(f)
  .disabled_col = ReadShort(f)
 END WITH
 IF itemnum > UBOUND(items) THEN REDIM PRESERVE items(itemnum)
 items(itemnum) = mi
 MenuItemBitsFromArray *mi, bits()
END SUB

SUB SaveMenuData(menu_set as MenuSet, dat as MenuDef, byval record as integer)
 DIM f as integer
 DIM bits(0) as integer
 OPENFILE(menu_set.menufile, FOR_BINARY, f)
 SEEK #f, record * getbinsize(binMENUS) + 1
 WITH dat
  WriteByteStr(f, 20, .name)
  WriteShort(f, -1, .boxstyle)
  WriteShort(f, -1, .textcolor)
  WriteShort(f, -1, .maxrows)
  MenuBitsToArray dat, bits()
  WriteShort(f, -1, bits(0))
  WriteShort(f, -1, .offset.x)
  WriteShort(f, -1, .offset.y)
  WriteShort(f, -1, .anchorhoriz - 1) ' On-disk enum is -1,0,1
  WriteShort(f, -1, .anchorvert - 1)  ' ditto  
  WriteShort(f, -1, .textalign - 1)   ' ditto
  WriteShort(f, -1, .min_chars)
  WriteShort(f, -1, .max_chars)
  WriteShort(f, -1, .bordersize)
  WriteShort(f, -1, .on_close)
  WriteShort(f, -1, .esc_menu)
  WriteShort(f, -1, 0)  'wasted garbage INT
  WriteShort(f, -1, .itemspacing)
  WriteShort(f, -1, .disabled_textcolor)
 END WITH
 CLOSE #f
 SaveMenuItems menu_set, dat, record
END SUB

SUB SaveMenuItems(menu_set as MenuSet, menu as MenuDef, byval record as integer)
 DIM i as integer
 DIM f as integer
 DIM member as integer
 DIM elem as integer = 0
 DIM mi as MenuDefItem ptr
 DIM blankmi as MenuDefItem
 
 OPENFILE(menu_set.itemfile, FOR_BINARY, f)
 'Loop through each record and orphan all old entries for this menu
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = record + 1 THEN
   SaveMenuItem f, blankmi, i, -1, 0
  END IF
 NEXT i
 'Loop through each record, writing new values into orphan slots
 mi = menu.first
 FOR i = 0 TO gen(genMaxMenuItem)
  SEEK #f, i * getbinsize(binMENUITEM) + 1
  member = ReadShort(f)
  IF member = 0 THEN
   IF mi = NULL THEN EXIT FOR
   SaveMenuItem f, *mi, i, record, elem
   elem = elem + 1
   mi = mi->trueorder.next
  END IF
 NEXT i
 DO WHILE mi
  'More items need to be written, append them
  gen(genMaxMenuItem) += 1
  SaveMenuItem f, *mi, gen(genMaxMenuItem), record, elem
  elem += 1
  mi = mi->trueorder.next
 LOOP
 CLOSE #f
END SUB

SUB SaveMenuItem(byval f as integer, mi as MenuDefItem, byval record as integer, byval menunum as integer, byval itemnum as integer)
 DIM i as integer
 DIM bits(0) as integer
 SEEK #f, record * getbinsize(binMENUITEM) + 1
 WITH mi
  WriteShort(f, -1, menunum + 1)
  WriteByteStr(f, 38, .caption)
  WriteShort(f, -1, itemnum)
  WriteShort(f, -1, .t)
  WriteShort(f, -1, .sub_t)
  WriteShort(f, -1, .tag1)
  WriteShort(f, -1, .tag2)
  WriteShort(f, -1, .settag)
  WriteShort(f, -1, .togtag)
  MenuItemBitsToArray mi, bits()
  WriteShort(f, -1, bits(0))
  FOR i = 0 TO 2
   WriteShort(f, -1, .extra(i))
  NEXT i
  WriteShort(f, -1, .col)
  WriteShort(f, -1, .disabled_col)
 END WITH
END SUB

SUB MenuBitsToArray (menu as MenuDef, bits() as integer)
 bits(0) = 0
 WITH menu
  setbit bits(), 0, 0, .translucent
  setbit bits(), 0, 1, .no_scrollbar
  setbit bits(), 0, 2, .allow_gameplay
  setbit bits(), 0, 3, .suspend_player
  setbit bits(), 0, 4, .no_box
  setbit bits(), 0, 5, .no_close
  setbit bits(), 0, 6, .no_controls
  setbit bits(), 0, 7, .prevent_main_menu
  setbit bits(), 0, 8, .advance_textbox
  setbit bits(), 0, 9, .highlight_selection
  setbit bits(), 0, 10, .remember_selection
  setbit bits(), 0, 11, .clamp_to_screen
 END WITH
END SUB

SUB MenuBitsFromArray (menu as MenuDef, bits() as integer)
 WITH menu
  .translucent    = xreadbit(bits(), 0)
  .no_scrollbar   = xreadbit(bits(), 1)
  .allow_gameplay = xreadbit(bits(), 2)
  .suspend_player = xreadbit(bits(), 3)
  .no_box         = xreadbit(bits(), 4)
  .no_close       = xreadbit(bits(), 5)
  .no_controls    = xreadbit(bits(), 6)
  .prevent_main_menu = xreadbit(bits(), 7)
  .advance_textbox   = xreadbit(bits(), 8)
  .highlight_selection = xreadbit(bits(), 9)
  .remember_selection = xreadbit(bits(), 10)
  .clamp_to_screen = xreadbit(bits(), 11)
 END WITH
END SUB

SUB MenuItemBitsToArray (mi as MenuDefItem, bits() as integer)
 bits(0) = 0
 WITH mi
  setbit bits(), 0, 0, .hide_if_disabled
  setbit bits(), 0, 1, .close_when_activated
  setbit bits(), 0, 2, .skip_close_script
 END WITH
END SUB

SUB MenuItemBitsFromArray (mi as MenuDefItem, bits() as integer)
 WITH mi
  .hide_if_disabled  = xreadbit(bits(), 0)
  .close_when_activated = xreadbit(bits(), 1)
  .skip_close_script = xreadbit(bits(), 2)
 END WITH
END SUB

FUNCTION read_menu_int (menu as MenuDef, byval intoffset_plus1 as integer) as integer
 '--This function allows read access to integers in a menu for the plotscripting interface
 '--intoffset_plus1 is the integer offset as appears in the MENUS.BIN lump documentation plus one
 DIM bits(0) as integer
 WITH menu
  SELECT CASE intoffset_plus1
   CASE 12: RETURN .boxstyle
   CASE 13: RETURN .textcolor
   CASE 14: RETURN .maxrows
   CASE 15:
    MenuBitsToArray menu, bits()
    RETURN bits(0)
   CASE 16: RETURN .offset.x
   CASE 17: RETURN .offset.y
   CASE 18: RETURN .anchorhoriz - 1 ' Translate to align: constants
   CASE 19: RETURN .anchorvert - 1  ' ditto
   CASE 20: RETURN .textalign - 1   ' ditto
   CASE 21: RETURN .min_chars
   CASE 22: RETURN .max_chars
   CASE 23: RETURN .bordersize
   CASE 24: RETURN .on_close
   CASE 25: RETURN .esc_menu
   '26 is garbage
   CASE 27: RETURN .itemspacing
   CASE 28: RETURN .disabled_textcolor
   CASE ELSE
    reporterr "read_menu_int: " & intoffset_plus1 & " is an invalid integer offset"
  END SELECT
 END WITH
 RETURN 0
END FUNCTION

SUB write_menu_int (menu as MenuDef, byval intoffset_plus1 as integer, byval n as integer)
 '--This sub allows write access to integers in a menu for the plotscripting interface
 '--FIXME: there's no error checking, not even in the wrapper scripts in plotscr.hsd!
 '--intoffset_plus1 is the integer offset as appears in the MENUS.BIN lump documentation plus one
 DIM bits(0) as integer
 WITH menu
  SELECT CASE intoffset_plus1
   CASE 12: .boxstyle = n
   CASE 13: .textcolor = n
   CASE 14: .maxrows = n
   CASE 15:
    bits(0) = n
    MenuBitsFromArray menu, bits()
   CASE 16: .offset.x = n
   CASE 17: .offset.y = n
   CASE 18: .anchorhoriz = n + 1 ' Translate from align: constants
   CASE 19: .anchorvert = n + 1  ' ditto
   CASE 20: .textalign = n + 1   ' ditto
   CASE 21: .min_chars = n
   CASE 22: .max_chars = n
   CASE 23: .bordersize = n
   CASE 24: .on_close = n
   CASE 25: .esc_menu = n
   '26 is garbage
   CASE 27: .itemspacing = n
   CASE 28: .disabled_textcolor = n
   CASE ELSE
    reporterr "write_menu_int: " & intoffset_plus1 & " is an invalid integer offset"
  END SELECT
 END WITH
END SUB

FUNCTION read_menu_item_int (mi as MenuDefItem, byval intoffset as integer) as integer
 '--This function allows read access to integers in a menu item for the plotscripting interface
 '--intoffset is the integer offset, same as appears in the MENUITEM.BIN lump documentation
 DIM bits(0) as integer
 WITH mi
  SELECT CASE intoffset
   CASE 22: RETURN .t
   CASE 23: RETURN .sub_t
   CASE 24: RETURN .tag1
   CASE 25: RETURN .tag2
   CASE 26: RETURN .settag
   CASE 27: RETURN .togtag
   CASE 28:
    MenuItemBitsToArray mi, bits()
    RETURN bits(0)
   CASE 29 TO 31: RETURN .extra(intoffset - 29)
   CASE 32: RETURN .col
   CASE 33: RETURN .disabled_col
   CASE ELSE
    reporterr "read_menu_item_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
 RETURN 0
END FUNCTION

SUB write_menu_item_int (mi as MenuDefItem, byval intoffset as integer, byval n as integer)
 '--This sub allows write access to integers in a menu item for the plotscripting interface
 '--intoffset is the integer offset, same as appears in the MENUITEM.BIN lump documentation
 DIM bits(0) as integer
 WITH mi
  SELECT CASE intoffset
   CASE 22: .t = n
   CASE 23: .sub_t = n
   CASE 24: .tag1 = n
   CASE 25: .tag2 = n
   CASE 26: .settag = n
   CASE 27: .togtag = n
   CASE 28:
    bits(0) = n
    MenuItemBitsFromArray mi, bits()
   CASE 29 TO 31: .extra(intoffset - 29) = n
   CASE 32: .col = n
   CASE 33: .disabled_col = n
   CASE ELSE
    reporterr "write_menu_item_int: " & intoffset & " is an invalid integer offset"
  END SELECT
 END WITH
END SUB


'==========================================================================================
'                                    Drawing MenuDefs
'==========================================================================================

'Update the caption of each menu item
'Needs to be called before calc_menu_rect
SUB update_menu_captions (menu as MenuDef)
 FOR i as integer = 0 TO menu.numitems - 1
  menu.items[i]->text = get_menu_item_caption(*menu.items[i], menu)
 NEXT
END SUB

SUB draw_menu (menu as MenuDef, state as MenuState, byval page as integer)
 DIM i as integer
 DIM elem as integer
 DIM where as XYPair
 
 menu.age += 1

 update_menu_captions menu
 calc_menu_rect state, menu, page

 DIM bord as integer = 8 + menu.bordersize

 IF menu.no_box = NO THEN
  edgeboxstyle menu.rect, menu.boxstyle, page, menu.translucent, menu.suppress_borders
 END IF

 state.tog = state.tog XOR 1

 'First draw the highlight rectangle, if any, behind the items
 IF menu.highlight_selection THEN
  i = state.pt - state.top
  IF i >= 0 AND i <= state.size THEN
   where = menu.rect.topleft + XY(4, bord + i * state.spacing - menu.itemspacing \ 2)
   rectangle where.x, where.y, menu.rect.wide - 8, state.spacing, uiLook(uiHighlight), page
  END IF
 END IF

 IF menu.no_scrollbar = NO THEN
  draw_scrollbar state, menu, page
 END IF

 'Draw the items
 FOR i = 0 TO state.size
  elem = state.top + i
  IF elem >= 0 AND elem < menu.numitems THEN
   WITH *menu.items[elem]
    DIM col as integer
    col = menu_item_color(state, elem, .disabled, .unselectable, .col, .disabled_col, menu.textcolor, menu.disabled_textcolor)

    IF .visible THEN
     position_menu_item menu, .text, i, where

     IF .t = mtypeSpecial THEN
      ' Check for menu items with bars behind. The bar is drawn using the menu's boxstyle and Line border
      DIM bar_width as integer = 0
      DIM metermax as integer
      metermax = small(state.rect.wide, 80)  'large(48, textwidth(.text))
      IF .sub_t = spMusicVolume OR .sub_t = spVolumeMenu THEN
       bar_width = get_music_volume() * metermax
      ELSEIF .sub_t = spSoundVolume THEN
       bar_width = get_global_sfx_volume() * metermax
      ELSEIF .sub_t = spMargins THEN ' TV Safe Margin meter
       bar_width = get_safe_zone_margin() * metermax \ 10
      END IF
      IF bar_width THEN
       edgeboxstyle menu.rect.x + (menu.rect.wide - metermax) \ 2, where.y, bar_width, 10, menu.boxstyle, page, NO, YES
      END IF
     END IF

     edgeprint .text, where.x, where.y, col, page, menu.withtags
    END IF
   END WITH
  END IF
 NEXT i
 
END SUB

' Calculate top-left corner of the text, placed in 'where'
SUB position_menu_item (menu as MenuDef, cap as string, byval i as integer, byref where as XYPair)
 'Adding bord to menu.rect like this should equal state.rect. TODO: use state.rect instead?
 DIM bord as integer
 bord = 8 + menu.bordersize
 WITH menu.rect
  SELECT CASE menu.textalign
   CASE alignLeft
    where.x = .x + bord
   CASE alignCenter
    where.x = .x + (.wide - textwidth(cap)) / 2
   CASE alignRight
    where.x = .x + .wide - bord - textwidth(cap)
  END SELECT
  where.y = .y + bord + (i * (10 + menu.itemspacing))
 END WITH
END SUB

' Calculate state.size of a MenuDef menu from menu.maxrows
' .maxrows=0 is the MenuDef equivalent of state.autosize (which isn't used for MenuDef)
SUB calc_menustate_size (byref state as MenuState, menu as MenuDef, page as integer)
 WITH state
  .spacing = 10 + menu.itemspacing
  IF menu.maxrows <= 0 THEN

   ' Calculate available vertical space
   DIM vertspace as integer
   IF menu.clamp_to_screen THEN
    ' Doesn't matter how the menu is aligned
    vertspace = vpages(page)->h
   ELSE
    ' The anchor point on the screen. anchory is how much space is on the screen
    ' above the anchor point, vpages(page)->h - anchory is the space below.
    DIM anchory as integer = anchor_point(menu.alignvert, vpages(page)->h) + menu.offset.y

    SELECT CASE menu.anchorvert  'Anchor on the menu rect
     CASE alignTop:     vertspace = vpages(page)->h - anchory
     CASE alignBottom:  vertspace = anchory
     CASE alignCenter:  vertspace = 2 * small(anchory, vpages(page)->h - anchory)
    END SELECT
   END IF

   DIM bord as integer = 8 + menu.bordersize
   .size = large(1, (vertspace - 2 * bord + menu.itemspacing) \ .spacing) - 1
  ELSE
   .size = menu.maxrows - 1
  END IF

  .size = small(.size, .last)
 END WITH
END SUB

' Calculate menu.rect and state.rect (which includes the border padding) and also state.size
SUB calc_menu_rect (state as MenuState, menu as MenuDef, byval page as integer)
 DIM i as integer
 DIM bord as integer
 bord = 8 + menu.bordersize

 'Compute total width & height of all the items and borders
 menu.rect.wide = bord * 2
 menu.rect.high = bord * 2
 FOR i = 0 TO menu.numitems - 1
  WITH *menu.items[i]
   'hidden items used to matter for auto-width but not auto-height; now they don't for either
   IF .visible = NO THEN CONTINUE FOR
   menu.rect.wide = large(menu.rect.wide, textwidth(.text) + bord * 2)
   menu.rect.high += 10
   IF i <> 0 THEN menu.rect.high += menu.itemspacing
  END WITH
 NEXT i

 'Enforce min width
 menu.rect.wide = large(menu.rect.wide, menu.min_chars * 8 + bord * 2)
 'Limit to screen size (this isn't strictly needed, and maxrows=0 also does the same)
 'menu.rect.wide = small(menu.rect.wide, vpages(page)->w)
 menu.rect.high = small(menu.rect.high, vpages(page)->h)

 'Set state.size and state.spacing
 calc_menustate_size state, menu, page

 menu.rect.high = small(menu.rect.high, (state.size + 1) * state.spacing - menu.itemspacing + bord * 2)

 WITH menu
  .rect.x = anchor_point(.alignhoriz, vpages(page)->w) - anchor_point(.anchorhoriz, .rect.wide) + .offset.x
  .rect.y = anchor_point(.alignvert, vpages(page)->h) - anchor_point(.anchorvert, .rect.high) + .offset.y

  IF .clamp_to_screen THEN
   'Clamping shouldn't happen when .maxrows=0
   'Keep the menu 1 pixel away from the screen edge, looks better.
   'Not really worth making this customisable.
   DIM padding as XYPair = XY(1, 1)
   'MenuDef doesn't support RelPos, but we can reuse this function
   .rect.xy = relative_pos(.rect.xy + XY(showLeft, showTop) - padding, vpages(page)->size, .rect.wh + padding * 2) + padding
  END IF
 END WITH

 WITH state
  .position_known = YES
  .rect.x = menu.rect.x + bord
  .rect.y = menu.rect.y + bord
  .rect.wide = menu.rect.wide - bord * 2
  .rect.high = menu.rect.high - bord * 2
 END WITH
END SUB

FUNCTION anchor_point(byval anchor as AlignType, byval size as integer) as integer
 SELECT CASE anchor
  CASE alignLeft
   RETURN 0
  CASE alignMiddle
   RETURN size \ 2
  CASE alignRight
   RETURN size
 END SELECT
END FUNCTION

'Number visible items -- menu.numitems is total number.
FUNCTION count_visible_menu_items (menu as MenuDef) as integer
 DIM i as integer
 DIM count as integer = 0
 FOR i = 0 TO menu.numitems - 1
  WITH *menu.items[i]
   IF .visible = NO THEN CONTINUE FOR
   count += 1
  END WITH
 NEXT i
 RETURN count
END FUNCTION

FUNCTION get_menu_item_caption (mi as MenuDefItem, menu as MenuDef) as string
 DIM cap as string
 cap = mi.caption
 IF LEN(cap) = 0 THEN
  'No caption, use the default
  SELECT CASE mi.t
   CASE mtypeSpecial
    cap = get_special_menu_caption(mi.sub_t)
   CASE mtypeMenu
    cap = getmenuname(mi.sub_t)
    IF cap = "" THEN cap = "Menu " & mi.sub_t
   CASE mtypeTextBox
    cap = "Text Box " & mi.sub_t
   CASE mtypeScript
    cap = scriptname(mi.sub_t)
  END SELECT
 END IF
 IF menu.edit_mode = YES THEN
  IF LEN(TRIM(cap)) = 0 THEN cap = "[BLANK]"
  IF mi.disabled ANDALSO mi.hide_if_disabled THEN cap &= " [hidden]"
  cap &= get_menu_item_editing_annotation(mi)
 END IF
 #IFDEF IS_GAME
  embedtext cap
 #ENDIF
 IF menu.max_chars > 0 THEN ' Crop overlength
  'TODO: we should replace max_chars with a pixel width, but in the meantime, special-case for withtags
  IF menu.withtags THEN
   IF menu.textalign = alignRight THEN
    cap = text_right(cap, menu.max_chars * 8, NO, NO)  'ellipsis=NO, withtags=NO
   ELSE ' left and center align
    cap = text_left(cap, menu.max_chars * 8, NO, NO)  'ellipsis=NO, withtags=NO
   END IF
  ELSE
   IF menu.textalign = alignRight THEN
    cap = RIGHT(cap, menu.max_chars)
   ELSE ' left and center align
    cap = LEFT(cap, menu.max_chars)
   END IF
  END IF
 END IF
 RETURN cap
END FUNCTION

FUNCTION get_special_menu_caption(byval subtype as integer) as string
 DIM cap as string
 SELECT CASE subtype
  CASE spItems           : cap = readglobalstring(60, "Items", 10)
  CASE spSpells          : cap = readglobalstring(61, "Spells", 10)
  CASE spStatus          : cap = readglobalstring(62, "Status", 10)
  CASE spEquip           : cap = readglobalstring(63, "Equip", 10)
  CASE spOrder           : cap = readglobalstring(64, "Order", 10)
  CASE spTeam            : cap = readglobalstring(65, "Team", 10)
  CASE spTeamOrOrder
   IF prefbit(5) THEN  '"Hero Swapping Always Available"
    cap = readglobalstring(65, "Team", 10)
   ELSE
    cap = readglobalstring(64, "Order", 10)
   END IF
  CASE spMap,spMapMaybe  : cap = readglobalstring(68, "Map", 10)
  CASE spSave,spSaveMaybe: cap = readglobalstring(66, "Save", 10)
  CASE spLoad            : cap = readglobalstring(322, "Load", 20)
  CASE spQuit            : cap = readglobalstring(67, "Quit", 10)
  CASE spVolumeMenu      : cap = readglobalstring(69, "Volume", 10)
  CASE spMusicVolume     : cap = readglobalstring(318, "Music", 20)
  CASE spSoundVolume     : cap = readglobalstring(320, "Sound", 20)
  CASE spMargins         : cap = readglobalstring(308, "Margins", 10)
  CASE spPurchases       : cap = readglobalstring(313, "Purchases", 10)
  CASE spWindowed        : cap = readglobalstring(314, "Windowed", 20)
  CASE spFullscreen      : cap = readglobalstring(316, "Fullscreen", 20)
 END SELECT
 RETURN cap
END FUNCTION

' Return the suffix that is appended to a menu item while in edit mode
FUNCTION get_menu_item_editing_annotation (mi as MenuDefItem) as string
 SELECT CASE mi.t
  CASE 1 ' special screen
   SELECT CASE mi.sub_t
    CASE spTeamOrOrder
     RETURN " [general bitset]"
    CASE spMapMaybe
     RETURN " [if allowed by map]"
    CASE spSaveMaybe
     RETURN " [if allowed by map]"
    CASE spMargins
     RETURN " [if available]"
    CASE spPurchases
     RETURN " [if available]"
    CASE spWindowed
     RETURN " [if fullscreen]"
    CASE spFullscreen
     RETURN " [if windowed]"
    CASE spVolumeMenu
     RETURN " [menu]"
   END SELECT
 END SELECT
 RETURN ""
END FUNCTION

'Whether, according to the in-game meaning of the type and subtype,
'this menu item can be activated (possibly setting tags and closing the menu)
FUNCTION menu_item_is_activatable(mi as MenuDefItem) as bool
 IF mi.t = mtypeLabel ANDALSO (mi.sub_t = lbDisabled OR mi.sub_t = lbUnselectable) THEN
  RETURN NO
 ELSEIF mi.t = mtypeSpecial ANDALSO (mi.sub_t = spMusicVolume OR mi.sub_t = spSoundVolume OR mi.sub_t = spMargins) THEN
  'These menu items have bars, and it doesn't make sense to activate them
  RETURN NO
 ELSE
  RETURN YES
 END IF
END FUNCTION


'==========================================================================================
'                                       Scrollbars!
'==========================================================================================

'Whether this menu will be drawn with a scrollbar (because it's larger than
'its .size), if not explicitly disabled (by MenuDef/MenuOptions.no_scrollbar)
FUNCTION MenuState.would_have_scrollbar() as bool
 DIM count as integer = last - first + 1
 'recall size is off-by-1
 RETURN (top > first OR count > (size + 1)) ANDALSO count > 0
END FUNCTION

SUB draw_scrollbar(state as MenuState, menu as MenuDef, page as integer, align as AlignType = alignRight)
 draw_scrollbar state, menu.rect, menu.boxstyle, page, align
END SUB

'Hint: usually you would pass state.rect as rect
'count being the number of (visible) menu items
'align is which side to put the slider on
SUB draw_scrollbar(state as MenuState, rect as RectType, boxstyle as integer=0, page as integer, align as AlignType = alignRight)
 DIM count as integer = state.last - state.first + 1
 'recall state.size is off-by-1
 IF state.would_have_scrollbar() THEN
  IF count > 0 THEN
   DIM sbar as RectType
   DIM slider as RectType
   ' 2px padding on each side, 4px wide slider
   DIM pad as integer = 2
   sbar.wide = 4
   sbar.high = rect.high - pad * 2
   sbar.x = rect.x + pad + anchor_point(align, rect.wide - pad * 2 - sbar.wide)
   sbar.y = rect.y + pad
   WITH sbar
    slider.y = .high / count * (state.top - state.first)
    slider.high = large(1, .high / count * (state.size + 1))
    rectangle .x, .y, .wide, .high, uilook(uiBackground), page
    rectangle .x, .y + slider.y, .wide, slider.high, boxlook(boxstyle).edgecol, page
   END WITH
  END IF
 END IF
END SUB

SUB draw_fullscreen_scrollbar(state as MenuState, boxstyle as integer=0, page as integer, align as AlignType = alignRight)
 DIM rect as RectType
 rect.wide = vpages(page)->w
 rect.high = vpages(page)->h
 draw_scrollbar state, rect, boxstyle, page, align
END SUB


'==========================================================================================
'                                   Generic menu system
'==========================================================================================


' The boilerplate for displaying a MenuDef menu, if nothing else has to be drawn to the screen.
SUB run_MenuDef(menu as MenuDef, each_tick as FnMenuLogic, dataptr as any ptr = NULL)
 DIM holdscreen as integer = allocatepage
 copypage vpage, holdscreen
 DIM state as MenuState
 init_menu_state state, menu
 DO
  setwait 55
  setkeys YES
  usemenu state
  IF keyval(ccCancel) > 1 THEN EXIT DO
  IF each_tick(menu, state, dataptr) THEN EXIT DO
  copypage holdscreen, vpage
  draw_menu menu, state, vpage
  setvispage vpage
  dowait
 LOOP
 setkeys
 freepage holdscreen
END SUB

SUB ModularMenu.add_item(itemtype as integer = 0, id as integer = -1, text as string = "", canselect as bool = YES, heading as bool = NO, disabled as bool = NO)
 a_append itemtypes(), itemtype
 a_append itemids(), id
 IF heading THEN
  a_append menu(), fgtag(uilook(eduiHeading)) & text
 ELSE
  a_append menu(), text
 END IF
 a_append selectable(), canselect
 IF canselect = NO THEN use_selectable = YES
 a_append shaded(), disabled
END SUB

SUB ModularMenu.add_spacer()
 add_item , , , NO, YES, NO
END SUB

SUB ModularMenu.header(text as string)
 add_spacer
 add_item , , text, NO, YES, NO
END SUB

SUB ModularMenu.clear_menu()
 ERASE menu
 ERASE selectable
 ERASE shaded
 ERASE itemtypes
 ERASE itemids
 state.last = -1
END SUB

SUB ModularMenu.update()
END SUB

FUNCTION ModularMenu.each_tick() as bool
 RETURN NO
END FUNCTION

FUNCTION ModularMenu.try_exit() as bool
 RETURN YES
END FUNCTION

SUB ModularMenu.draw_underlays()
END SUB

SUB ModularMenu.draw_overlays()
END SUB

SUB ModularMenu.draw()
 draw_underlays()

 DIM titlesize as XYPair
 DIM where as XYPair = (pMenuX, pMenuY)

 IF floating THEN
  'state.rect wouldn't be calculated until standardmenu is called, so need
  'to pre-calculate to prevent flicker....
  'TODO: In fact, this is a pretty ugly way to draw a floating menu.
  'So this should probably be replaced with MenuDef draw_menu
  DIM basicmenu as BasicMenuItem vector
  standard_to_basic_menu menu(), state, basicmenu
  where = XY(pCentered, pCentered)
  IF LEN(title) THEN
   titlesize = textsize(title, rWidth - 20, fontEdged)
   where.y += 8 + titlesize.h \ 2
   state.autosize_ignore_pixels = 14 + titlesize.h
  END IF
  calc_menu_rect state, menuopts, where, vpage, basicmenu
  v_free basicmenu
  edgeboxstyle where.x, where.y, state.rect.wide + 10, state.rect.high + 10, 1, vpage
 END IF

 IF LEN(title) THEN
  IF floating THEN
   DIM titley as integer = where.y - state.rect.high \ 2 - titlesize.h - 8
   centerbox rCenter, titley + (titlesize.h + 6) \ 2, titlesize.w + 12, titlesize.h + 6, 1, vpage
   wrapprint title, pCentered, titley, uilook(uiText), vpage, rWidth - 20
   'where.y += titlesize.h + 2
  ELSE
   wrapprint title, where.x, where.y, uilook(uiText), vpage, rWidth - where.x - 4
   where.y += textsize(title, rWidth - where.x).h + 4
  END IF
 END IF

 IF UBOUND(menu) >= 0 THEN
  DIM menu_display(UBOUND(menu)) as string
  highlight_menu_typing_selection menu(), menu_display(), selectst, state
  standardmenu menu_display(), state, shaded(), where.x, where.y, vpage, menuopts
 END IF

 IF LEN(tooltip) THEN
  wrapprintbg tooltip, pInfoX, pInfoY, uilook(uiText), vpage
 END IF

 draw_overlays()
END SUB

'Additional logic around update()
SUB ModularMenu.update_wrapper()
 clear_menu()
 update()
 init_menu_state state, menu(), menuopts  'Updates .size, .last, .pt., .hover, .top
 'Updating shaded() is optional
 REDIM PRESERVE shaded(UBOUND(menu))
 IF use_selectable THEN
  'Move state.pt to a selectable menu item (yuck!)
  '(This is also normally done by init_menu_state, but we can't call that)
  WHILE selectable(state.pt) = NO
   IF state.pt <= state.first THEN EXIT WHILE
   state.pt -= 1
  WEND
  correct_menu_state_top state
 END IF
 mouse_update_hover state  'Not actually needed; hover won't be incorrect unless the menu grew
 'correct_menu_state state  'Also calls mouse_update_hover
END SUB

SUB ModularMenu.run()
 running = YES
 IF floating THEN
  holdscreen = allocatepage
  copypage vpage, holdscreen

  menuopts.wide = 80
  menuopts.calc_size = YES
 END IF
 state.autosize = YES
 state.autosize_ignore_lines = 1  'For the tooltip
 'If floating, the title gets cut off when the menu is small
 IF floating = NO ANDALSO LEN(title) THEN state.autosize_ignore_lines += 2

 update_wrapper()
 IF floating THEN draw()   'To calculate state.rect

 DO
  setwait 55
  setkeys YES
  IF use_selectable THEN
   usemenu_ret = usemenu(state, selectable())
  ELSE
   usemenu_ret = usemenu(state)
  END IF

  can_use_strgrabber = (LEN(selectst.query) = 0)
  using_strgrabber = NO

  'Call each_tick before checking cancel and help keys, so it can override them if it wants
  IF each_tick() THEN EXIT DO

  IF keyval(ccCancel) > 1 ANDALSO try_exit() THEN EXIT DO
  IF LEN(helpkey) ANDALSO keyval(scF1) > 1 ANDALSO (keyval(scCtrl) OR keyval(scShift)) = 0 THEN
   show_help helpkey
  END IF
  IF state.need_update THEN
   state.need_update = NO
   update_wrapper()
  END IF

  IF using_strgrabber = NO ANDALSO select_by_typing(selectst, NO) THEN
   select_on_word_boundary menu(), selectst, state
  END IF

  IF floating THEN
   copypage holdscreen, vpage
  ELSE
   clearpage vpage
  END IF
  draw()
  setvispage vpage
  dowait
 LOOP
 setkeys
 IF holdscreen THEN
  copypage holdscreen, vpage   'Just in case something else also does holdscreen
  freepage holdscreen
 END IF
 clear_menu()
 running = NO
END SUB
