'OHRRPGCE - bmodsubs.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from bmodsubs.bas

#IFNDEF BMODSUBS_BI
#DEFINE BMODSUBS_BI

#INCLUDE "udts.bi"

declare function is_hero(who)
declare function is_enemy(who)
declare function is_attack(who)
declare function is_weapon(who)
declare sub advance (who, atk(), bslot() as battlesprite, t())
declare function atkallowed (atkbuf(), attacker, spclass, lmplev, bstat() AS BattleStats)
declare function checktheftchance (item, itemp, rareitem, rareitemp)
declare sub control
declare function countai (ai, them, es())
declare function enemycount (bslot() as battlesprite, bstat() AS BattleStats)
declare function targenemycount (bslot() AS BattleSprite, bstat() AS BattleStats)
declare sub etwitch (who, atk(), bslot() as battlesprite, t())
declare function getweaponpos(w,f,isy)'or x?
declare function getheropos(h,f,isy)'or x?
declare sub heroanim (who, atk(), bslot() as battlesprite, t())
declare function inflict (w, t, bstat() AS BattleStats, bslot() as battlesprite, harm$(), hc(), hx(), hy(), atk(), tcount, bits(), revenge(), revengemask(), targmem(), revengeharm(), repeatharm())
declare function liveherocount (bstat() AS BattleStats)
declare sub loadfoe (i, formdata(), es(), bslot() as battlesprite, p(), ext$(), bits(), bstat() AS BattleStats, ebits(), batname$())
declare function randomally (who)
declare function randomfoe (who)
declare sub retreat (who, atk(), bslot() as battlesprite, t())
declare function safesubtract (number, minus)
declare function safemultiply (number, by!)
declare sub setbatcap (cap$, captime, capdelay)
declare sub smartarrowmask (inrange(), pt, d, axis, bslot() as battlesprite, tmask())
declare sub smartarrows (pt, d, axis, bslot() as battlesprite, targ(), tmask(), spred)
declare function targetable (attacker, target, ebits(), bslot() as battlesprite)
declare function targetmaskcount (tmask())
declare sub traceshow (s$)
declare function trytheft (who, targ, atk(), es())
declare function exptolevel& (level)
declare sub updatestatslevelup (i, exstat(), bstat() AS BattleStats, allowforget)
declare sub giveheroexperience (i, exstat(), exper&)
declare function visibleandalive (o, bstat() AS BattleStats, bslot() as battlesprite)
declare sub writestats (exstat(), bstat() AS BattleStats)

declare sub get_valid_targs(tmask(), who, atkbuf(), bslot() AS BattleSprite, bstat() AS BattleStats, revenge(), revengemask(), targmem())
declare function attack_can_hit_dead(who, atkbuf())
declare sub autotarget (confirmtarg(), tmask(), who, atkbuf())
declare function find_preferred_target(tmask(), who, atkbuf(), bslot() AS BattleSprite, bstat() AS BattleStats)

#ENDIF
