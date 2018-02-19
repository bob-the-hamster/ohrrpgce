'OHRRPGCE - bmodsubs.bi
'(C) Copyright 1997-2006 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)
'Auto-generated by MAKEBI from bmodsubs.bas

#IFNDEF BMODSUBS_BI
#DEFINE BMODSUBS_BI

#INCLUDE "udts.bi"
#INCLUDE "battle_udts.bi"

declare function is_hero(byval who as integer) as integer
declare function is_enemy(byval who as integer) as integer
declare function is_attack(byval who as integer) as integer
declare function is_weapon(byval who as integer) as integer
declare sub anim_advance (byval who as integer, attack as AttackData, bslot() as battlesprite, t() as integer)
declare function atkallowed (atk as AttackData, byval attacker as integer, byval spclass as integer, byval lmplev as integer, bslot() as BattleSprite) as integer
declare function checktheftchance (byval item as integer, byval itemp as integer, byval rareitem as integer, byval rareitemp as integer) as integer
declare function countai (byval ai as integer, byval them as integer, bslot() as BattleSprite) as integer
declare function enemycount (bslot() as battlesprite) as integer
declare function targenemycount (bslot() as BattleSprite, byval for_alone_ai as integer=0) as integer
declare sub anim_enemy (byval who as integer, attack as AttackData, bslot() as BattleSprite, t() as integer)
declare function get_weapon_handle_point(itemid as integer, handlenum as integer) as XYPair
declare sub anim_hero (byval who as integer, attack as AttackData, bslot() as BattleSprite, t() as integer)
declare function inflict (byref h as integer = 0, byref targstat as integer = 0, byval attackerslot as integer, targetslot as integer, byref attacker as BattleSprite, byref target as BattleSprite, attack as AttackData, tcount as integer) as bool
declare function liveherocount overload (bslot() as BattleSprite) as integer
declare function liveherocount () as integer
declare sub loadfoe (byval slot as integer, formdata as Formation, byref bat as BattleState, bslot() as BattleSprite, byval allow_dead as integer = NO)
declare sub changefoe(byval slot as integer, byval new_id as integer, formdata as Formation, bslot() as BattleSprite, byval hp_rule as integer, byval other_stats_rule as integer)
declare sub anim_retreat (byval who as integer, attack as AttackData, bslot() as BattleSprite)
declare function safesubtract (byval number as integer, byval minus as integer) as integer
declare function safemultiply (byval number as integer, byval by as single) as integer
declare sub setbatcap (bat as BattleState, cap as string, byval captime as integer, byval capdelay as integer)
declare sub battle_target_arrows_mask (inrange() as integer, byval d as integer, byval axis as integer, bslot() as battlesprite, targ as TargettingState)
declare sub battle_target_arrows (byval d as integer, byval axis as integer, bslot() as battlesprite, targ as TargettingState, byval allow_spread as integer=0)
declare function targetmaskcount (tmask() as integer) as integer
declare sub traceshow (s as string)
declare function trytheft (bat as BattleState, byval who as integer, byval targ as integer, attack as AttackData, bslot() as BattleSprite) as integer
declare function hero_total_exp (byval hero_slot as integer) as integer
declare sub updatestatslevelup (byval hero_slot as integer, byval allowforget as integer)
declare sub hero_total_equipment_bonuses (byval hero_slot as integer, bonuses() as integer)
declare sub recompute_hero_max_stats (byval hero_slot as integer)
declare sub compute_hero_base_stats_from_max (byval hero_slot as integer)
declare sub learn_spells_for_current_level(byval who as integer, byval allowforget as integer)
declare sub giveheroexperience (byval i as integer, byval exper as integer)
declare sub setheroexperience (byval who as integer, byval amount as integer, byval allowforget as integer)
declare function allowed_to_gain_levels(byval heroslot as integer) as integer

declare function visibleandalive (byval who as integer, bslot() as battlesprite) as integer
declare sub export_battle_hero_stats (bslot() as BattleSprite)
declare sub import_battle_hero_stats (bslot() as BattleSprite)

declare sub get_valid_targs (tmask() as integer, byval who as integer, byref atk as AttackData, bslot() as BattleSprite)
declare function attack_can_hit_dead OVERLOAD (byval who as integer, byval atk_id as integer, byval stored_targs_can_be_dead as integer=NO) as integer
declare function attack_can_hit_dead OVERLOAD (byval who as integer, attack as AttackData, byval stored_targs_can_be_dead as integer=NO) as integer
declare function autotarget OVERLOAD (byval who as integer, byval atk_id as integer, bslot() as BattleSprite, t() as integer, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO) as bool
declare function autotarget OVERLOAD (byval who as integer, byref atk as AttackData, bslot() as BattleSprite, t() as integer, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO) as bool
declare function autotarget OVERLOAD (byval who as integer, byval atk_id as integer, bslot() as BattleSprite, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO) as bool
declare function autotarget OVERLOAD (byval who as integer, byref atk as AttackData, bslot() as BattleSprite, byval queue as integer=YES, byval override_blocking as integer=-2, byval dont_retarget as integer=NO) as bool

declare function find_preferred_target (tmask() as integer, byval who as integer, atk as AttackData, bslot() as BattleSprite) as integer

declare sub try_to_reload_files_inbattle ()

#ENDIF
