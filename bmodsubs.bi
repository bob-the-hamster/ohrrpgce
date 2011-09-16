'OHRRPGCE - bmodsubs.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from bmodsubs.bas

#IFNDEF BMODSUBS_BI
#DEFINE BMODSUBS_BI

#INCLUDE "udts.bi"
#INCLUDE "battle_udts.bi"

declare function is_hero(who as integer) as integer
declare function is_enemy(who as integer) as integer
declare function is_attack(who as integer) as integer
declare function is_weapon(who as integer) as integer
declare sub anim_advance (who as integer, attack as AttackData, bslot() as battlesprite, t() as integer)
declare function atkallowed (atk as AttackData, attacker as integer, spclass as integer, lmplev as integer, bslot() as BattleSprite) as integer
declare function checktheftchance (item as integer, itemp as integer, rareitem as integer, rareitemp as integer) as integer
declare sub control
declare function countai (ai as integer, them as integer, bslot() as BattleSprite) as integer
declare function enemycount (bslot() as battlesprite) as integer
declare function targenemycount (bslot() as BattleSprite, byval for_alone_ai as integer=0) as integer
declare sub anim_enemy (who as integer, attack as AttackData, bslot() as BattleSprite, t() as integer)
declare function getweaponpos(w as integer,f as integer,isy as integer) as integer'or x?
declare function getheropos(h as integer,f as integer,isy as integer) as integer'or x?
declare sub anim_hero (who as integer, attack as AttackData, bslot() as BattleSprite, t() as integer)
declare function inflict OVERLOAD (w as integer, t as integer, byref attacker as BattleSprite, byref target as BattleSprite, attack as AttackData, tcount as integer, byval hit_dead as integer=NO) as integer
declare function inflict OVERLOAD (byref h as integer, byref targstat as integer, w as integer, t as integer, byref attacker as BattleSprite, byref target as BattleSprite, attack as AttackData, tcount as integer, byval hit_dead as integer=NO) as integer
declare function liveherocount overload (bslot() as BattleSprite) as integer
declare function liveherocount () as integer
declare sub loadfoe (slot as integer, formdata() as integer, byref bat as BattleState, bslot() as BattleSprite, allow_dead as integer = NO)
declare sub changefoe(slot as integer, new_id as integer, formdata() as integer, bslot() as BattleSprite, hp_rule as integer, other_stats_rule as integer)
declare function randomally (who as integer) as integer
declare function randomfoe (who as integer) as integer
declare sub anim_retreat (who as integer, attack as AttackData, bslot() as BattleSprite)
declare function safesubtract (number as integer, minus as integer) as integer
declare function safemultiply (number as integer, by as single) as integer
declare sub setbatcap (byref bat as BattleState, cap as string, captime as integer, capdelay as integer)
declare sub battle_target_arrows_mask (inrange() as integer, d as integer, axis as integer, bslot() as battlesprite, targ as TargettingState)
declare sub battle_target_arrows (d as integer, axis as integer, bslot() as battlesprite, byref targ as TargettingState, allow_spread as integer=0)
declare function targetmaskcount (tmask() as integer) as integer
declare sub traceshow (s as string)
declare function trytheft (byref bat as BattleState, who as integer, targ as integer, attack as AttackData, bslot() as BattleSprite) as integer
declare function hero_total_exp (hero_slot as integer) as integer
declare sub updatestatslevelup (i as integer, allowforget as integer)
declare sub learn_spells_for_current_level(byval who as integer, byval allowforget as integer)
declare sub giveheroexperience (i as integer, exper as integer)
declare sub setheroexperience (byval who as integer, byval amount as integer, byval allowforget as integer)
declare function allowed_to_gain_levels(heroslot as integer) as integer

declare function visibleandalive (o as integer, bslot() as battlesprite) as integer
declare sub writestats (bslot() as BattleSprite)

declare sub get_valid_targs (tmask() as integer, byval who as integer, byref atk as AttackData, bslot() as BattleSprite)
declare function attack_can_hit_dead OVERLOAD (who as integer, atk_id as integer, stored_targs_can_be_dead as integer=NO) as integer
declare function attack_can_hit_dead OVERLOAD (who as integer, attack as AttackData, stored_targs_can_be_dead as integer=NO) as integer
declare sub autotarget OVERLOAD (byval who as integer, byval atk_id as integer, bslot() as BattleSprite, t() as integer, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO)
declare sub autotarget OVERLOAD (byval who as integer, byref atk as AttackData, bslot() as BattleSprite, t() as integer, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO)

declare function find_preferred_target (tmask() as integer, who as integer, atk as AttackData, bslot() as BattleSprite) as integer

declare sub try_to_reload_files_inbattle ()

#ENDIF
