'OHRRPGCE CUSTOM - Attack Editor, and generic flexmenu routines
'(C) Copyright 1997-2017 James Paige and Hamster Republic Productions
'Please read LICENSE.txt for GPL License details and disclaimer of liability
'See README.txt for code docs and apologies for crappyness of this code ;)

#include "config.bi"
#include "allmodex.bi"
#include "common.bi"
#include "customsubs.bi"
#include "cglobals.bi"
#include "flexmenu.bi"
#include "const.bi"
#include "loading.bi"
#include "custom.bi"
#include "thingbrowser.bi"

'--Local SUBs
DECLARE FUNCTION atk_edit_add_new(recbuf() as integer, preview_box as Slice Ptr) as bool
DECLARE SUB atk_edit_merge_bitsets(recbuf() as integer, tempbuf() as integer)
DECLARE SUB atk_edit_split_bitsets(recbuf() as integer, tempbuf() as integer)
DECLARE SUB update_attack_editor_for_fail_conds(recbuf() as integer, caption() as string, byval AtkCapFailConds as integer)
DECLARE SUB attack_editor_build_damage_menu(recbuf() as integer, menu() as string, menutype() as integer, caption() as string, menucapoff() as integer, workmenu() as integer, state as MenuState, dmgbit() as string, maskeddmgbit() as string, damagepreview as string)
DECLARE SUB attack_editor_build_appearance_menu(recbuf() as integer, workmenu() as integer, state as MenuState)
DECLARE FUNCTION browse_base_attack_stat(byval base_num as integer) as integer

DECLARE SUB atk_edit_preview(byval pattern as integer, sl as Slice Ptr)
DECLARE SUB atk_edit_pushptr(state as MenuState, laststate as MenuState, byref menudepth as integer)
DECLARE SUB atk_edit_backptr(workmenu() as integer, mainMenu() as integer, state as MenuState, laststate as menustate, byref menudepth as integer)


SUB addcaption (caption() as string, byref indexer as integer, cap as string)
 str_array_append caption(), cap
 indexer = UBOUND(caption) + 1
END SUB

'------------------------------ Attack Editor ----------------------------------

'--ID numbers for menu item definitions

CONST AtkBackAct = 0
CONST AtkName = 1
CONST AtkAppearAct = 2
CONST AtkDmgAct = 3
CONST AtkTargAct = 4
CONST AtkCostAct = 5
CONST AtkChainAct = 6
CONST AtkBitAct = 7
CONST AtkPic = 8
CONST AtkPal = 9
CONST AtkAnimPattern = 10
CONST AtkTargClass = 11
CONST AtkTargSetting = 12
CONST AtkChooseAct = 13
CONST AtkDamageEq = 14
CONST AtkAimEq = 15
CONST AtkBaseAtk = 16
CONST AtkMPCost = 17
CONST AtkHPCost = 18
CONST AtkMoneyCost = 19
CONST AtkExtraDamage = 20
CONST AtkChainTo = 21
CONST AtkChainRate = 22
CONST AtkAnimAttacker = 23
CONST AtkAnimAttack = 24
CONST AtkDelay = 25
CONST AtkHitX = 26
CONST AtkTargStat = 27
CONST AtkCaption = 28
CONST AtkCapTime = 29
CONST AtkCaptDelay = 30
CONST AtkBaseDef = 31
CONST AtkTag = 32
CONST AtkTagIf = 33
CONST AtkTagAnd = 34
CONST AtkTag2 = 35
CONST AtkTagIf2 = 36
CONST AtkTagAnd2 = 37
CONST AtkTagAct = 38
CONST AtkDescription = 39
CONST AtkItem1 = 40
CONST AtkItemCost1 = 41
CONST AtkItem2 = 42
CONST AtkItemCost2 = 43
CONST AtkItem3 = 44
CONST AtkItemCost3 = 45
CONST AtkSoundEffect = 46
CONST AtkPreferTarg = 47
CONST AtkPrefTargStat = 48
CONST AtkChainMode = 49
CONST AtkChainVal1 = 50
CONST AtkChainVal2 = 51
CONST AtkChainBits = 52
CONST AtkElseChainTo = 53
CONST AtkElseChainRate = 54
CONST AtkElseChainMode = 55
CONST AtkElseChainVal1 = 56
CONST AtkElseChainVal2 = 57
CONST AtkElseChainBits = 58
CONST AtkChainHeader = 59
CONST AtkElseChainHeader = 60
CONST AtkInsteadChainHeader = 61
CONST AtkInsteadChainTo = 62
CONST AtkInsteadChainRate = 63
CONST AtkInsteadChainMode = 64
CONST AtkInsteadChainVal1 = 65
CONST AtkInsteadChainVal2 = 66
CONST AtkInsteadChainBits = 67
CONST AtkChainBrowserAct = 68
CONST AtkLearnSoundEffect = 69
CONST AtkTransmogAct = 70
CONST AtkTransmogEnemy = 71
CONST AtkTransmogHp = 72
CONST AtkTransmogStats = 73
CONST AtkElementFailAct = 74
CONST AtkElementalFailHeader = 75
CONST AtkElementalFails = 76  ' to 139
CONST AtkElemBitAct = 140
CONST AtkDamageBitAct = 141
CONST AtkBlankMenuItem = 142  ' Generic blank skippable menu item
CONST AtkWepPic = 143
CONST AtkWepPal = 144
CONST AtkWepHand0 = 145
CONST AtkWepHand1 = 146
CONST AtkTurnDelay = 147
CONST AtkDramaticPause = 148

'Next menu item is 148 (remember to update MnuItems)


'--Offsets in the attack data record (combined DT6 + ATTACK.BIN)

CONST AtkDatPic = 0
CONST AtkDatPal = 1
CONST AtkDatAnimPattern = 2
CONST AtkDatTargClass = 3
CONST AtkDatTargSetting = 4
CONST AtkDatDamageEq = 5
CONST AtkDatAimEq = 6
CONST AtkDatBaseAtk = 7
CONST AtkDatMPCost = 8
CONST AtkDatHPCost = 9
CONST AtkDatMoneyCost = 10
CONST AtkDatExtraDamage = 11
CONST AtkDatChainTo = 12
CONST AtkDatChainRate = 13 'See also the hacky usage of this value in updateflexmenu
CONST AtkDatAnimAttacker = 14
CONST AtkDatAnimAttack = 15
CONST AtkDatDelay = 16
CONST AtkDatHitX = 17
CONST AtkDatTargStat = 18
CONST AtkDatPreferTarg = 19
CONST AtkDatBitsets = 20' to 23
CONST AtkDatName = 24'to 35
CONST AtkDatCapTime = 36
CONST AtkDatCaption = 37'to 56
CONST AtkDatCaptDelay = 57
CONST AtkDatBaseDef = 58
CONST AtkDatTag = 59
CONST AtkDatTagIf = 60
CONST AtkDatTagAnd = 61
CONST AtkDatTag2 = 62
CONST AtkDatTagIf2 = 63
CONST AtkDatTagAnd2 = 64
CONST AtkDatBitsets2 = 65' to 72
CONST AtkDatDescription = 73'to 92
CONST AtkDatItem = 93', 95, 97
CONST AtkDatItemCost = 94', 96, 98
CONST AtkDatSoundEffect = 99
CONST AtkDatPrefTargStat = 100
CONST AtkDatChainMode = 101
CONST AtkDatChainVal1 = 102
CONST AtkDatChainVal2 = 103
CONST AtkDatChainBits = 104
CONST AtkDatElseChainTo = 105
CONST AtkDatElseChainMode = 106
CONST AtkDatElseChainRate = 107
CONST AtkDatElseChainVal1 = 108
CONST AtkDatElseChainVal2 = 109
CONST AtkDatElseChainBits = 110
CONST AtkDatInsteadChainTo = 111
CONST AtkDatInsteadChainMode = 112
CONST AtkDatInsteadChainRate = 113
CONST AtkDatInsteadChainVal1 = 114
CONST AtkDatInsteadChainVal2 = 115
CONST AtkDatInsteadChainBits = 116
CONST AtkDatLearnSoundEffect = 117
CONST AtkDatTransmogEnemy = 118
CONST AtkDatTransmogHp = 119
CONST AtkDatTransmogStats = 120
CONST AtkDatElementalFail = 121 'to 312
CONST AtkDatWepPic = 313
CONST AtkDatWepPal = 314
CONST AtkDatWepHand0X = 315
CONST AtkDatWepHand0Y = 316
CONST AtkDatWepHand1X = 317
CONST AtkDatWepHand1Y = 318
CONST AtkDatTurnDelay = 319
CONST AtkDatDramaticPause = 320

'anything past this requires expanding the data


'recindex: which attack to show. If -1, same as last time. If >= max, ask to add a new attack,
'(and exit and return -1 if cancelled).
'Otherwise, returns the attack number we were last editing.
'Note: the attack editor can be entered recursively!
FUNCTION attack_editor (recindex as integer = -1) as integer

DIM i as integer

DIM elementnames() as string
getelementnames elementnames()

'--bitsets

DIM atkbit(-1 TO 128) as string

atkbit(3) = "Unreversable Picture"
atkbit(4) = "Steal Item"

'FOR i = 0 TO 7
 'atkbit(i + 5) = elementnames(i) & " Damage" '05-12
 'atkbit(i + 13) = "Bonus vs " & readglobalstring(9 + i, "EnemyType" & i+1) '13-20
 'atkbit(i + 21) = "Fail vs " & elementnames(i) & " resistance" '21-28
 'atkbit(i + 29) = "Fail vs " & readglobalstring(9 + i, "EnemyType" & i+1) '29-36
'NEXT i

FOR i = 0 TO 7
 atkbit(i + 37) = "Cannot target enemy slot " & i
NEXT i
FOR i = 0 TO 3
 atkbit(i + 45) = "Cannot target hero slot " & i
NEXT i

atkbit(50) = "Erase rewards (Enemy target only)"
atkbit(52) = "Store Target"
atkbit(53) = "Delete Stored Target"
atkbit(54) = "Automatically choose target"
atkbit(55) = "Show attack name"
atkbit(56) = "Do not display Damage"
atkbit(59) = "Useable Outside of Battle"
atkbit(63) = "Cause heroes to run away"
atkbit(64) = "Mutable"
atkbit(65) = "Fail if target is poisoned"
atkbit(66) = "Fail if target is regened"
atkbit(67) = "Fail if target is stunned"
atkbit(68) = "Fail if target is muted"
atkbit(70) = "Check costs when used as a weapon"
atkbit(71) = "Do not chain if attack fails"
atkbit(72) = "Reset Poison register"
atkbit(73) = "Reset Regen register"
atkbit(74) = "Reset Stun register"
atkbit(75) = "Reset Mute register"
atkbit(76) = "Cancel target's attack"
atkbit(77) = "Can't be cancelled by other attacks"
atkbit(78) = "Do not trigger spawning on hit"
atkbit(79) = "Do not trigger spawning on kill"
atkbit(80) = "Check costs when used as an item"
atkbit(81) = "Re-check costs after attack delay"
atkbit(82) = "Do not cause target to flinch"
atkbit(84) = "Delay doesn't block further actions"
atkbit(85) = "Force victory"
atkbit(86) = "Force battle exit (no run animation)"
atkbit(87) = "Never trigger elemental counterattacks"
'             ^---------------------------------------^
'               the amount of room you have (39 chars)

DIM dmgbit(-1 TO 128) as string
DIM maskeddmgbit(-1 TO 128) as string  'Built in attack_editor_build_damage_menu

dmgbit(0)  = "Cure Instead of Harm"
dmgbit(1)  = "Divide Spread Damage"
dmgbit(2)  = "Absorb Damage"          'was bounceable!
dmgbit(49) = "Ignore attacker's extra hits"
dmgbit(51) = "Show damage without inflicting"
dmgbit(57) = "Reset target stat to max before hit"
dmgbit(58) = "Allow Cure to exceed maximum"
'dmgbit(60) = "Damage " & statnames(statMP) & " (obsolete)"
dmgbit(61) = "Do not randomize"
dmgbit(62) = "Damage can be Zero"
dmgbit(69) = "% based attacks damage instead of set"
dmgbit(83) = "Don't allow damage to exceed target stat"
dmgbit(88) = "Healing poison causes regen, and reverse"
'             ^---------------------------------------^
'               the amount of room you have (39 chars)



'--191 attack bits allowed in menu.
'--Data is split, See AtkDatBits and AtkDatBits2 for offsets


'These bits are edited separately, because it would be a pain to linearise them somehow,
'editbitset doesn't support it.
DIM elementbit(-1 TO 79) as string
FOR i = 0 TO small(15, gen(genNumElements) - 1)
 elementbit(i + 5) = elementnames(i) & " Damage"  'bits 5-20
NEXT i
FOR i = 16 TO gen(genNumElements) - 1
 elementbit((i - 16) + 32) = elementnames(i) & " Damage"  'bits 144-191 in the main bit array
NEXT i


DIM atk_chain_bitset_names(3) as string
atk_chain_bitset_names(0) = "Attacker must know chained attack"
atk_chain_bitset_names(1) = "Ignore chained attack's delay"
atk_chain_bitset_names(2) = "Delay doesn't block further actions"
atk_chain_bitset_names(3) = "Don't retarget if target is lost"

'----------------------------------------------------------
DIM recbuf(40 + curbinsize(binATTACK) \ 2 - 1) as integer '--stores the combined attack data from both .DT6 and ATTACK.BIN

CONST MnuItems = 148
DIM menu(MnuItems) as string
DIM menutype(MnuItems) as integer
DIM menuoff(MnuItems) as integer
DIM menulimits(MnuItems) as integer
DIM menucapoff(MnuItems) as integer

'----------------------------------------------------------

DIM capindex as integer = 0
REDIM caption(-1 TO -1) as string
DIM max(42) as integer
DIM min(42) as integer

'Limit(0) is not used

CONST AtkLimUInt = 8
max(AtkLimUInt) = 32767

CONST AtkLimInt = 9
max(AtkLimInt) = 32767
min(AtkLimInt) = -32767

CONST AtkLimStr10 = 10
max(AtkLimStr10) = 10

CONST AtkLimStr38 = 19
max(AtkLimStr38) = 38

CONST AtkLimPic = 1
max(AtkLimPic) = gen(genMaxAttackPic)

CONST AtkLimAnimPattern = 2
max(AtkLimAnimPattern) = 3
menucapoff(AtkAnimPattern) = capindex
addcaption caption(), capindex, "Cycle Forward"
addcaption caption(), capindex, "Cycle Back"
addcaption caption(), capindex, "Oscillate"
addcaption caption(), capindex, "Random"

CONST AtkLimTargClass = 3
max(AtkLimTargClass) = 12
menucapoff(AtkTargClass) = capindex
addcaption caption(), capindex, "Enemy"
addcaption caption(), capindex, "Ally"
addcaption caption(), capindex, "Self"
addcaption caption(), capindex, "All"
addcaption caption(), capindex, "Ally (Including Dead)"
addcaption caption(), capindex, "Ally Not Self"
addcaption caption(), capindex, "Revenge (last to hit attacker)"
addcaption caption(), capindex, "Revenge (whole battle)"
addcaption caption(), capindex, "Previous target"
addcaption caption(), capindex, "Recorded target"
addcaption caption(), capindex, "Dead Allies (hero only)"
addcaption caption(), capindex, "Thankvenge (last to cure attacker)"
addcaption caption(), capindex, "Thankvenge (whole battle)"

CONST AtkLimTargSetting = 4
max(AtkLimTargSetting) = 4
menucapoff(AtkTargSetting) = capindex
addcaption caption(), capindex, "Focused"
addcaption caption(), capindex, "Spread"
addcaption caption(), capindex, "Optional Spread"
addcaption caption(), capindex, "Random Roulette"
addcaption caption(), capindex, "First Target"

CONST AtkLimDamageEq = 5
max(AtkLimDamageEq) = 6
menucapoff(AtkDamageEq) = capindex
addcaption caption(), capindex, "Normal: ATK - DEF*.5"
addcaption caption(), capindex, "Blunt: ATK*.8 - DEF*.1"
addcaption caption(), capindex, "Sharp: ATK*1.3 - DEF"
addcaption caption(), capindex, "Pure Damage"
addcaption caption(), capindex, "No Damage"
addcaption caption(), capindex, "Set = N% of Max"
addcaption caption(), capindex, "Set = N% of Current"

CONST AtkLimAimEq = 6
max(AtkLimAimEq) = 8
menucapoff(AtkAimEq) = capindex
addcaption caption(), capindex, "Normal: " & statnames(statAim) & "*4 ~ " & statnames(statDodge)
addcaption caption(), capindex, "Poor: " & statnames(statAim) & "*2 ~ " & statnames(statDodge)
addcaption caption(), capindex, "Bad: " & statnames(statAim) & " ~ " & statnames(statDodge)
addcaption caption(), capindex, "Never Misses"
addcaption caption(), capindex, "Magic: " & statnames(statMagic) & " ~ " & statnames(statWill) & "*1.25"
addcaption caption(), capindex, "Percentage: " & statnames(statAim) & "% * " & statnames(statDodge) & "%"
addcaption caption(), capindex, "Percentage: " & statnames(statAim) & "%"
addcaption caption(), capindex, "Percentage: " & statnames(statMagic) & "% * " & statnames(statWill) & "%"
addcaption caption(), capindex, "Percentage: " & statnames(statMagic) & "%"

CONST AtkLimBaseAtk = 7
max(AtkLimBaseAtk) = 58
menucapoff(AtkBaseAtk) = capindex
addcaption caption(), capindex, statnames(statAtk) & " (attacker)"
addcaption caption(), capindex, statnames(statMagic) & " (attacker)"
addcaption caption(), capindex, statnames(statHP) & " (attacker)"
addcaption caption(), capindex, "Lost " & statnames(statHP) & " (attacker)"
addcaption caption(), capindex, "Random 0 to 999"
addcaption caption(), capindex, "100"
FOR i = 0 TO 11
 addcaption caption(), capindex, statnames(i) & " (attacker)"
NEXT
addcaption caption(), capindex, "previous attack"
addcaption caption(), capindex, "last damage to attacker"
addcaption caption(), capindex, "last damage to target"
addcaption caption(), capindex, "last cure to attacker"
addcaption caption(), capindex, "last cure to target"
FOR i = 0 TO 11
 addcaption caption(), capindex, statnames(i) & " (target)"
NEXT
FOR i = 0 TO 11
 addcaption caption(), capindex, "Max " & statnames(i) & " (attacker)"
NEXT
FOR i = 0 TO 11
 addcaption caption(), capindex, "Max " & statnames(i) & " (target)"
NEXT

CONST AtkLimExtraDamage = 11
max(AtkLimExtraDamage) = 32767
min(AtkLimExtraDamage) = -100

CONST AtkLimChainTo = 12
max(AtkLimChainTo) = gen(genMaxAttack) + 1'--must be updated!

CONST AtkLimChainRate = 13
max(AtkLimChainRate) = 100
min(AtkLimChainRate) = 0

CONST AtkLimAnimAttacker = 14
max(AtkLimAnimAttacker) = 9
menucapoff(AtkAnimAttacker) = capindex
addcaption caption(), capindex, "Strike"
addcaption caption(), capindex, "Cast"
addcaption caption(), capindex, "Dash In"
addcaption caption(), capindex, "SpinStrike"
addcaption caption(), capindex, "Jump (chain to Land)"
addcaption caption(), capindex, "Land"
addcaption caption(), capindex, "Null"
addcaption caption(), capindex, "Standing Cast"
addcaption caption(), capindex, "Teleport"
addcaption caption(), capindex, "Standing Strike"

CONST AtkLimAnimAttack = 15
max(AtkLimAnimAttack) = 10
menucapoff(AtkAnimAttack) = capindex
addcaption caption(), capindex, "Normal"
addcaption caption(), capindex, "Projectile"
addcaption caption(), capindex, "Reverse Projectile"
addcaption caption(), capindex, "Drop"
addcaption caption(), capindex, "Ring"
addcaption caption(), capindex, "Wave"
addcaption caption(), capindex, "Scatter"
addcaption caption(), capindex, "Sequential Projectile"
addcaption caption(), capindex, "Meteor"
addcaption caption(), capindex, "Driveby"
addcaption caption(), capindex, "Null"

CONST AtkLimDelay = 16
max(AtkLimDelay) = 1000

CONST AtkLimHitX = 17
max(AtkLimHitX) = 20
min(AtkLimHitX) = 1

CONST AtkLimTargStat = 18
max(AtkLimTargStat) = 15
menucapoff(AtkTargStat) = capindex
FOR i = 0 TO 11
 addcaption caption(), capindex, statnames(i)
NEXT
addcaption caption(), capindex, "poison register"
addcaption caption(), capindex, "regen register"
addcaption caption(), capindex, "stun register"
addcaption caption(), capindex, "mute register"

CONST AtkLimCapTime = 20
max(AtkLimCapTime) = 16383
min(AtkLimCapTime) = -1
addcaption caption(), capindex, "Ticks"  'Note: special-cased to add seconds estimate
menucapoff(AtkCapTime) = capindex
addcaption caption(), capindex, "Full Duration of Attack"
addcaption caption(), capindex, "Not at All"

CONST AtkLimCaptDelay = 21
max(AtkLimCaptDelay) = 16383
min(AtkLimCaptDelay) = 0

CONST AtkLimBaseDef = 22
max(AtkLimBaseDef) = 1 + UBOUND(statnames)
menucapoff(AtkBaseDef) = capindex
addcaption caption(), capindex, "Default"
FOR i = 0 TO UBOUND(statnames)
 addcaption caption(), capindex, statnames(i)
NEXT

CONST AtkLimTag = 23
max(AtkLimTag) = max_tag()
min(AtkLimTag) = -max_tag()

CONST AtkLimTagIf = 24
max(AtkLimTagIf) = 4
menucapoff(AtkTagIf) = capindex
'Indices are AttackTagConditionEnum
addcaption caption(), capindex, "Never:"    '0
addcaption caption(), capindex, "On Use:"   '1
addcaption caption(), capindex, "On Hit:"   '2
addcaption caption(), capindex, "On Miss:"  '3
addcaption caption(), capindex, "On Kill:"  '4

CONST AtkLimTagAnd = 25
max(AtkLimTag) = max_tag()
min(AtkLimTag) = -max_tag()

CONST AtkLimItem = 26
max(AtkLimItem) = gen(genMaxItem) + 1
min(AtkLimItem) = 0

CONST AtkLimSfx = 27
max(AtkLimSfx) = gen(genMaxSFX) + 1
min(AtkLimSfx) = 0

CONST AtkLimPal16 = 28
max(AtkLimPal16) = 32767
min(AtkLimPal16) = -1

CONST AtkLimPreferTarg = 29
max(AtkLimPreferTarg) = 8
min(AtkLimPreferTarg) = 0
menucapoff(AtkPreferTarg) = capindex
addcaption caption(), capindex, "default"    '0
addcaption caption(), capindex, "first"      '1
addcaption caption(), capindex, "closest"    '2
addcaption caption(), capindex, "farthest"   '3
addcaption caption(), capindex, "random"     '4
addcaption caption(), capindex, "weakest"    '5
addcaption caption(), capindex, "strongest"  '6
addcaption caption(), capindex, "weakest%"   '7
addcaption caption(), capindex, "strongest%" '8

CONST AtkLimPrefTargStat = 30
max(AtkLimPrefTargStat) = 16
min(AtkLimPrefTargStat) = 0
menucapoff(AtkPrefTargStat) = capindex
addcaption caption(), capindex, "same as target stat" '0
FOR i = 0 TO 11  '1 - 12
 addcaption caption(), capindex, statnames(i)
NEXT
addcaption caption(), capindex, "poison register"'13
addcaption caption(), capindex, "regen register" '14 
addcaption caption(), capindex, "stun register"  '15
addcaption caption(), capindex, "mute register"  '16

CONST AtkLimChainMode = 31
max(AtkLimChainMode) = 13
menucapoff(AtkChainMode) = capindex
addcaption caption(), capindex, "No special conditions" '0
addcaption caption(), capindex, "Tag Check"     '1
addcaption caption(), capindex, "Attacker stat > value" '2
addcaption caption(), capindex, "Attacker stat < value" '3
addcaption caption(), capindex, "Attacker stat > %"     '4
addcaption caption(), capindex, "Attacker stat < %"     '5
addcaption caption(), capindex, "Any target stat > value" '6
addcaption caption(), capindex, "Any target stat < value" '7
addcaption caption(), capindex, "Any target stat > %"     '8
addcaption caption(), capindex, "Any target stat < %"     '9
addcaption caption(), capindex, "All target stat > value" '10
addcaption caption(), capindex, "All target stat < value" '11
addcaption caption(), capindex, "All target stat > %"     '12
addcaption caption(), capindex, "All target stat < %"     '13

CONST AtkLimChainVal1 = 32
max(AtkLimChainVal1) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimChainVal1) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimChainVal2 = 33
max(AtkLimChainVal2) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimChainVal2) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimElseChainVal1 = 34
max(AtkLimElseChainVal1) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimElseChainVal1) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimElseChainVal2 = 35
max(AtkLimElseChainVal2) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimElseChainVal2) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimInsteadChainVal1 = 36
max(AtkLimInsteadChainVal1) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimInsteadChainVal1) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimInsteadChainVal2 = 37
max(AtkLimInsteadChainVal2) = 0 '--updated by update_attack_editor_for_chain()
min(AtkLimInsteadChainVal2) = 0 '--updated by update_attack_editor_for_chain()

CONST AtkLimTransmogStats = 38
max(AtkLimTransmogStats) = 3
min(AtkLimTransmogStats) = 0
menucapoff(AtkTransmogStats) = capindex
addcaption caption(), capindex, "keep old current"  '0
addcaption caption(), capindex, "restore to new max"  '1
addcaption caption(), capindex, "preserve % of max"   '2
addcaption caption(), capindex, "keep old current, limit to new max"  '3

CONST AtkLimTransmogEnemy = 39
max(AtkLimTransmogEnemy) = gen(genMaxEnemy) + 1 'Must be updated!
min(AtkLimTransmogEnemy) = 0

'Special case!
DIM AtkCapFailConds as integer = capindex
FOR i = 0 TO 63
 addcaption caption(), capindex, " [No Condition]"
 addcaption caption(), capindex, "" '--updated by update_attack_editor_for_fail_conds()
NEXT

CONST AtkLimWepPic = 40
max(AtkLimWepPic) = gen(genMaxWeaponPic) + 1 ' the +1 is because 0 is used for "default"

CONST AtkLimTurnDelay = 41
max(AtkLimTurnDelay) = 1000
min(AtkLimTurnDelay) = 0

CONST AtkLimDramaticPause = 42
max(AtkLimDramaticPause) = 1000

'next limit is 43 (remember to update the dim)

'----------------------------------------------------------------------
'--menu content

menu(AtkBackAct) = "Previous Menu"
menutype(AtkBackAct) = 1

menu(AtkName) = "Name:"
menutype(AtkName) = 6
menuoff(AtkName) = AtkDatName
menulimits(AtkName) = AtkLimStr10

menu(AtkAppearAct) = "Appearance & Sounds..."
menutype(AtkAppearAct) = 1

menu(AtkDmgAct) = "Damage Settings..."
menutype(AtkDmgAct) = 1

menu(AtkTargAct) = "Target and Aiming Settings..."
menutype(AtkTargAct) = 1

menu(AtkCostAct) = "Cost..."
menutype(AtkCostAct) = 1

menu(AtkChainAct) = "Chaining..."
menutype(AtkChainAct) = 1

menu(AtkBitAct) = "Bitsets..."
menutype(AtkBitAct) = 1

menu(AtkPic) = "Picture:"
menutype(AtkPic) = 0
menuoff(AtkPic) = AtkDatPic
menulimits(AtkPic) = AtkLimPic

menu(AtkPal) = "Palette:"
menutype(AtkPal) = 12
menuoff(AtkPal) = AtkDatPal
menulimits(AtkPal) = AtkLimPal16

menu(AtkAnimPattern) = "Animation Pattern:"
menutype(AtkAnimPattern) = 2000 + menucapoff(AtkAnimPattern)
menuoff(AtkAnimPattern) = AtkDatAnimPattern
menulimits(AtkAnimPattern) = AtkLimAnimPattern

menu(AtkTargClass) = "Target Class:"
menutype(AtkTargClass) = 2000 + menucapoff(AtkTargClass)
menuoff(AtkTargClass) = AtkDatTargClass
menulimits(AtkTargClass) = AtkLimTargClass

menu(AtkTargSetting) = "Target Setting:"
menutype(AtkTargSetting) = 2000 + menucapoff(AtkTargSetting)
menuoff(AtkTargSetting) = AtkDatTargSetting
menulimits(AtkTargSetting) = AtkLimTargSetting

menu(AtkChooseAct) = "Attack"
menutype(AtkChooseAct) = 5

menu(AtkDamageEq) = "Damage Math:"
menutype(AtkDamageEq) = 2000 + menucapoff(AtkDamageEq)
menuoff(AtkDamageEq) = AtkDatDamageEq
menulimits(AtkDamageEq) = AtkLimDamageEq

menu(AtkAimEq) = "Aim Math:"
menutype(AtkAimEq) = 2000 + menucapoff(AtkAimEq)
menuoff(AtkAimEq) = AtkDatAimEq
menulimits(AtkAimEq) = AtkLimAimEq

menu(AtkBaseAtk) = "Base ATK Stat:"
menutype(AtkBaseAtk) = 2000 + menucapoff(AtkBaseAtk)
menuoff(AtkBaseAtk) = AtkDatBaseAtk
menulimits(AtkBaseAtk) = AtkLimBaseAtk

menu(AtkMPCost) = statnames(statMP) & " Cost:"
menutype(AtkMPCost) = 0
menuoff(AtkMPCost) = AtkDatMPCost
menulimits(AtkMPCost) = AtkLimInt

menu(AtkHPCost) = statnames(statHP) & " Cost:"
menutype(AtkHPCost) = 0
menuoff(AtkHPCost) = AtkDatHPCost
menulimits(AtkHPCost) = AtkLimInt

menu(AtkMoneyCost) = readglobalstring(32, "Money") & " Cost:"
menutype(AtkMoneyCost) = 0
menuoff(AtkMoneyCost) = AtkDatMoneyCost
menulimits(AtkMoneyCost) = AtkLimInt

menu(AtkExtraDamage) = "Extra Damage:"
menutype(AtkExtraDamage) = 17 'int%
menuoff(AtkExtraDamage) = AtkDatExtraDamage
menulimits(AtkExtraDamage) = AtkLimExtraDamage

menu(AtkChainTo) = "  Attack:"
menutype(AtkChainTo) = 7 '--special class for showing an attack name
menuoff(AtkChainTo) = AtkDatChainTo
menulimits(AtkChainTo) = AtkLimChainTo

menu(AtkChainRate) = "  Rate:"
menutype(AtkChainRate) = 17
menuoff(AtkChainRate) = AtkDatChainRate
menulimits(AtkChainRate) = AtkLimChainRate

menu(AtkAnimAttacker) = "Attacker Animation:"
menutype(AtkAnimAttacker) = 2000 + menucapoff(AtkAnimAttacker)
menuoff(AtkAnimAttacker) = AtkDatAnimAttacker
menulimits(AtkAnimAttacker) = AtkLimAnimAttacker

menu(AtkAnimAttack) = "Attack Animation:"
menutype(AtkAnimAttack) = 2000 + menucapoff(AtkAnimAttack)
menuoff(AtkAnimAttack) = AtkDatAnimAttack
menulimits(AtkAnimAttack) = AtkLimAnimAttack

IF gen(genBattleMode) = 0 THEN  'Active-turn
 menu(AtkDelay) = "Delay Ticks Before Attack:"
 menutype(AtkDelay) = 19'ticks
ELSE
 menu(AtkDelay) = "Delay Attacks Before Attack:"
 menutype(AtkDelay) = 0'int
END IF
menuoff(AtkDelay) = AtkDatDelay
menulimits(AtkDelay) = AtkLimDelay

menu(AtkHitX) = "Number of Hits:"
menutype(AtkHitX) = 0
menuoff(AtkHitX) = AtkDatHitX
menulimits(AtkHitX) = AtkLimHitX

menu(AtkTargStat) = "Target Stat:"
menutype(AtkTargStat) = 2000 + menucapoff(AtkTargStat)
menuoff(AtkTargStat) = AtkDatTargStat
menulimits(AtkTargStat) = AtkLimTargStat

menu(AtkCaption) = "Caption:"
menutype(AtkCaption) = 3'goodstring
menuoff(AtkCaption) = AtkDatCaption
menulimits(AtkCaption) = AtkLimStr38

menu(AtkCapTime) = "Display Caption:"
menutype(AtkCapTime) = 3000 + menucapoff(AtkCapTime)
menuoff(AtkCapTime) = AtkDatCapTime
menulimits(AtkCapTime) = AtkLimCapTime

menu(AtkCaptDelay) = "Delay Before Caption:"
menutype(AtkCaptDelay) = 19'ticks
menuoff(AtkCaptDelay) = AtkDatCaptDelay
menulimits(AtkCaptDelay) = AtkLimCaptDelay

menu(AtkBaseDef) = "Base DEF Stat:"
menutype(AtkBaseDef) = 2000 + menucapoff(AtkBaseDef)
menuoff(AtkBaseDef) = AtkDatBaseDef
menulimits(AtkBaseDef) = AtkLimBaseDef

menu(AtkTag) = " Set Tag"
menutype(AtkTag) = 21
menuoff(AtkTag) = AtkDatTag
menulimits(AtkTag) = AtkLimTag

menu(AtkTagIf) = ""
menutype(AtkTagIf) = 2000 + menucapoff(AtkTagIf)
menuoff(AtkTagIf) = AtkDatTagIf
menulimits(AtkTagIf) = AtkLimTagIf

menu(AtkTagAnd) = " If Tag"
menutype(AtkTagAnd) = 2
menuoff(AtkTagAnd) = AtkDatTagAnd
menulimits(AtkTagAnd) = AtkLimTagAnd

menu(AtkTag2) = " Set Tag"
menutype(AtkTag2) = 21
menuoff(AtkTag2) = AtkDatTag2
menulimits(AtkTag2) = AtkLimTag

menu(AtkTagIf2) = ""
menutype(AtkTagIf2) = 2000 + menucapoff(AtkTagIf)
menuoff(AtkTagIf2) = AtkDatTagIf2
menulimits(AtkTagIf2) = AtkLimTagIf

menu(AtkTagAnd2) = " If Tag"
menutype(AtkTagAnd2) = 2
menuoff(AtkTagAnd2) = AtkDatTagAnd2
menulimits(AtkTagAnd2) = AtkLimTagAnd

menu(AtkTagAct) = "Tags..."
menutype(AtkTagAct) = 1

menu(AtkDescription) = "Description:"
menutype(AtkDescription) = 3
menuoff(AtkDescription) = AtkDatDescription
menulimits(AtkDescription) = AtkLimStr38

menu(AtkItem1) = "Item 1:"
menutype(AtkItem1) = 10
menuoff(AtkItem1) = AtkDatItem
menulimits(AtkItem1) = AtkLimItem

menu(AtkItemCost1) = "  Cost:"
menutype(AtkItemCost1) = 0
menuoff(AtkItemCost1) = AtkDatItemCost
menulimits(AtkItemCost1) = AtkLimInt

menu(AtkItem2) = "Item 2:"
menutype(AtkItem2) = 10
menuoff(AtkItem2) = AtkDatItem + 2
menulimits(AtkItem2) = AtkLimItem

menu(AtkItemCost2) = "  Cost:"
menutype(AtkItemCost2) = 0
menuoff(AtkItemCost2) = AtkDatItemCost + 2
menulimits(AtkItemCost2) = AtkLimInt

menu(AtkItem3) = "Item 3:"
menutype(AtkItem3) = 10
menuoff(AtkItem3) = AtkDatItem + 4
menulimits(AtkItem3) = AtkLimItem

menu(AtkItemCost3) = "  Cost:"
menutype(AtkItemCost3) = 0
menuoff(AtkItemCost3) = AtkDatItemCost + 4
menulimits(AtkItemCost3) = AtkLimInt

menu(AtkSoundEffect) = "Sound Effect:"
menutype(AtkSoundEffect) = 11
menuoff(AtkSoundEffect) = AtkDatSoundEffect
menulimits(AtkSoundEffect) = AtkLimSFX

menu(AtkPreferTarg) = "Prefer Target:"
menutype(AtkPreferTarg) = 2000 + menucapoff(AtkPreferTarg)
menuoff(AtkPreferTarg) = AtkDatPreferTarg
menulimits(AtkPreferTarg) = AtkLimPreferTarg

menu(AtkPrefTargStat) = "Weak/Strong Stat:"
menutype(AtkPrefTargStat) = 2000 + menucapoff(AtkPrefTargStat)
menuoff(AtkPrefTargStat) = AtkDatPrefTargStat
menulimits(AtkPrefTargStat) = AtkLimPrefTargStat

menu(AtkChainMode) = "  Condition:"
menutype(AtkChainMode) = 2000 + menucapoff(AtkChainMode)
menuoff(AtkChainMode) = AtkDatChainMode
menulimits(AtkChainMode) = AtkLimChainMode

menu(AtkChainVal1) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkChainVal1) = 18 'skipper
menuoff(AtkChainVal1) = AtkDatChainVal1
menulimits(AtkChainVal1) = AtkLimChainVal1

menu(AtkChainVal2) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkChainVal2) = 18 'skipper
menuoff(AtkChainVal2) = AtkDatChainVal2
menulimits(AtkChainVal2) = AtkLimChainVal2

menu(AtkChainBits) = "  Option bitsets..."
menutype(AtkChainBits) = 1

menu(AtkElseChainTo) = "  Attack:"
menutype(AtkElseChainTo) = 7 '--special class for showing an attack name
menuoff(AtkElseChainTo) = AtkDatElseChainTo
menulimits(AtkElseChainTo) = AtkLimChainTo

menu(AtkElseChainRate) = "  Rate:"
menutype(AtkElseChainRate) = 20 'Hacky specific type
menuoff(AtkElseChainRate) = AtkDatElseChainRate
menulimits(AtkElseChainRate) = AtkLimChainRate

menu(AtkElseChainMode) = "  Condition:"
menutype(AtkElseChainMode) = 2000 + menucapoff(AtkChainMode)
menuoff(AtkElseChainMode) = AtkDatElseChainMode
menulimits(AtkElseChainMode) = AtkLimChainMode

menu(AtkElseChainVal1) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkElseChainVal1) = 18'skipper
menuoff(AtkElseChainVal1) = AtkDatElseChainVal1
menulimits(AtkElseChainVal1) = AtkLimElseChainVal1

menu(AtkElseChainVal2) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkElseChainVal2) = 18'skipper
menuoff(AtkElseChainVal2) = AtkDatElseChainVal2
menulimits(AtkElseChainVal2) = AtkLimElseChainVal2

menu(AtkElseChainBits) = "  Option bitsets..."
menutype(AtkElseChainBits) = 1

menu(AtkChainHeader) = "[Regular Chain]"
menutype(AtkChainHeader) = 18'skipper

menu(AtkElseChainHeader) = "[Else-Chain]"
menutype(AtkElseChainHeader) = 18'skipper

menu(AtkInsteadChainHeader) = "[Instead-Chain]"
menutype(AtkInsteadChainHeader) = 18'skipper

menu(AtkInsteadChainTo) = "  Attack:"
menutype(AtkInsteadChainTo) = 7 '--special class for showing an attack name
menuoff(AtkInsteadChainTo) = AtkDatInsteadChainTo
menulimits(AtkInsteadChainTo) = AtkLimChainTo

menu(AtkInsteadChainRate) = "  Rate:"
menutype(AtkInsteadChainRate) = 17
menuoff(AtkInsteadChainRate) = AtkDatInsteadChainRate
menulimits(AtkInsteadChainRate) = AtkLimChainRate

menu(AtkInsteadChainMode) = "  Condition:"
menutype(AtkInsteadChainMode) = 2000 + menucapoff(AtkChainMode)
menuoff(AtkInsteadChainMode) = AtkDatInsteadChainMode
menulimits(AtkInsteadChainMode) = AtkLimChainMode

menu(AtkInsteadChainVal1) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkInsteadChainVal1) = 18'skipper
menuoff(AtkInsteadChainVal1) = AtkDatInsteadChainVal1
menulimits(AtkInsteadChainVal1) = AtkLimInsteadChainVal1

menu(AtkInsteadChainVal2) = "" '--updated by update_attack_editor_for_chain()
menutype(AtkInsteadChainVal2) = 18'skipper
menuoff(AtkInsteadChainVal2) = AtkDatInsteadChainVal2
menulimits(AtkInsteadChainVal2) = AtkLimInsteadChainVal2

menu(AtkInsteadChainBits) = "  Option bitsets..."
menutype(AtkInsteadChainBits) = 1

menu(AtkChainBrowserAct) = "Browse chain..."
menutype(AtkChainBrowserAct) = 1

menu(AtkLearnSoundEffect) = "Sound When Learned:"
menutype(AtkLearnSoundEffect) = 11
menuoff(AtkLearnSoundEffect) = AtkDatLearnSoundEffect
menulimits(AtkLearnSoundEffect) = AtkLimSFX

menu(AtkTransmogAct) = "Transmogrification..."
menutype(AtkTransmogAct) = 1

menu(AtkTransmogEnemy) = "Enemy target becomes:"
menutype(AtkTransmogEnemy) = 9 'enemy name
menuoff(AtkTransmogEnemy) = AtkDatTransmogEnemy
menulimits(AtkTransmogEnemy) = AtkLimTransmogEnemy

menu(AtkTransmogHp) = "Health:"
menutype(AtkTransmogHp) = 2000 + menucapoff(AtkTransmogStats)
menuoff(AtkTransmogHp) = AtkDatTransmogHp
menulimits(AtkTransmogHp) = AtkLimTransmogStats

menu(AtkTransmogStats) = "Other stats:"
menutype(AtkTransmogStats) = 2000 + menucapoff(AtkTransmogStats)
menuoff(AtkTransmogStats) = AtkDatTransmogStats
menulimits(AtkTransmogStats) = AtkLimTransmogStats

menu(AtkElementFailAct) = "Elemental failure conditions..."
menutype(AtkElementFailAct) = 1

menu(AtkElementalFailHeader) = "Fail when target's damage..."
menutype(AtkElementalFailHeader) = 18  'skip

FOR i = 0 TO small(63, gen(genNumElements) - 1)
 menu(AtkElementalFails + i) = " from " + rpad(elementnames(i), " ", 15)
 menutype(AtkElementalFails + i) = 4000 + AtkCapFailConds + i * 2  'percent_cond_grabber
 menuoff(AtkElementalFails + i) = AtkDatElementalFail + i * 3
NEXT

menu(AtkElemBitAct) = "Elemental bits..."
menutype(AtkElemBitAct) = 1

menu(AtkDamageBitAct) = "Damage bitsets..."
menutype(AtkDamageBitAct) = 1

menu(AtkBlankMenuItem) = ""
menutype(AtkBlankMenuItem) = 18  'skip

menu(AtkWepPic) = "Weapon Picture:"
menutype(AtkWepPic) = 13
menuoff(AtkWepPic) = AtkDatWepPic
menulimits(AtkWepPic) = AtkLimWepPic

menu(AtkWepPal) = "Weapon Palette:"
menutype(AtkWepPal) = 12
menuoff(AtkWepPal) = AtkDatWepPal
menulimits(AtkWepPal) = AtkLimPal16

menu(AtkWepHand0) = "Weapon handle for first frame"
menutype(AtkWepHand0) = 1

menu(AtkWepHand1) = "Weapon handle for second frame"
menutype(AtkWepHand1) = 1

menu(AtkTurnDelay) = "Delay Turns Before Attack:"
menutype(AtkTurnDelay) = 0
menuoff(AtkTurnDelay) = AtkDatTurnDelay
menulimits(AtkTurnDelay) = AtkLimTurnDelay

menu(AtkDramaticPause) = "Dramatic Pause Ticks:"
menutype(AtkDramaticPause) = 19'ticks
menuoff(AtkDramaticPause) = AtkDatDramaticPause
menulimits(AtkDramaticPause) = AtkLimDramaticPause

'----------------------------------------------------------
'--menu structure
DIM workmenu(65) as integer
DIM dispmenu(65) as string
DIM state as MenuState
state.autosize = YES
state.autosize_ignore_pixels = 12

DIM mainMenu(13) as integer
mainMenu(0) = AtkBackAct
mainMenu(1) = AtkChooseAct
mainMenu(2) = AtkName
mainMenu(3) = AtkDescription
mainMenu(4) = AtkAppearAct
mainMenu(5) = AtkTargAct
mainMenu(6) = AtkDmgAct
mainMenu(7) = AtkCostAct
mainMenu(8) = AtkChainAct
mainMenu(9) = AtkBitAct
mainMenu(10) = AtkElemBitAct
mainMenu(11) = AtkElementFailAct
mainMenu(12) = AtkTagAct
mainMenu(13) = AtkTransmogAct

DIM targMenu(5) as integer
targMenu(0) = AtkBackAct
targMenu(1) = AtkAimEq
targMenu(2) = AtkTargClass
targMenu(3) = AtkTargSetting
targMenu(4) = AtkPreferTarg
targMenu(5) = AtkPrefTargStat

DIM costMenu(9) as integer
costMenu(0) = AtkBackAct
costMenu(1) = AtkMPCost
costMenu(2) = AtkHPCost
costMenu(3) = AtkMoneyCost
costMenu(4) = AtkItem1
costMenu(5) = AtkItemCost1
costMenu(6) = AtkItem2
costMenu(7) = AtkItemCost2
costMenu(8) = AtkItem3
costMenu(9) = AtkItemCost3

DIM chainMenu(22) as integer
chainMenu(0) = AtkBackAct
chainMenu(1) = AtkChainBrowserAct
chainMenu(2) = AtkChainHeader
chainMenu(3) = AtkChainTo
chainMenu(4) = AtkChainRate
chainMenu(5) = AtkChainBits
chainMenu(6) = AtkChainMode
chainMenu(7) = AtkChainVal1
chainMenu(8) = AtkChainVal2
chainMenu(9) = AtkElseChainHeader
chainMenu(10) = AtkElseChainTo
chainMenu(11) = AtkElseChainRate
chainMenu(12) = AtkElseChainBits
chainMenu(13) = AtkElseChainMode
chainMenu(14) = AtkElseChainVal1
chainMenu(15) = AtkElseChainVal2
chainMenu(16) = AtkInsteadChainHeader
chainMenu(17) = AtkInsteadChainTo
chainMenu(18) = AtkInsteadChainRate
chainMenu(19) = AtkInsteadChainBits
chainMenu(20) = AtkInsteadChainMode
chainMenu(21) = AtkInsteadChainVal1
chainMenu(22) = AtkInsteadChainVal2

DIM tagMenu(6) as integer
tagMenu(0) = AtkBackAct
tagMenu(1) = AtkTagIf
tagMenu(2) = AtkTagAnd
tagMenu(3) = AtkTag
tagMenu(4) = AtkTagIf2
tagMenu(5) = AtkTagAnd2
tagMenu(6) = AtkTag2

DIM transmogMenu(3) as integer
transmogMenu(0) = AtkBackAct
transmogMenu(1) = AtkTransmogEnemy
transmogMenu(2) = AtkTransmogHp
transmogMenu(3) = AtkTransmogStats

DIM elementFailMenu(gen(genNumElements) + 1) as integer
elementFailMenu(0) = AtkBackAct
elementFailMenu(1) = AtkElementalFailHeader
FOR i = 0 TO gen(genNumElements) - 1
 elementFailMenu(2 + i) = AtkElementalFails + i
NEXT

'--Create the box that holds the preview
DIM preview_box as Slice Ptr
preview_box = NewSliceOfType(slRectangle)
ChangeRectangleSlice preview_box, ,uilook(uiDisabledItem), uilook(uiMenuItem), , transOpaque
'--Align the box in the bottom right
WITH *preview_box
 .X = -8
 .Y = -8
 .Width = 52
 .Height = 52
 .AnchorHoriz = 2
 .AlignHoriz = 2
 .AnchorVert = 2
 .AlignVert = 2
END WITH

'--Create the preview sprite. It will be updated before it is drawn.
DIM preview as Slice Ptr
preview = NewSliceOfType(slSprite, preview_box)
'--Align the sprite to the center of the containing box
WITH *preview
 .AnchorHoriz = 1
 .AlignHoriz = 1
 .AnchorVert = 1
 .AlignVert = 1
END WITH

'--Create the weapon preview sprite. It will be updated before it is drawn.
DIM weppreview as Slice Ptr
weppreview = NewSliceOfType(slSprite, preview_box)
'--Align the sprite to the top of the containing box
WITH *weppreview
 .AnchorHoriz = 1
 .AlignHoriz = 1
 .AnchorVert = 2
 .AlignVert = 0
END WITH

DIM damagepreview as string

'--default starting menu
setactivemenu workmenu(), mainMenu(), state
state.pt = 1  'Select <-Attack ..-> line
state.size = 25

DIM selectable() as bool
flexmenu_update_selectable workmenu(), menutype(), selectable()

DIM menudepth as integer = 0
DIM laststate as MenuState
laststate.pt = 0
laststate.top = 0

laststate.need_update = NO

STATIC rememberindex as integer = -1   'Record to switch to with TAB
DIM show_name_ticks as integer = 0  'Number of ticks to show name (after switching record with TAB)

DIM remember_atk_bit as integer = -1
DIM remember_dmg_bit as integer = -1
DIM remember_elmt_bit as integer = -1
DIM drawpreview as bool = YES
STATIC warned_old_fail_bit as bool = NO

'Which attack to show?
STATIC remember_recindex as integer = 0
IF recindex < 0 THEN
 recindex = remember_recindex
ELSE
 IF recindex > gen(genMaxAttack) THEN
  IF atk_edit_add_new(recbuf(), preview_box) THEN
   'Added a new record (blank or copy)
   saveattackdata recbuf(), recindex
   recindex = gen(genMaxAttack) + 1
  ELSE
   DeleteSlice @preview_box
   RETURN -1
  END IF
 END IF
END IF

'load data here
loadattackdata recbuf(), recindex
state.need_update = YES

'As a hack (I blame it on flexmenu itself which tries to be more "flexible" than possible),
'helpkey is used to tell us which submenu we're in
DIM helpkey as string = "attacks"
DIM tmpstr as string

'------------------------------------------------------------------------
'--main loop

setkeys YES
DO
 setwait 55
 setkeys YES
 IF keyval(scESC) > 1 THEN
  IF menudepth = 1 THEN
   atk_edit_backptr workmenu(), mainMenu(), state, laststate, menudepth
   flexmenu_update_selectable workmenu(), menutype(), selectable()
   helpkey = "attacks"
   drawpreview = YES
   damagepreview = ""
  ELSE
   EXIT DO
  END IF
 END IF

 IF keyval(scF1) > 1 THEN show_help helpkey

 '--SHIFT+BACKSPACE
 IF cropafter_keycombo(workmenu(state.pt) = AtkChooseAct) THEN
  cropafter recindex, gen(genMaxAttack), 0, game + ".dt6", 80
  '--this is a hack to detect if it is safe to erase the extended data
  '--in the second file
  IF recindex = gen(genMaxAttack) THEN
   '--delete the end of attack.bin without the need to prompt
   cropafter recindex, gen(genMaxAttack), 0, workingdir + SLASH + "attack.bin", getbinsize(binATTACK), NO
  END IF
 END IF

 IF usemenu(state, selectable()) THEN
  state.need_update = YES
 END IF

 IF workmenu(state.pt) = AtkChooseAct OR (keyval(scAlt) > 0 and NOT isStringField(menutype(workmenu(state.pt)))) THEN
  DIM lastindex as integer = recindex
  IF intgrabber_with_addset(recindex, 0, gen(genMaxAttack), 32767, "attack") THEN
   saveattackdata recbuf(), lastindex
   IF recindex > gen(genMaxAttack) THEN
    IF atk_edit_add_new(recbuf(), preview_box) THEN
     'Added a new record (blank or copy)
     saveattackdata recbuf(), recindex
    ELSE
     'cancelled add, reload the old last record
     recindex -= 1
     loadattackdata recbuf(), recindex
    END IF
   ELSE
    loadattackdata recbuf(), recindex
   END IF

   state.need_update = YES
  END IF
 END IF

 IF keyval(scTab) > 1 THEN
  IF keyval(scShift) > 0 THEN
   rememberindex = recindex
  ELSEIF rememberindex >= 0 AND rememberindex <= gen(genMaxAttack) THEN
   saveattackdata recbuf(), recindex
   SWAP rememberindex, recindex
   loadattackdata recbuf(), recindex
   state.need_update = YES
   show_name_ticks = 23
  END IF
 END IF

 'Debug key: edit all bitsets
 IF keyval(scCtrl) > 0 AND keyval(scB) > 1 THEN
  DIM allbits(-1 TO 128) as string
  FOR i = 0 TO UBOUND(allbits)
   allbits(i) = "  bit " & i
  NEXT
  FOR i = 0 TO UBOUND(atkbit)
   IF LEN(atkbit(i)) THEN allbits(i) = atkbit(i)
  NEXT
  FOR i = 0 TO UBOUND(dmgbit)
   IF LEN(dmgbit(i)) THEN allbits(i) = dmgbit(i)
  NEXT

  'Obsolete bits; changes will have no effect
  FOR i = 0 TO 7
   allbits(i + 5) = elementnames(i) & " Damage" '05-12
   allbits(i + 13) = "Bonus vs " & readglobalstring(9 + i, "EnemyType" & i+1) '13-20
   allbits(i + 21) = "Fail vs " & elementnames(i) & " resistance" '21-28
   allbits(i + 29) = "Fail vs " & readglobalstring(9 + i, "EnemyType" & i+1) '29-36
  NEXT i
  allbits(60) = "Damage " & statnames(statMP) & " (obsolete)"

  atk_edit_merge_bitsets recbuf(), buffer()
  editbitset buffer(), 0, UBOUND(allbits), allbits(), "attack_bitsets"
  atk_edit_split_bitsets recbuf(), buffer()
  state.need_update = YES
 END IF

 IF enter_space_click(state) THEN
  DIM nowindex as integer = workmenu(state.pt)
  SELECT CASE menutype(nowindex)
   CASE 8 ' Item
    DIM itemb as ItemBrowser
    recbuf(menuoff(nowindex)) = itemb.browse(recbuf(menuoff(nowindex)))
    state.need_update = YES
   CASE 10 ' Item with offset
    DIM itemb as ItemBrowser
    recbuf(menuoff(nowindex)) = itemb.browse(recbuf(menuoff(nowindex)) - 1) + 1
    state.need_update = YES
  END SELECT
  SELECT CASE nowindex
   CASE AtkChooseAct
    'The <-Attack #-> line; enter exits so that if we were called from another menu
    'it is easy to select an attack and return to it.
    EXIT DO
   CASE AtkBackAct
    IF menudepth = 1 THEN
     atk_edit_backptr workmenu(), mainMenu(), state, laststate, menudepth
     helpkey = "attacks"
     drawpreview = YES
     damagepreview = ""
    ELSE
     EXIT DO
    END IF
   CASE AtkAppearAct
    'Special case
    atk_edit_pushptr state, laststate, menudepth
    state.pt = 0
    state.need_update = YES
    drawpreview = YES
    helpkey = "attack_appearance"
   CASE AtkDmgAct
    'Special case
    atk_edit_pushptr state, laststate, menudepth
    state.pt = 0
    state.need_update = YES
    helpkey = "attack_damage"
    drawpreview = NO
   CASE AtkTargAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), targMenu(), state
    helpkey = "attack_targetting"
   CASE AtkCostAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), costMenu(), state
    helpkey = "attack_cost"
   CASE AtkChainAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), chainMenu(), state
    helpkey = "attack_chaining"
   CASE AtkElementFailAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), elementFailMenu(), state
    helpkey = "attack_elementfail"
    IF readbit(gen(), genBits2, 9) ANDALSO warned_old_fail_bit = NO THEN
     'Show warning about 'Simulate old fail vs. element resist bit'
     show_help "attack_warn_old_fail_bit"
     warned_old_fail_bit = YES
    END IF
    drawpreview = NO
   CASE AtkTagAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), tagMenu(), state
    helpkey = "attack_tags"
   CASE AtkTransmogAct
    atk_edit_pushptr state, laststate, menudepth
    setactivemenu workmenu(), transmogMenu(), state
    helpkey = "attack_transmogrify"
   CASE AtkPal
    recbuf(AtkDatPal) = pal16browse(recbuf(AtkDatPal), sprTypeAttack, recbuf(AtkDatPic))
    state.need_update = YES
   CASE AtkWepPal
    IF recbuf(AtkDatWepPic) > 0 THEN
     recbuf(AtkDatWepPal) = pal16browse(recbuf(AtkDatWepPal), sprTypeAttack, recbuf(AtkDatWepPic))
     state.need_update = YES
    END IF
   CASE AtkBitAct
    atk_edit_merge_bitsets recbuf(), buffer()
    editbitset buffer(), 0, UBOUND(atkbit), atkbit(), "attack_bitsets", remember_atk_bit
    atk_edit_split_bitsets recbuf(), buffer()
   CASE AtkDamageBitAct
    DIM updatebits as integer
    DO
     atk_edit_merge_bitsets recbuf(), buffer()
     updatebits = editbitset(buffer(), 0, UBOUND(maskeddmgbit), maskeddmgbit(), "attack_damage_bitsets", remember_dmg_bit, YES)
     atk_edit_split_bitsets recbuf(), buffer()
     IF updatebits THEN
      attack_editor_build_damage_menu recbuf(), menu(), menutype(), caption(), menucapoff(), workmenu(), state, dmgbit(), maskeddmgbit(), damagepreview
     ELSE
      EXIT DO
     END IF
    LOOP
    'Bitsets have complicated effects
    state.need_update = YES
   CASE AtkElemBitAct
    'merge the two blocks of bitsets into the buffer
    FOR i = 0 TO 1
     'includes bits 5 - 20
     buffer(i) = recbuf(AtkDatBitsets + i)
    NEXT i
    FOR i = 0 TO 2
     'bits 80 - 127
     buffer(2 + i) = recbuf(AtkDatBitsets2 + 5 + i)
    NEXT i
    editbitset buffer(), 0, UBOUND(elementbit), elementbit(), "attack_element_bitsets", remember_elmt_bit
    'split the buffer to the two bitset blocks
    FOR i = 0 TO 1
     recbuf(AtkDatBitsets + i) = buffer(i)
    NEXT i
    FOR i = 0 TO 2
     recbuf(AtkDatBitsets2 + 5 + i) = buffer(2 + i)
    NEXT i
   CASE AtkChainBits
    editbitset recbuf(), AtkDatChainBits, UBOUND(atk_chain_bitset_names), atk_chain_bitset_names(), "attack_chain_bitsets"
    state.need_update = YES
   CASE AtkElseChainBits
    editbitset recbuf(), AtkDatElseChainBits, UBOUND(atk_chain_bitset_names), atk_chain_bitset_names(), "attack_chain_bitsets"
    state.need_update = YES
   CASE AtkInsteadChainBits
    editbitset recbuf(), AtkDatInsteadChainBits, UBOUND(atk_chain_bitset_names), atk_chain_bitset_names(), "attack_chain_bitsets"
    state.need_update = YES
   CASE AtkChainBrowserAct
    saveattackdata recbuf(), recindex
    recindex = attack_chain_browser(recindex)
    loadattackdata recbuf(), recindex
    state.need_update = YES
   CASE AtkElementalFails TO AtkElementalFails + 63
    DIM cond as AttackElementCondition
    DeSerAttackElementCond cond, recbuf(), menuoff(workmenu(state.pt))
    percent_cond_editor cond, -1000.0, 1000.0, 4, "Fail", " damage" + menu(workmenu(state.pt))  'Fail when ... damage from <elem>
    SerAttackElementCond cond, recbuf(), menuoff(workmenu(state.pt))
    state.need_update = YES
   CASE AtkWepHand0
    xy_position_on_slice weppreview, recbuf(AtkDatWepHand0X), recbuf(AtkDatWepHand0Y), "weapon handle position", "xy_weapon_handle"
   CASE AtkWepHand1
    ChangeSpriteSlice weppreview, , , , 1
    xy_position_on_slice weppreview, recbuf(AtkDatWepHand1X), recbuf(AtkDatWepHand1Y), "weapon handle position", "xy_weapon_handle"
    ChangeSpriteSlice weppreview, , , , 0
   CASE AtkBaseAtk
    recbuf(AtkDatBaseAtk) = browse_base_attack_stat(recbuf(AtkDatBaseAtk))
    state.need_update = YES
  END SELECT
 END IF

 IF keyval(scAlt) = 0 or isStringField(menutype(workmenu(state.pt))) THEN 'not pressing ALT, or not allowed to
  IF editflexmenu(workmenu(state.pt), menutype(), menuoff(), menulimits(), recbuf(), caption(), min(), max()) THEN
   state.need_update = YES
  END IF
 END IF

 IF flexmenu_handle_crossrefs(state, workmenu(state.pt), menutype(), menuoff(), recindex, recbuf(), YES) THEN
  'Reload this attack in case it was changed in recursive call to the editor (in fact, this record might be deleted!)
  recindex = small(recindex, gen(genMaxAttack))
  loadattackdata recbuf(), recindex
  show_name_ticks = 23
  state.need_update = YES
 END IF

 IF state.need_update THEN
  IF helpkey = "attack_appearance" THEN
   attack_editor_build_appearance_menu recbuf(), workmenu(), state
  END IF
  IF helpkey = "attack_damage" THEN
   attack_editor_build_damage_menu recbuf(), menu(), menutype(), caption(), menucapoff(), workmenu(), state, dmgbit(), maskeddmgbit(), damagepreview
  END IF
  '--regenerate captions for fail conditions
  update_attack_editor_for_fail_conds recbuf(), caption(), AtkCapFailConds
  '--in case new attacks/enemies have been added
  max(AtkLimChainTo) = gen(genMaxAttack) + 1
  max(AtkLimTransmogEnemy) = gen(genMaxEnemy) + 1
  '--in case chain mode has changed
  update_attack_editor_for_chain recbuf(AtkDatChainMode),        menu(AtkChainVal1),        max(AtkLimChainVal1),        min(AtkLimChainVal1),        menutype(AtkChainVal1),        menu(AtkChainVal2),        max(AtkLimChainVal2),        min(AtkLimChainVal2),        menutype(AtkChainVal2)
  update_attack_editor_for_chain recbuf(AtkDatElseChainMode),    menu(AtkElseChainVal1),    max(AtkLimElseChainVal1),    min(AtkLimElseChainVal1),    menutype(AtkElseChainVal1),    menu(AtkElseChainVal2),    max(AtkLimElseChainVal2),    min(AtkLimElseChainVal2),    menutype(AtkElseChainVal2)
  update_attack_editor_for_chain recbuf(AtkDatInsteadChainMode), menu(AtkInsteadChainVal1), max(AtkLimInsteadChainVal1), min(AtkLimInsteadChainVal1), menutype(AtkInsteadChainVal1), menu(AtkInsteadChainVal2), max(AtkLimInsteadChainVal2), min(AtkLimInsteadChainVal2), menutype(AtkInsteadChainVal2)
  '--re-enforce bounds, as they might have just changed
  enforceflexbounds menuoff(), menutype(), menulimits(), recbuf(), min(), max()
  '--fix caption attack caption duration
  caption(menucapoff(AtkCapTime) - 1) = "ticks (" & seconds_estimate(recbuf(AtkDatCapTime)) & " sec)"
  updateflexmenu state.pt, dispmenu(), workmenu(), state.last, menu(), menutype(), menuoff(), menulimits(), recbuf(), caption(), max(), recindex
  flexmenu_update_selectable workmenu(), menutype(), selectable()
  '--update the picture and palette preview
  ChangeSpriteSlice preview, 6, recbuf(AtkDatPic), recbuf(AtkDatPal)
  '--update the weapon picture and palette preview
  IF recbuf(AtkDatWepPic) = 0 THEN
   weppreview->visible = NO
  ELSE
   weppreview->visible = YES
   ChangeSpriteSlice weppreview, 5, recbuf(AtkDatWepPic) - 1, recbuf(AtkDatWepPal)
  END IF
  '--done updating
  state.need_update = NO
 END IF

 clearpage dpage
 IF drawpreview THEN
  atk_edit_preview recbuf(AtkDatAnimPattern), preview
  DrawSlice preview_box, dpage
 END IF

 'Damage preview, blank on most menus.
 'It really can get 13 lines long! *shudder*
 wrapprint damagepreview, 0, 77, uilook(uiMenuItem), dpage, , , fontPlain

 'Cost preview
 IF helpkey = "attack_cost" THEN
  DIM tmp_atk as AttackData
  tmp_atk.mp_cost = recbuf(AtkDatMpCost)
  tmp_atk.hp_cost = recbuf(AtkDatHpCost)
  tmp_atk.money_cost = recbuf(AtkDatMoneyCost)
  FOR i as integer = 0 TO 2
   tmp_atk.item(i).id = recbuf(AtkDatItem + i * 2)
   tmp_atk.item(i).number = recbuf(AtkDatItemCost + i * 2)
  NEXT i
  DIM cost_caption as string = attack_cost_info(tmp_atk, 0, 99, 99)
  ' This preview indicates that only the right-most 30 characters fit on the screen;
  ' the rest are shown dark.
  edgeprint cost_caption, pRight, pBottom, uilook(uiDisabledItem), dpage
  edgeprint RIGHT(cost_caption, 30), pRight, pBottom, uilook(uiText), dpage
 END IF

 edgeprint flexmenu_tooltip(workmenu(state.pt), menutype()), pLeft, pBottom, uilook(uiDisabledItem), dpage

 standardmenu dispmenu(), state, 0, 0, dpage
 IF keyval(scAlt) > 0 OR show_name_ticks > 0 THEN 'holding ALT or just tab-flipped, show ID and name
   show_name_ticks = large(0, show_name_ticks - 1)
   tmpstr = readbadbinstring(recbuf(), AtkDatName, 10, 1) & " " & recindex
   textcolor uilook(uiText), uilook(uiHighlight)
   printstr tmpstr, pRight, 0, dpage
 END IF

 SWAP vpage, dpage
 setvispage vpage
 dowait
LOOP

'--save what we were last working on
saveattackdata recbuf(), recindex

resetsfx
DeleteSlice @preview_box

remember_recindex = recindex
RETURN recindex

END FUNCTION

'Returns YES if a new record was added, or NO if cancelled.
'When YES, gen(genMaxAttack) gets updated, and recbuf() will be populated with
'blank or cloned record, and unsaved! Previous contents are discarded.
'TODO: convert to generic_add_new
FUNCTION atk_edit_add_new (recbuf() as integer, preview_box as Slice Ptr) as bool
  DIM attack as AttackData
  DIM menu(2) as string
  DIM attacktocopy as integer = 0
  DIM preview as Slice ptr = preview_box->FirstChild
  DIM state as MenuState
  state.last = UBOUND(menu)
  state.autosize = YES
  state.pt = 1
  state.size = 3

  state.need_update = YES
  setkeys
  DO
    setwait 55
    setkeys
    IF keyval(scESC) > 1 THEN setkeys : RETURN NO  'cancel
    IF keyval(scF1) > 1 THEN show_help "attack_new"
    usemenu state
    IF state.pt = 2 THEN
      IF intgrabber(attacktocopy, 0, gen(genMaxAttack)) THEN state.need_update = YES
    END IF
    IF state.need_update THEN
      state.need_update = NO
      loadattackdata recbuf(), attacktocopy
      convertattackdata recbuf(), attack
      ChangeSpriteSlice preview, 6, recbuf(AtkDatPic), recbuf(AtkDatPal)
      menu(0) = "Cancel"
      menu(1) = "New Blank Attack"
      menu(2) = "Copy of Attack " & attacktocopy
    END IF
    IF enter_space_click(state) THEN
      setkeys
      SELECT CASE state.pt
        CASE 0 ' cancel
          RETURN NO
        CASE 1 ' blank
          gen(genMaxAttack) += 1
          initattackdata recbuf()
          RETURN YES
        CASE 2 ' copy
          gen(genMaxAttack) += 1
          RETURN YES
      END SELECT
    END IF

    clearpage vpage
    standardmenu menu(), state, 20, 20, vpage
    IF state.pt = 2 THEN
      textcolor uilook(uiMenuItem), 0
      printstr " Name: " & attack.name, 20, 48, vpage
      printstr RIGHT(" Description: " & attack.description, 40), 20, 56, vpage
      atk_edit_preview recbuf(AtkDatAnimPattern), preview
      DrawSlice preview_box, vpage
    END IF
    setvispage vpage
    dowait
  LOOP
END FUNCTION

SUB atk_edit_merge_bitsets(recbuf() as integer, tempbuf() as integer)
  'merge the two blocks of bitsets into the buffer
  DIM i as integer
  FOR i = 0 TO 3
    tempbuf(i) = recbuf(AtkDatBitsets + i)
  NEXT i
  FOR i = 0 TO 7
    tempbuf(4 + i) = recbuf(AtkDatBitsets2 + i)
  NEXT i
END SUB

SUB atk_edit_split_bitsets(recbuf() as integer, tempbuf() as integer)
  'split the buffer to the two bitset blocks
  DIM i as integer
  FOR i = 0 TO 3
    recbuf(AtkDatBitsets + i) = tempbuf(i)
  NEXT i
  FOR i = 0 TO 7
    recbuf(AtkDatBitsets2 + i) = tempbuf(4 + i)
  NEXT i
END SUB

'Regenerate captions for elemental failure conditions
SUB update_attack_editor_for_fail_conds(recbuf() as integer, caption() as string, byval AtkCapFailConds as integer)
 DIM cond as AttackElementCondition
 FOR i as integer = 0 TO 63
  DeSerAttackElementCond cond, recbuf(), 121 + i * 3
  caption(AtkCapFailConds + i * 2 + 1) = format_percent_cond(cond, " [No Condition]")
 NEXT
END SUB

SUB attack_editor_build_appearance_menu(recbuf() as integer, workmenu() as integer, state as MenuState)
  FOR i as integer = 2 TO UBOUND(workmenu)
   workmenu(i) = AtkBlankMenuItem
  NEXT
  workmenu(0) = AtkBackAct
  workmenu(1) = AtkPic
  workmenu(2) = AtkPal
  workmenu(3) = AtkAnimAttack
  workmenu(4) = AtkAnimPattern
  workmenu(5) = AtkAnimAttacker
  workmenu(6) = AtkDelay
  workmenu(7) = AtkTurnDelay
  workmenu(8) = AtkDramaticPause
  workmenu(9) = AtkCaption
  workmenu(10) = AtkCapTime
  workmenu(11) = AtkCaptDelay
  workmenu(12) = AtkSoundEffect
  workmenu(13) = AtkLearnSoundEffect
  state.last = 13
  
  DIM anim as integer = recbuf(AtkDatAnimAttacker)
  IF     anim = atkrAnimStrike _
  ORELSE anim = atkrAnimDashIn _
  ORELSE anim = atkrAnimSpinStrike _
  ORELSE anim = atkrAnimTeleport _
  ORELSE anim = atkrAnimStandingStrike _
  THEN
   workmenu(14) = AtkWepPic
   state.last = 14
   IF recbuf(AtkDatWepPic) > 0 THEN
    workmenu(15) = AtkWepPal
    workmenu(16) = AtkWepHand0
    workmenu(17) = AtkWepHand1
    state.last = 17
   END IF
  END IF
   
  state.top = 0
  state.need_update = YES
END SUB

'Wherein we show how to avoid the limitations of flexmenu by avoiding its use
SUB attack_editor_build_damage_menu(recbuf() as integer, menu() as string, menutype() as integer, caption() as string, menucapoff() as integer, workmenu() as integer, state as MenuState, dmgbit() as string, maskeddmgbit() as string, preview as string)
  DIM i as integer
  DIM attack as AttackData
  convertattackdata(recbuf(), attack)
  DIM targetstat as string = caption(menucapoff(AtkTargStat) + attack.targ_stat)
  DIM iselemental as integer = NO
  DIM target_is_register as integer = NO
  DIM percentage_attack as integer = NO

  IF attack.targ_stat > statLast AND attack.targ_stat <= statLastRegister THEN target_is_register = YES
  IF attack.damage_math = 5 OR attack.damage_math = 6 THEN percentage_attack = YES

  FOR i = 0 TO gen(genNumElements) - 1
    IF attack.elemental_damage(i) THEN iselemental = YES
  NEXT

  ' Blank the menu
  FOR i as integer = 2 TO UBOUND(workmenu)
   workmenu(i) = AtkBlankMenuItem
  NEXT
  state.top = 0
  state.last = 23
  state.need_update = YES
  preview = ""

  ' By default, all bitsets shown. We'll blank ones to hide later
  FOR i = 0 TO UBOUND(dmgbit)
    maskeddmgbit(i) = dmgbit(i)
  NEXT


  ' Start building
  workmenu(0) = AtkBackAct   'Previous
  workmenu(1) = AtkHitX      'Number of hits
  workmenu(2) = AtkDamageEq  'Damage equation
  DIM nextslot as integer = 3

  ' "Attacks will ignore extra hits stat" gen bitset
  IF xreadbit(gen(), 13, genBits2) THEN
    maskeddmgbit(49) = ""  'Ignore attacker's extra hits
  END IF

  IF xreadbit(gen(), 13, genBits2) = NO AND attack.ignore_extra_hits = NO THEN
    preview += "Hits " & attack.hits & " to " & attack.hits & " + attacker " + statnames(statHitX) + !" times\n"
  ELSE
    IF attack.hits = 1 THEN
      preview += !"Hits 1 time\n"
    ELSE
      preview += "Hits " & attack.hits & !" times\n"
    END IF
  END IF

  IF target_is_register THEN
    'Register stats are always capped to max
    maskeddmgbit(58) = ""  'Allow Cure to exceed maximum
  END IF

  IF attack.targ_stat <> statRegen AND attack.targ_stat <> statPoison THEN
    maskeddmgbit(88) = ""  'Healing poison causes regen and reverse
  END IF

  'If Damage Math is No Damage
  '(Note that this also disables nearly all aiming and failure logic!)
  IF attack.damage_math = 4 THEN
    'Nada... and only one of the bitsets apply

    workmenu(nextslot) = AtkDamageBitAct   'Damage bitsets menu
    nextslot += 1

    FOR i = 0 TO UBOUND(maskeddmgbit)
      IF i <> 49 THEN maskeddmgbit(i) = ""  'Ignore attacker's extra hits
    NEXT

    'Also "Do not display damage" has no effect, but that's not in this menu

  ELSE
    'Doing damage

    DIM setvalue as integer = NO  'Setting target stat directly to a value (percentage of something)
    DIM elemental_modifiers as integer = iselemental  'absorbable due to elements?

    'A normal attack (not percentage-based)
    IF attack.damage_math <= 3 THEN
      workmenu(nextslot) = AtkBaseAtk      'Base attack value/stat
      nextslot += 1
      IF attack.damage_math <> 3 THEN
        'Not pure damage
        workmenu(nextslot) = AtkBaseDef    'Base defense stat
        nextslot += 1
      END IF

      menu(AtkExtraDamage) = "Extra Damage:"
      menutype(AtkExtraDamage) = 17  'value%

      preview += "${LM48}DMG = "

      DIM as string amult, dmult, astat, dstat

      astat = caption(menucapoff(AtkBaseAtk) + attack.base_atk_stat)
      dstat = caption(menucapoff(AtkBaseDef) + attack.base_def_stat)
      IF attack.base_def_stat = 0 THEN  'Default
        IF attack.base_atk_stat = 1 THEN  'Magic attack
          dstat = statnames(statWill)
        ELSE
          dstat = statnames(statDef)
        END IF
      END IF

      IF attack.damage_math = 0 THEN amult = "" : dmult = "0.5 * "  'Normal
      IF attack.damage_math = 1 THEN amult = "0.8 * " : dmult = "0.1 * "  'Blunt
      IF attack.damage_math = 2 THEN amult = "1.3 * " : dmult = ""  'Sharp

      DIM show_extra_damage as integer = (attack.extra_damage <> 0)

      IF attack.damage_math = 3 THEN  'Pure damage
        'Some special case simplifications
        IF attack.base_atk_stat = 4 THEN
          '0 to 999
          preview += "Random(0 to " & INT(9.99 * (100 + attack.extra_damage)) & ")"
          show_extra_damage = NO
        ELSEIF attack.base_atk_stat = 5 THEN
          '100
          preview += STR(100 + attack.extra_damage)
          show_extra_damage = NO
        ELSE
          preview += astat
        END IF
      ELSE
        preview += "(" + amult + astat + " - " + dmult + dstat + ")"
      END IF

      IF show_extra_damage THEN
        preview += " * " & (attack.extra_damage + 100) & "%"
      END IF
      IF iselemental THEN
        preview += " * Elemental Bonuses"
      END IF

      IF attack.do_not_randomize = NO THEN
        preview += !"\nDMG = DMG +/- 20%"
      END IF

      'If the attack is actually spreadable (Spread or Optional Spread)
      IF attack.targ_set = 1 OR attack.targ_set = 2 THEN
        IF attack.divide_spread_damage THEN preview += " / Num Targets"
      ELSE
        maskeddmgbit(1) = ""  'Divide spread damage
      END IF

      '--mask bitsets which have no effect
      maskeddmgbit(69) = "" '% based attacks damage instead of set


    ELSEIF attack.damage_math = 5 OR attack.damage_math = 6 THEN
      '%-based attacks. Two big alternative damage formulae!

      elemental_modifiers = NO

      DIM as string tempcap

      preview += "${LM48}"

      IF attack.percent_damage_not_set = NO THEN
        setvalue = YES

        '--percentage damage shows target stat
        tempcap = caption(menucapoff(AtkTargStat) + recbuf(AtkDatTargStat)) + " = " & (100 + attack.extra_damage) & "%"
        caption(menucapoff(AtkDamageEq) + 5) = tempcap + " of Maximum"
        caption(menucapoff(AtkDamageEq) + 6) = tempcap + " of Current"

        IF attack.show_damage_without_inflicting THEN
          'Ugh, special case it to show damage instead
          'preview += "DMG = "  + caption(menucapoff(AtkDamageEq) + attack.damage_math) + " - Current " + targetstat
          IF attack.damage_math = 5 THEN tempcap = "maximum " + targetstat
          IF attack.damage_math = 6 THEN tempcap = "current " + targetstat
          preview += "DMG = current " + targetstat + " - " & (100 + attack.extra_damage) & "% of " + tempcap
        ELSE
          preview += "Target " + caption(menucapoff(AtkDamageEq) + attack.damage_math)
        END IF

        '--mask bitsets which have no effect
        maskeddmgbit(0) = ""  'Cure instead of harm
        maskeddmgbit(83) = "" 'Don't allow damage to exceed target stat
        'Enemy's "Harmed by cure" bitset also does nothing

      ELSE
        tempcap = (100 + attack.extra_damage) & "%"
        caption(menucapoff(AtkDamageEq) + 5) = tempcap + " of Maximum"
        caption(menucapoff(AtkDamageEq) + 6) = tempcap + " of Current"

        preview += "DMG = " + caption(menucapoff(AtkDamageEq) + attack.damage_math) + " " + targetstat

      END IF

      menu(AtkExtraDamage) = "Percentage:"
      menutype(AtkExtraDamage) = 22  '(100 + value)%

      '--mask bitsets which have no effect
      maskeddmgbit(1) = ""   'Divide spread damage
      maskeddmgbit(61) = ""  'Do not randomize
      maskeddmgbit(62) = ""  'Damage can be zero
      
    ELSE
      fatalerror "Impossible damage math setting"
    END IF

    'Add rest of menu items
    IF attack.show_damage_without_inflicting = NO OR percentage_attack THEN
      'If not inflicting, only need to select target stat if it affects damage
      workmenu(nextslot) = AtkTargStat     'Target stat
      nextslot += 1
    END IF
    workmenu(nextslot) = AtkExtraDamage  'Extra damage %
    nextslot += 1
    workmenu(nextslot) = AtkDamageBitAct 'Damage bitsets menu
    nextslot += 1

    'If this bit is set, then damage caps and "Allow cure to exceed maximum" and absorbing
    'don't take effect, but "Do not exceed target stat" and min 1 damage still do
    IF attack.show_damage_without_inflicting = YES THEN
      maskeddmgbit(2)  = ""  'Absorb Damage
      maskeddmgbit(57) = ""  'Reset target stat to max before hit
      maskeddmgbit(58) = ""  'Allow Cure to exceed maximum
      maskeddmgbit(88) = ""  'Healing poison causes regen and reverse
    END IF

    IF attack.show_damage_without_inflicting = NO AND setvalue = NO AND gen(genDamageCap) > 0 THEN
      'Both damage caps takes effect
      IF attack.damage_can_be_zero THEN
        preview += !"\nDMG = limit(DMG, 0 to " & gen(genDamageCap) & ")"
      ELSE
        preview += !"\nDMG = limit(DMG, 1 to " & gen(genDamageCap) & ")"
      END IF
    ELSEIF percentage_attack = NO THEN
      'Cap damage below
      IF attack.damage_can_be_zero = NO THEN
        preview += !"\nIf DMG <= 0 then DMG = 1"
      ELSE
        preview += !"\nIf DMG < 0 then DMG = 0"
      END IF
    END IF

    DIM might_otherwise_exceed_max as integer = NO  'Could "allow cure to exceed max" be needed for THE TARGET

    'Check whether (and say when) this attack might cure the target
    IF elemental_modifiers THEN
      '(setvalue is NO)
      IF attack.cure_instead_of_harm THEN
        preview += !"\nNegate DMG if target absorbs element or not `Harmed by cure'"
      ELSE
        preview += !"\nNegate DMG if target absorbs element"
      END IF
      might_otherwise_exceed_max = YES
    ELSEIF attack.cure_instead_of_harm AND setvalue = NO THEN
      'AKA damage-not-set percentage-based attack
      preview += !"\nNegate DMG if target not `Harmed by cure'"
      might_otherwise_exceed_max = YES
    ELSEIF setvalue = YES AND attack.extra_damage > 0 THEN
      might_otherwise_exceed_max = YES
    END IF

    IF setvalue = NO AND attack.do_not_exceed_targ_stat THEN
      preview += !"\nDMG = limit(DMG, -target lost " + targetstat + " to target " + targetstat + ")"

      'In this case, we can never cure the target, but we ONLY hide "Allow Cure to exceed maximum"
      'if we are not absorbing, because it still affects the attacker's target stat!
      IF attack.absorb_damage = NO THEN
        maskeddmgbit(58) = ""  'Allow Cure to exceed maximum
      END IF
      might_otherwise_exceed_max = NO
    END IF

    IF attack.show_damage_without_inflicting = NO THEN
      IF setvalue THEN
        'Special case, "Target stat = ..." line already added
        IF attack.absorb_damage THEN
          preview += !"\nAttacker " + targetstat + " -= change to target's " + targetstat
        END IF
      ELSE

        IF attack.reset_targ_stat_before_hit THEN
          preview += !"\nTarget " + targetstat + " = Max " + targetstat + " - DMG"
        ELSE
          preview += !"\nTarget " + targetstat + " -= DMG"
        END IF
        IF attack.absorb_damage THEN
          preview += !"\nAttacker " + targetstat + " += DMG"
        END IF
      END IF

      IF attack.poison_is_negative_regen AND (attack.targ_stat = statPoison OR attack.targ_stat = statRegen) THEN
        'Healing poison causes regen and reverse
        DIM negatedstat as integer = IIF(attack.targ_stat = statPoison, statRegen, statPoison)
        DIM negatedstatname as string = caption(menucapoff(AtkTargStat) + negatedstat)
        preview += !"\nIf Target/Attacker " + targetstat + " > Max"
        preview += !"\nthen Target/Attacker " & negatedstatname & " -= amount above Max"
      END IF

      IF attack.allow_cure_to_exceed_maximum = NO AND target_is_register = NO THEN
        'Might the target stat be capped?
        'Don't bother stating this for registers, as they are always capped (and the preview gets way too long)
        IF might_otherwise_exceed_max THEN
          'preview += !"\nIf Target " + targetstat + " > Maximum then " + targetstat + " = Maximum"
          preview += !"\nLimit Target " + targetstat + " to <= Max"
        END IF
        IF attack.absorb_damage THEN
          'preview += !"\nIf Attacker " + targetstat + " > Maximum then " + targetstat + " = Maximum"
          preview += !"\nLimit Attacker " + targetstat + " to <= Max"
        END IF
      END IF
    END IF
  END IF

  state.pt = small(state.pt, nextslot - 1)

END SUB

SUB atk_edit_preview(byval pattern as integer, sl as Slice Ptr)
 STATIC anim0 as integer
 STATIC anim1 as integer
 anim0 = anim0 + 1
 IF anim0 > 3 THEN
  anim0 = 0
  IF pattern = 0 THEN anim1 = anim1 + 1: IF anim1 > 2 THEN anim1 = 0
  IF pattern = 1 THEN anim1 = anim1 - 1: IF anim1 < 0 THEN anim1 = 2
  IF pattern = 2 THEN anim1 = anim1 + 1: IF anim1 > 2 THEN anim1 = -1
  IF pattern = 3 THEN anim1 = randint(3)
 END IF
 ChangeSpriteSlice sl, , , ,ABS(anim1)
END SUB


'--------------------------- Nearly Generic Flexmenu Stuff ---------------------


SUB atk_edit_backptr(workmenu() as integer, mainMenu() as integer, state as MenuState, laststate as menustate, byref menudepth as integer)
 setactivemenu workmenu(), mainMenu(), state
 menudepth = 0
 state.pt = laststate.pt
 state.top = laststate.top
 state.need_update = YES
END SUB

SUB atk_edit_pushptr(state as MenuState, laststate as MenuState, byref menudepth as integer)
 laststate.pt = state.pt
 laststate.top = state.top
 menudepth = 1
END SUB

SUB flexmenu_update_selectable(workmenu() as integer, menutype() as integer, selectable() as bool)
 REDIM selectable(UBOUND(workmenu))
 FOR i as integer = 0 TO UBOUND(workmenu)
  selectable(i) = menutype(workmenu(i)) <> 18  'skippable
 NEXT
END SUB

'Handles attempt to enter the attack or enemy editor by hitting Enter/etc/+/Insert on a menu item.
'Returns true if need to update state.
FUNCTION flexmenu_handle_crossrefs (state as MenuState, nowindex as integer, menutype() as integer, menuoff() as integer, recindex as integer, recbuf() as integer, is_attack_editor as bool) as bool

 'Early out tests
 IF enter_or_add_new(state) = NO THEN RETURN NO
 SELECT CASE menutype(nowindex)
  CASE 7, 9 'attack, enemy
  CASE ELSE
   RETURN NO
 END SELECT

 IF is_attack_editor THEN
  saveattackdata recbuf(), recindex
 ELSE
  saveenemydata recbuf(), recindex
 END IF

 DIM ret as bool
 DIM byref dat as integer = recbuf(menuoff(nowindex))
 SELECT CASE menutype(nowindex)
  CASE 7 'dat is attack + 1
   ret = attackgrabber(dat, state, 1, , NO)  'intgrab=NO
  CASE 9 'dat is enemy + 1
   ret = enemygrabber(dat, state, 1, , NO)  'intgrab=NO
 END SELECT

 ' If we entered the attack/enemy editor recursively recbuf() may now stale, so
 ' reload it and re-write dat.
 ' When we return YES recbuf() will be reloaded again, so we need to save our changes too!
 IF ret THEN
  DIM newdat as integer = dat
  IF is_attack_editor THEN
   loadattackdata recbuf(), recindex
   dat = newdat
   saveattackdata recbuf(), recindex
  ELSE
   loadenemydata recbuf(), recindex
   dat = newdat
   saveenemydata recbuf(), recindex
  END IF
 END IF

 RETURN ret
END FUNCTION

FUNCTION editflexmenu (nowindex as integer, menutype() as integer, menuoff() as integer, menulimits() as integer, datablock() as integer, caption() as string, mintable() as integer, maxtable() as integer) as bool
'--Calls intgrabber/strgrabber etc, as appropriate for the selected data field.
'--returns true if data has changed, false it not

'nowindex is the index into the menu data of the currently selected menuitem
'menutype() holds the type of each menu element.
'           0=int
'           1=action (usually triggering a different menu)
'           2=tag condition, including special tags
'           3=string(bybyte)
'           4=badly stored string(by word)
'           5=chooser (not connected with data)
'           6=extra badly stored string(by word with gap)
'           7=attack number (offset!)
'           8=item number (not offset)
'           9=enemy name (offset)
'           10=item number (offset!)
'           11=sound effect (offset)
'           12=defaultable positive int >=0 is int, -1 is "default"
'           13=Default zero int >0 is int, 0 is "default"
'           14=sound effect + 1 (0=default, -1=none)
'           15=speed (shows battle turn time estimate)
'           16=stat (numbered the same way as BattleStatsSingle.sta())
'           17=int with a % sign after it
'           18=skipper (caption which is skipped by the cursor)
'           19=ticks (with seconds estimate)
'           20=Else-Chain Rate hack (clumsy hack to force myself to do this elegantly in editedit --James)
'           21=set tag, excluding special tags
'           22=(int+100) with a % sign after it
'           1000-1999=postcaptioned int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           2000-2999=caption-only int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           3000-3999=multi-state (uses caption index -1 too!)
'           4000-4999=percent_cond_grabber, where caption(n-4000) holds
'                     the default string (no condition), and caption(n-4000+1) is
'                     the repr string needed by percent_cond_grabber.
'                     Limits not yet supported.
'                     (The condition is stored in 3 consecutive INTs.)
'           5000-5999=percent_grabber (single floats), where caption(n-4000) holds
'                     the repr string needed by percent_grabber.
'                     Limits not yet supported.
'                     (The single is stored in 2 consecutive INTs.)
'menuoff() is the offsets into the data block where each menu data is stored
'menulimits() is the offsets into the mintable() and maxtable() arrays
'datablock() holds the actual data
'mintable() is minimum integer values
'maxtable() is maximum int values and string limits

DIM changed as bool = NO
DIM s as string

SELECT CASE menutype(nowindex)
 CASE 0, 8, 12 TO 17, 19, 20, 1000 TO 3999' integers
  changed = intgrabber(datablock(menuoff(nowindex)), mintable(menulimits(nowindex)), maxtable(menulimits(nowindex)))
 CASE 7, 9 TO 11 'offset integers
  changed = zintgrabber(datablock(menuoff(nowindex)), mintable(menulimits(nowindex)) - 1, maxtable(menulimits(nowindex)) - 1)
 CASE 22 '(int+100)%
  DIM temp as integer = datablock(menuoff(nowindex)) + 100
  changed = intgrabber(temp, mintable(menulimits(nowindex)) + 100, maxtable(menulimits(nowindex)) + 100)
  datablock(menuoff(nowindex)) = temp - 100
 CASE 2' tag condition
  changed = tag_grabber(datablock(menuoff(nowindex)), -max_tag(), max_tag(), YES)
 CASE 21' set tag (non-special)
  changed = tag_grabber(datablock(menuoff(nowindex)), -max_tag(), max_tag(), NO)
 CASE 3' string
  s = readbinstring(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)))
  IF strgrabber(s, maxtable(menulimits(nowindex))) THEN changed = YES
  writebinstring s, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex))
 CASE 4' badly stored string
  s = readbadbinstring(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 0)
  IF strgrabber(s, maxtable(menulimits(nowindex))) THEN changed = YES
  writebadbinstring s, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 0
 CASE 6' extra badly stored string
  s = readbadbinstring(datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 1)
  IF strgrabber(s, maxtable(menulimits(nowindex))) THEN changed = YES
  writebadbinstring s, datablock(), menuoff(nowindex), maxtable(menulimits(nowindex)), 1
 CASE 4000 TO 4999' elemental condition
  DIM cond as AttackElementCondition
  DIM capnum as integer = menutype(nowindex) - 4000
  DeSerAttackElementCond cond, datablock(), menuoff(nowindex)
  'modifies caption(capnum + 1)
  changed = percent_cond_grabber(cond, caption(capnum + 1), caption(capnum), -1000.0, 1000.0)
  'debug "cond_grab: ch=" & changed & " type = " & cond.type & " val = " & cond.value &  " off = " & menuoff(nowindex) & " cap = " & caption(capnum + 1)
  SerAttackElementCond cond, datablock(), menuoff(nowindex)
 CASE 5000 TO 5999' single, as percent
  DIM value as single
  DIM capnum as integer = menutype(nowindex) - 5000
  value = DeSerSingle(datablock(), menuoff(nowindex))
  'modifies caption(capnum)
  changed = percent_grabber(value, caption(capnum), -1000.0, 1000.0)
  SerSingle(datablock(), menuoff(nowindex), value)
END SELECT

'--preview sound effects
IF menutype(nowindex) = 11 AND changed THEN resetsfx
IF menutype(nowindex) = 11 AND enter_or_space() THEN
 DIM sfx as integer = datablock(menuoff(nowindex))
 IF sfx > 0 AND sfx <= gen(genMaxSFX) + 1 THEN
  playsfx sfx - 1
 END IF
END IF

RETURN changed

END FUNCTION

SUB enforceflexbounds (menuoff() as integer, menutype() as integer, menulimits() as integer, recbuf() as integer, min() as integer, max() as integer)

FOR i as integer = 0 TO UBOUND(menuoff)
 SELECT CASE menutype(i)
  CASE 0, 8, 12 TO 17, 19, 20, 22, 1000 TO 3999
   '--bound ints
   IF menulimits(i) > 0 THEN
    '--only bound items that have real limits
    IF recbuf(menuoff(i)) < min(menulimits(i)) OR recbuf(menuoff(i)) > max(menulimits(i)) THEN
     '--detected out-of-range
     recbuf(menuoff(i)) = large(0, min(menulimits(i)))
    END IF
   END IF
 END SELECT
NEXT i

END SUB

SUB setactivemenu (workmenu() as integer, newmenu() as integer, byref state as MenuState)
 DIM i as integer
 FOR i = 0 TO UBOUND(newmenu)
  workmenu(i) = newmenu(i)
 NEXT i
 state.pt = 0
 state.top = 0
 state.last = UBOUND(newmenu)
 state.need_update = YES
END SUB

SUB updateflexmenu (mpointer as integer, nowmenu() as string, nowdat() as integer, size as integer, menu() as string, menutype() as integer, menuoff() as integer, menulimits() as integer, datablock() as integer, caption() as string, maxtable() as integer, recindex as integer)

'--generates a nowmenu subset from generic menu data

'nowmenu() contains the results. a menu ready to use with standardmenu
'nowdat() is a list of the indexes of which menu elements are currently on display
'size is the index of the last element in nowdat() and nowmenu()
'menu() holds all the available captions. They may contain $$ to indicate where
'       the generated text should be inserted, otherwise it is appended.
'menutype() holds the type of each menu element.
'           0=int
'           1=action (usually triggering a different menu)
'           2=tag condition, including special tags
'           3=string(bybyte)
'           4=badly stored string(by word)
'           5=record chooser (not connected with data)
'           6=extra badly stored string(by word with gap)
'           7=attack number (offset)
'           8=item number (not offset)
'           9=enemy name (offset)
'           10=item name (offset)
'           11=sound effect (offset)
'           12=defaultable positive int >=0 is int, -1 is "default"
'           13=Default zero int >0 is int, 0 is "default"
'           14=sound effect + 1 (0=default, -1=none)
'           15=speed (shows battle turn time estimate)
'           16=stat (numbered the same way as BattleStatsSingle.sta())
'           17=int with a % sign after it
'           18=skipper (caption which is skipped by the cursor)
'           19=ticks (with seconds estimate)
'           20=Else-Chain Rate hack (clumsy hack to force myself to do this elegantly in editedit --James)
'           21=set tag, excluding special tags
'           22=(int+100) with a % sign after it
'           1000-1999=postcaptioned int (caption-start-offset=n-1000)
'                     (be careful about negatives!)
'           2000-2999=caption-only int (caption-start-offset=n-2000)
'                     (be careful about negatives!)
'           3000-3999=Multi-state (0 and negatives are caption-only,
'                                  positive is postcaptioned. Captions are
'                                  numbered bass-ackwards )
'           4000-4999=percent_cond_grabber, where caption(n-4000) holds
'                     the default string (no condition), and caption(n-4000+1) is
'                     the repr string needed by percent_cond_grabber.
'                     Limits not yet supported.
'                     (The condition is stored in 3 consecutive INTs.)
'           5000-5999=percent_grabber (single floats), where caption(n-4000) holds
'                     the repr string needed by percent_grabber.
'                     Limits not yet supported.
'                     (The single is stored in 2 consecutive INTs.)
'menuoff() tells us what index to look for the data for this menu item
'menulimits() is the offset to look in maxtable() for limits
'datablock() the actual data the menu represents
'caption() available captions for postcaptioned ints
'maxtable() used here only for max string lengths

DIM maxl as integer
DIM capnum as integer
DIM dat as integer
DIM i as integer
FOR i = 0 TO size
 DIM nospace as integer = NO
 DIM datatext as string
 dat = datablock(menuoff(nowdat(i)))
 nowmenu(i) = menu(nowdat(i))
 SELECT CASE menutype(nowdat(i))
  CASE 0 '--int
   datatext = STR(dat)
  CASE 2 '--tag condition, including specials
   datatext = tag_condition_caption(dat, "", "NONE")
  CASE 3 '--goodstring
   maxl = maxtable(menulimits(nowdat(i)))
   datatext = readbinstring(datablock(), menuoff(nowdat(i)), maxl)
   nospace = YES
  CASE 4 '--badstring
   maxl = maxtable(menulimits(nowdat(i)))
   datatext = readbadbinstring(datablock(), menuoff(nowdat(i)), maxl, 0)
   nospace = YES
  CASE 5 '--record index
   'Special, $$ text replacement not available
   nowmenu(i) = CHR(27) & nowmenu(i) & " " & recindex & CHR(26)
  CASE 6 '--extrabadstring
   maxl = maxtable(menulimits(nowdat(i)))
   datatext = readbadbinstring(datablock(), menuoff(nowdat(i)), maxl, 1)
   nospace = YES
  CASE 7 '--attack number
   IF dat <= 0 THEN
    datatext = "None"
   ELSE
    datatext = (dat - 1) & " " + readattackname(dat - 1)
   END IF
  CASE 8 '--item number
   datatext = load_item_name(dat, 0, 1)
  CASE 9 '--enemy number
   IF dat <= 0 THEN
    datatext = "None"
   ELSE
    datatext = (dat - 1) & " " + readenemyname(dat - 1)
   END IF
  CASE 10 '--item number, offset
    datatext = load_item_name(dat, 0, 0)
  CASE 11 '--sound effect number, offset
    IF dat <= 0 THEN
      datatext = "None"
    ELSE
      datatext = (dat - 1) & " (" + getsfxname(dat - 1) + ")"
    END IF
  CASE 12 '--defaultable positive int
    datatext = defaultint(dat)
  CASE 13 '--zero default int
    datatext = zero_default(dat)
  CASE 14 '--sound effect number + 1 (0=default, -1=none)
    IF dat = 0 THEN
      datatext = "Default"
    ELSEIF dat < 0 THEN
      datatext = "None"
    ELSE
      datatext = (dat - 1) & " (" + getsfxname(dat - 1) + ")"
    END IF
  CASE 15 '--speed (shows battle turn time estimate)
    datatext = dat & " (1 turn each " & speed_estimate(dat) & ")"
  CASE 16 '--stat
    SELECT CASE dat
     CASE 0 TO 11
      datatext = statnames(dat)
     CASE 12: datatext = "poison register"
     CASE 13: datatext = "regen register"
     CASE 14: datatext = "stun register"
     CASE 15: datatext = "mute register"
    END SELECT
  CASE 17 '--int%
   datatext = dat & "%"
  CASE 18 '--skipper
   '--no change to caption
  CASE 19 '--ticks
   datatext = dat & " ticks (" & seconds_estimate(dat) & " sec)"
  CASE 20 '--Else-chain rate (FIXME: it is a terrible hack to hardcode 13 here)
   datatext = dat & "%"
   'AtkDatChainRate = 13
   IF dat > 0 ANDALSO datablock(13) > 0 THEN
    datatext = datatext &  " (effectively " & INT((100 - datablock(13)) / 100.0 * dat) & "%)"
   END IF
  CASE 21 '--set tag, not including specials
   datatext = tag_set_caption(dat, "")
  CASE 22 '--(int+100)%
   datatext = (dat + 100) & "%"
  CASE 1000 TO 1999 '--captioned int
   capnum = menutype(nowdat(i)) - 1000
   datatext = dat & " " & caption(capnum + dat)
  CASE 2000 TO 2999 '--caption-only int
   capnum = menutype(nowdat(i)) - 2000
   datatext = caption(capnum + dat)
  CASE 3000 TO 3999 '--multistate
   capnum = menutype(nowdat(i)) - 3000
   IF dat > 0 THEN
    datatext = dat & " " & caption(capnum - 1)
   ELSE
    datatext = caption(capnum + ABS(dat))
   END IF
  CASE 4000 TO 4999 '--percent_cond_grabber
   capnum = menutype(nowdat(i)) - 4000
   datatext = caption(capnum + 1)
   nospace = YES
  CASE 5000 TO 5999 '--percent_grabber
   capnum = menutype(nowdat(i)) - 5000
   datatext = caption(capnum)
 END SELECT
 IF replacestr(nowmenu(i), "$$", datatext) = 0 THEN
  'No replacements made
  IF nospace = NO AND nowmenu(i) <> "" THEN nowmenu(i) += " "
  nowmenu(i) += datatext
 END IF
NEXT i
END SUB

FUNCTION isStringField(byval mnu as integer) as bool
  IF mnu = 3 OR mnu = 4 OR mnu = 6 THEN RETURN YES
  RETURN NO
END FUNCTION

'Message to show at the bottom of the screen. Only for things not specific to enemy or attack editor.
FUNCTION flexmenu_tooltip(nowindex as integer, menutype() as integer) as string
 SELECT CASE menutype(nowindex)
  CASE 7, 9  'attack (offset)
   RETURN "ENTER to edit, + or INSERT to add new"
 END SELECT
END FUNCTION

'------------------------------------------------------------------------------

'Returns which "base attack stat" was selected. base_num is the initial/default value.
FUNCTION browse_base_attack_stat(byval base_num as integer) as integer

 IF base_num = 1 THEN base_num = 12 'redundant attacker magic entry
 IF base_num = 2 THEN base_num = 6 'redundant attacker HP entry

 DIM hstate as MenuState
 hstate.last = 4
 DIM state(4) as MenuState
 DIM menu(4) as MenuDef
 FOR i as integer = 0 TO 4
  ClearMenuData menu(i)
 NEXT i

 append_menu_item(menu(0), "Default (" & statnames(statAtk) & ")")
 menu(0).last->extra(0) = 0
 append_menu_item(menu(0), "100")
 menu(0).last->extra(0) = 5
 append_menu_item(menu(0), "Lost HP")
 menu(0).last->extra(0) = 3
 append_menu_item(menu(0), "Random 0-999")
 menu(0).last->extra(0) = 4
 append_menu_item(menu(0), "Previous attack")
 menu(0).last->extra(0) = 18
 append_menu_item(menu(0), "Last damage to attacker")
 menu(0).last->extra(0) = 19
 append_menu_item(menu(0), "Last damage to target")
 menu(0).last->extra(0) = 20
 append_menu_item(menu(0), "Last cure to attacker")
 menu(0).last->extra(0) = 21
 append_menu_item(menu(0), "Last cure to target")
 menu(0).last->extra(0) = 22

 FOR i as integer = 0 TO 11
  append_menu_item(menu(1), statnames(i) & " (attacker)")
  menu(1).last->extra(0) = 6 + i
  append_menu_item(menu(2), statnames(i) & " (target)")
  menu(2).last->extra(0) = 23 + i
  append_menu_item(menu(3), "Max " & statnames(i) & " (attacker)")
  menu(3).last->extra(0) = 35 + i
  append_menu_item(menu(4), "Max " & statnames(i) & " (target)")
  menu(4).last->extra(0) = 47 + i
 NEXT i
 
 FOR i as integer = 0 TO 4
  FOR j as integer = 0 TO menu(i).numitems - 1
   state(i).active = NO
   IF menu(i).items[j]->extra(0) = base_num THEN
    state(i).active = YES
    state(i).pt = j
    hstate.pt = i
   END IF
  NEXT j
  WITH menu(i)
   .textalign = alignLeft
   .alignhoriz = alignLeft
   .alignvert = alignTop
   .anchorhoriz = alignLeft
   .anchorvert = alignTop
   .offset.y = 5
   .maxrows = 22
   .bordersize = -4
   IF i = 0 THEN
    .offset.x = 4
   ELSE
    .offset.x = menu(i-1).offset.x + menu(i-1).rect.wide + 8
   END IF
  END WITH
  init_menu_state state(i), menu(i)
  ' Draw the menu to calculate its width and position
  draw_menu menu(i), state(i), vpage
 NEXT i

 ' Pre-scroll the menus so that the selected one is fully visible
 DIM shiftx as integer
 WITH menu(hstate.pt).rect
  IF .x < 0 THEN
   shiftx = .x
  ELSE
   shiftx = large(0, .x + .wide - vpages(vpage)->w)
  END IF
 END WITH
 FOR i as integer = 0 TO 4
  menu(i).offset.x -= shiftx
 NEXT i

 DIM oldpt as integer
 DIM result as integer

 setkeys
 DO
  setwait 33
  setkeys

  IF keyval(scEsc) > 1 THEN
   result = base_num
   EXIT DO
  END IF

  IF keyval(scF1) > 1 THEN show_help "attack_browse_base_stat"

  IF enter_space_click(hstate) THEN
   result = menu(hstate.pt).items[state(hstate.pt).pt]->extra(0)
   EXIT DO
  END IF
  
  oldpt = hstate.pt
  IF usemenu(hstate, scLeft, scRight) THEN
   state(hstate.pt).pt = small(state(oldpt).pt, state(hstate.pt).last)
  END IF
  FOR i as integer = 0 TO 4
   state(i).active = (i = hstate.pt)
   usemenu state(i)
  NEXT i

  IF menu(hstate.pt).rect.x < 0 THEN
   FOR i as integer = 0 TO 4
    menu(i).offset.x += 16
   NEXT i
  ELSEIF menu(hstate.pt).rect.x + menu(hstate.pt).rect.wide > vpages(vpage)->w THEN
   FOR i as integer = 0 TO 4
    menu(i).offset.x -= 16
   NEXT i
  END IF

  clearpage vpage
  FOR i as integer = 0 TO 4
   draw_menu menu(i), state(i), vpage
  NEXT i  
  setvispage vpage
  dowait
 LOOP
 
 setkeys
 FOR i as integer = 0 TO 4
  ClearMenuData menu(i)
 NEXT i
 RETURN result
END FUNCTION
