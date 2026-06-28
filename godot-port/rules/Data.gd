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

# capacités : portées + recharges (port de index.html)
const COOLDOWN := {"smoke":3,"breach":4,"shadowstrike":2,"rally":3,"taunt":3,"holdline":3,"wall":3,"blast":3,"heal":2,"frost":2,"shove":3,"charge":4}
const BLAST_RANGE := 6
const BLAST_RADIUS := 1
const BLAST_MIN := 4
const BLAST_MAX := 7
const HEAL_RANGE := 6
const HEAL_AMT := 6
const FROST_RANGE := 7
const CHARGE_RANGE := 7

const GRADES := ["Recrue", "Aguerri", "Vétéran", "Élite", "Champion"]
const XP_THRESH := [0, 3, 7, 12, 17]
static func grade_from_xp(xp: int) -> int:
	var g := 0
	for i in XP_THRESH.size(): if xp >= XP_THRESH[i]: g = i
	return g

# perks : par classe, une paire A/B par grade. abil = capacité ; mod = bonus chiffrés.
static func perks() -> Dictionary:
	return {
		"soldat": [
			{"A":{"id":"se1a","name":"Cri de ralliement","abil":"rally"}, "B":{"id":"se1b","name":"Tenace","mod":{"hp":4}}},
			{"A":{"id":"se2a","name":"Provocation","abil":"taunt"}, "B":{"id":"se2b","name":"Meneur","mod":{"dmg":1}}},
			{"A":{"id":"se3a","name":"Tenir la ligne","abil":"holdline"}, "B":{"id":"se3b","name":"Garde d'acier","mod":{"shieldBlock":15}}},
			{"A":{"id":"se4a","name":"Allonge","mod":{"freeMp":1}}, "B":{"id":"se4b","name":"Vétéran","mod":{"dmg":2}}}],
		"sapeur": [
			{"A":{"id":"sa1a","name":"Fumigène","abil":"smoke"}, "B":{"id":"sa1b","name":"Œil de lynx","mod":{"aim":10}}},
			{"A":{"id":"sa2a","name":"Charge creuse","abil":"breach"}, "B":{"id":"sa2b","name":"Endurci","mod":{"hp":3}}},
			{"A":{"id":"sa3a","name":"Artificier","mod":{"scatter":1}}, "B":{"id":"sa3b","name":"Charge lourde","mod":{"dmg":2}}}],
		"assassin": [
			{"A":{"id":"as1a","name":"Frappe de l'ombre","abil":"shadowstrike"}, "B":{"id":"as1b","name":"Lame vive","mod":{"dmg":2}}},
			{"A":{"id":"as2a","name":"Estompe","abil":"vanish"}, "B":{"id":"as2b","name":"Précision","mod":{"aim":10}}},
			{"A":{"id":"as3a","name":"Tueur","mod":{"dmg":2}}, "B":{"id":"as3b","name":"Insaisissable","mod":{"parry":20}}},
			{"A":{"id":"as4a","name":"Allonge","mod":{"freeMp":1}}, "B":{"id":"as4b","name":"Coupe-jarret","mod":{"dmg":2}}}],
		"garde": [
			{"A":{"id":"ga1a","name":"Bouclier protecteur","abil":"protect"}, "B":{"id":"ga1b","name":"Robuste","mod":{"hp":4}}},
			{"A":{"id":"ga2a","name":"Mur mobile","abil":"wall"}, "B":{"id":"ga2b","name":"Repousser","abil":"shove"}},
			{"A":{"id":"ga3a","name":"Foulée","mod":{"mob":1}}, "B":{"id":"ga3b","name":"Bastion","mod":{"hp":5}}},
			{"A":{"id":"ga4a","name":"Charge longue","abil":"charge"}, "B":{"id":"ga4b","name":"Rempart","mod":{"shieldBlock":15}}}],
		"brute": [
			{"A":{"id":"br1a","name":"Colosse","mod":{"hp":5}}, "B":{"id":"br1b","name":"Bourrin","mod":{"dmg":2}}},
			{"A":{"id":"br2a","name":"Fracasse","mod":{"dmg":3}}, "B":{"id":"br2b","name":"Foulée","mod":{"mob":1}}},
			{"A":{"id":"br3a","name":"Cuir épais","mod":{"hp":6}}, "B":{"id":"br3b","name":"Carnage","mod":{"dmg":3}}},
			{"A":{"id":"br4a","name":"Allonge","mod":{"freeMp":1}}, "B":{"id":"br4b","name":"Titan","mod":{"hp":8}}}],
		"mage": [
			{"A":{"id":"mg1a","name":"Déflagration","abil":"blast"}, "B":{"id":"mg1b","name":"Trait perçant","mod":{"dmg":2}}},
			{"A":{"id":"mg2a","name":"Vague de soin","abil":"heal"}, "B":{"id":"mg2b","name":"Longue portée","mod":{"range":2}}},
			{"A":{"id":"mg3a","name":"Givre","abil":"frost"}, "B":{"id":"mg3b","name":"Vitalité","mod":{"hp":5}}}],
	}
static func perk_by_id(cls: String, id: String):
	for g in perks().get(cls, []):
		if g.A.id == id: return g.A
		if g.B.id == id: return g.B
	return null
