# Données du jeu (port fidèle de index.html : classes, armes, réglages).
class_name Data
extends RefCounted

# réglages mouvement / combat
const FREE_MP := 2
const AP_MAX := 2
const HEIGHT_BONUS := 6
const COVER_PEN := 30
const DEF_BRACE := 20
const PB := {1: 30, 2: 15}   # pénalité à bout portant (tir)

static func sword(a, l, h) -> Dictionary: return {"type":"melee","aim":a,"dmg_min":l,"dmg_max":h}
static func bow(a, l, h, r, c := -1) -> Dictionary:
	var w := {"type":"ranged","aim":a,"dmg_min":l,"dmg_max":h,"range":r}
	if c >= 0: w.clip = c
	return w
static func dagger(a, l, h, b, s) -> Dictionary: return {"type":"melee","aim":a,"dmg_min":l,"dmg_max":h,"flank":{"back":b,"side":s}}

# couleurs d'affichage (sphères) par équipe
const PLAYER_COL := Color(0.36, 0.69, 1.0)
const ENEMY_COL := Color(1.0, 0.42, 0.36)
const NEUTRAL_COL := Color(0.85, 0.79, 0.55)

static func classes() -> Dictionary:
	return {
		"soldat":   {"name":"Soldat", "hp":10,"mob":8,"shieldBlock":30, "w":{"melee":sword(75,4,6)}},
		"sapeur":   {"name":"Sapeur", "hp":7, "mob":8,"crackers":1, "w":{"ranged":bow(65,3,4,6,1),"melee":sword(70,3,5),"cracker":{"type":"throw","dmg_min":5,"dmg_max":9,"range":6,"radius":2,"scatter":2}}},
		"assassin": {"name":"Assassin","hp":7,"mob":8,"parry":35,"stealth":true, "w":{"melee":dagger(80,3,4,5,2)}},
		"garde":    {"name":"Garde",  "hp":8, "mob":6,"shieldBlock":20, "w":{"melee":sword(65,3,4)}},
		"archer":   {"name":"Archer", "hp":6, "mob":6, "w":{"ranged":bow(70,2,3,8)}},
		"brute":    {"name":"Brute",  "hp":13,"mob":8, "w":{"melee":sword(70,5,7)}},
		"shieldbearer":{"name":"Porteur de bouclier","hp":12,"mob":6,"shieldBlock":45,"enemyOnly":true,"abil":["shove","charge"],"w":{"melee":sword(60,3,5)}},
		"emage":    {"name":"Mage noir","hp":7,"mob":7,"enemyOnly":true,"abil":["blast","frost"],"w":{"ranged":bow(70,4,6,7,3),"melee":sword(45,2,3)}},
		"mage":     {"name":"Mage",   "hp":6, "mob":7, "w":{"ranged":bow(72,4,6,7,3),"melee":sword(45,2,3)}},
		"homme":    {"name":"Homme",  "hp":6, "mob":6,"civ":true, "w":{"melee":{"type":"melee","aim":40,"dmg_min":1,"dmg_max":2,"bare":true}}},
		"femme":    {"name":"Femme",  "hp":5, "mob":6,"civ":true, "w":{"melee":{"type":"melee","aim":40,"dmg_min":1,"dmg_max":2,"bare":true}}},
		"enfant":   {"name":"Enfant", "hp":3, "mob":7,"civ":true, "w":{"melee":{"type":"melee","aim":25,"dmg_min":0,"dmg_max":1,"bare":true}}},
	}
