extends Node
# État de campagne partagé (singleton autoload) : géoscape, roster, usure, sauvegarde.
# Port des systèmes campRun d'index.html (carry / attrition / xp / forge / raids).
const Data := preload("res://rules/Data.gd")

var camp := {}        # geoStates, missionN, winCount, act, seed, want, forge*, roster, carry, deploySel
var mission := {}     # seed, diff, act, objective, cell, name, forge, boss, enemies

const ACT_MISSIONS := {1:10, 2:20, 3:20}
const SQUAD_MAX := 4

# réglages d'usure (port des constantes d'équilibrage)
const FATIGUE_MISSION := 30
const STRESS_DMG := 3
const STRESS_KO_ALLY := 15
const STRESS_SELF_KO := 25
const REST_FRAC := 0.5
const WEARY := 100
const DEATH_PCT := 50
const SPELL_FATIGUE := 6

# escouade de départ : Aldric est le héros narratif (★ spécial = ne meurt pas définitivement)
const STARTER := [
	{"name":"Aldric", "cls":"soldat",   "special":true},
	{"name":"Vesna",  "cls":"assassin", "special":false},
	{"name":"Brom",   "cls":"garde",    "special":false},
	{"name":"Lys",    "cls":"mage",     "special":false},
	{"name":"Cael",   "cls":"archer",   "special":false},
	{"name":"Doran",  "cls":"brute",    "special":false},
	{"name":"Mira",   "cls":"sapeur",   "special":false},
]

# def (optionnel, campagne scénarisée) : {name, seed, roster:[{name,cls,special}], acts:{"1":n,...},
# narrative:{"1":{arrive,forge,boss},...}, potions}
func new_campaign(def := {}) -> void:
	var src: Array = def.get("roster", STARTER)
	var roster: Array = []
	for m in src:
		roster.append({"name":m.name, "cls":m.cls, "xp":int(m.get("xp", 0)), "stress":0, "fatigue":0,
			"special":bool(m.get("special", false)), "dead":false, "perks":(m.get("perks", []) as Array).duplicate()})
	var acts: Dictionary = def.get("acts", {})
	camp = {"geoStates":{}, "missionN":0, "winCount":0, "act":1,
		"seed":(int(def.seed) if def.has("seed") else (randi() & 0x7fffffff)) | 1,
		"want":int(acts.get("1", ACT_MISSIONS[1])),
		"forgeCount":0, "forgeBonus":{"hp":0, "dmg":0}, "lastAttack":-99, "done":false,
		"roster":roster, "carry":{}, "deploySel":[], "pendingPromos":[],
		"seenActs":[], "seenBoss":[], "potions":int(def.get("potions", 2)),
		"title":String(def.get("name", "")), "narr":def.get("narrative", {}), "acts":acts}
	mission = {}
	auto_select()

# want (régions) pour l'acte courant — surchargé par une campagne scénarisée
func want_for_act(act: int) -> int:
	var acts: Dictionary = camp.get("acts", {})
	return int(acts.get(str(act), ACT_MISSIONS.get(act, 20)))

# charge une campagne scénarisée depuis un JSON ; renvoie true si OK
func load_campaign_file(path: String) -> bool:
	if not FileAccess.file_exists(path): return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return false
	var data = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("roster"): return false
	new_campaign(data); save_game()
	return true

# ---------- roster : grades, perks, PV ----------
func member(name: String) -> Dictionary:
	for m in camp.get("roster", []):
		if m.name == name: return m
	return {}

func mem_ready(m: Dictionary) -> bool:
	return not m.is_empty() and not bool(m.dead) and int(m.fatigue) < WEARY and int(m.stress) < WEARY

# perks effectivement choisis (A/B) au fil des promotions
func member_perks(m: Dictionary) -> Array:
	return m.get("perks", [])

# paire A/B débloquée à un grade donné (grade 1 → première paire de l'arbre)
func promo_pair(cls: String, grade: int) -> Dictionary:
	var tree: Array = Data.perks().get(cls, [])
	if grade - 1 < 0 or grade - 1 >= tree.size(): return {}
	return tree[grade - 1]

# applique le choix de promotion (slot "A" ou "B") au premier en attente pour ce membre
func choose_promo(name: String, slot: String) -> void:
	var promos: Array = camp.get("pendingPromos", [])
	for i in promos.size():
		if promos[i].name == name:
			var m := member(name)
			var pair := promo_pair(m.cls, int(promos[i].grade))
			if not pair.is_empty(): m.perks.append(pair[slot].id)
			promos.remove_at(i)
			save_game()
			return

func auto_promote() -> void:   # tests / sans UI : choisit la branche A
	while not (camp.get("pendingPromos", []) as Array).is_empty():
		choose_promo(camp.pendingPromos[0].name, "A")

func mem_max_hp(m: Dictionary) -> int:
	var h: int = int(Data.classes().get(m.cls, {}).get("hp", 10))
	for id in member_perks(m):
		var p = Data.perk_by_id(m.cls, id)
		if p != null and p.has("mod") and p.mod.has("hp"): h += int(p.mod.hp)
	h += int(camp.get("forgeBonus", {}).get("hp", 0))
	return h

# PV au déploiement : reposé → plein ; vient de combattre → soin partiel (50 % du manque)
# exact = mission bonus enchaînée : PV EXACTEMENT conservés (pas de passage au camp)
func mem_deploy_hp(m: Dictionary, exact := false) -> Dictionary:
	var mx: int = mem_max_hp(m)
	var carry = camp.get("carry", {}).get(m.name, null)
	var hp: int = mx
	if carry != null:
		hp = clampi(int(carry), 1, mx) if exact else min(mx, int(carry) + int(ceil((mx - int(carry)) * 0.5)))
	return {"hp":hp, "max":mx, "full":hp >= mx}

# ---------- sélection d'escouade ----------
func ready_members() -> Array:
	var r: Array = []
	for m in camp.get("roster", []):
		if mem_ready(m): r.append(m.name)
	return r

func auto_select() -> void:
	var sel: Array = []
	for nm in ready_members():
		if sel.size() >= SQUAD_MAX: break
		sel.append(nm)
	camp.deploySel = sel

func toggle_select(name: String) -> void:
	var sel: Array = camp.get("deploySel", [])
	if sel.has(name): sel.erase(name)
	elif sel.size() < SQUAD_MAX and mem_ready(member(name)): sel.append(name)
	camp.deploySel = sel

# ---------- mission ----------
func enemy_count(diff: int, boss: bool) -> int:
	var n := clampi(2 + diff, 3, 7)
	if boss: n += 1
	n += int(camp.get("forgeCount", 0))
	return clampi(n, 3, 9)

func mission_preview_enemies(ginfo: Dictionary) -> int:
	return enemy_count(int(ginfo.diff), bool(ginfo.boss))

func objective_for(boss: bool) -> String:
	if boss: return "assassinate"
	var kinds := ["eliminate", "assassinate", "rescue", "defend", "survive", "extract"]
	return kinds[randi() % kinds.size()]

func set_mission(cell: int, ginfo: Dictionary) -> void:
	var diff: int = ginfo.diff
	var boss: bool = ginfo.boss
	mission = {
		"seed": (int(camp.seed) ^ (cell * 2654435761) ^ (int(camp.missionN) * 40503)) & 0x7fffffff | 1,
		"diff": diff, "act": int(camp.act), "objective": objective_for(boss),
		"cell": cell, "name": ginfo.name, "forge": ginfo.forge, "boss": boss,
		"enemies": enemy_count(diff, boss) }

# mission bonus enchaînée : un 2e affrontement, escouade déjà éprouvée (PV conservés exactement)
func set_bonus_mission() -> void:
	var diff: int = max(1, int(mission.get("diff", 1)))
	mission = {
		"seed": (int(camp.seed) ^ (int(camp.missionN) * 2246822519) ^ 0x5bd1) & 0x7fffffff | 1,
		"diff": diff, "act": int(camp.act), "objective": "eliminate",
		"cell": -1, "name": "Cible d'opportunite", "forge": false, "boss": false,
		"enemies": clampi(2 + diff, 3, 6), "bonus": true }

# issue d'une mission bonus : usure (mini, pas de repos), récompense, PAS de progression geoscape
func resolve_bonus(win: bool, report: Dictionary = {}) -> Array:
	var deaths: Array = []
	var deployed: Array = camp.get("deploySel", [])
	var ko_count := 0
	for nm in deployed:
		if report.has(nm) and bool(report[nm].get("ko", false)): ko_count += 1
	for m in camp.get("roster", []):
		if bool(m.dead) or not (deployed.has(m.name) and report.has(m.name)): continue
		var r: Dictionary = report[m.name]
		m.fatigue = min(100, int(m.fatigue) + FATIGUE_MISSION + int(r.get("spellsCast", 0)) * SPELL_FATIGUE)
		var self_ko: bool = bool(r.get("ko", false))
		m.stress = min(100, int(m.stress) + int(r.get("dmgTaken", 0)) * STRESS_DMG
			+ (STRESS_SELF_KO if self_ko else 0)
			+ max(0, ko_count - (1 if self_ko else 0)) * STRESS_KO_ALLY)
		camp.carry[m.name] = max(0, int(r.get("hp", 0)))
		if self_ko and not bool(m.special) and not win and randf() * 100.0 < DEATH_PCT:
			m.dead = true; deaths.append(m.name)
	if win:
		award_xp(report)
		camp.potions = int(camp.get("potions", 0)) + 1   # butin de la mission bonus
	auto_select(); save_game()
	return deaths

# ---------- issue de mission : carry, usure, XP, progression ----------
# report : { name -> {hp, max, dmgTaken, kills, spellsCast, ko} }
func resolve_mission(win: bool, report: Dictionary = {}) -> Array:
	var deaths := apply_attrition(win, report)
	if win: award_xp(report)
	var cell: int = mission.cell
	camp.geoStates[cell] = "cleared" if win else "lost"
	camp.missionN = int(camp.missionN) + 1
	if win:
		camp.winCount = int(camp.winCount) + 1
		if mission.get("forge", false):
			camp.forgeCount = int(camp.forgeCount) + 1
			var n: int = camp.forgeCount
			camp.forgeBonus = {"hp": 3 * n, "dmg": n}
	auto_select()
	save_game()
	return deaths

func apply_attrition(win: bool, report: Dictionary) -> Array:
	var deaths: Array = []
	var deployed: Array = camp.get("deploySel", [])
	var ko_count := 0
	for nm in deployed:
		if report.has(nm) and bool(report[nm].get("ko", false)): ko_count += 1
	for m in camp.get("roster", []):
		if bool(m.dead): continue
		if deployed.has(m.name) and report.has(m.name):
			var r: Dictionary = report[m.name]
			m.fatigue = min(100, int(m.fatigue) + FATIGUE_MISSION + int(r.get("spellsCast", 0)) * SPELL_FATIGUE)
			var self_ko: bool = bool(r.get("ko", false))
			m.stress = min(100, int(m.stress) + int(r.get("dmgTaken", 0)) * STRESS_DMG
				+ (STRESS_SELF_KO if self_ko else 0)
				+ max(0, ko_count - (1 if self_ko else 0)) * STRESS_KO_ALLY)
			camp.carry[m.name] = max(0, int(r.get("hp", 0)))
			# mort définitive : K.O. ET mission perdue ET non-spécial ET au jet
			if self_ko and not bool(m.special) and not win and randf() * 100.0 < DEATH_PCT:
				m.dead = true; deaths.append(m.name)
		else:
			# repos au camp : récup partielle de l'usure + soin complet (carry effacé)
			m.fatigue = max(0, int(m.fatigue) - int(ceil(int(m.fatigue) * REST_FRAC)))
			m.stress = max(0, int(m.stress) - int(ceil(int(m.stress) * REST_FRAC)))
			camp.carry.erase(m.name)
	return deaths

func award_xp(report: Dictionary) -> void:
	var promos: Array = camp.get("pendingPromos", [])
	for m in camp.get("roster", []):
		if not report.has(m.name): continue
		var old_g: int = Data.grade_from_xp(int(m.xp))
		m.xp = int(m.xp) + 3 + int(report[m.name].get("kills", 0))
		var new_g: int = Data.grade_from_xp(int(m.xp))
		for g in range(old_g + 1, new_g + 1):
			if not promo_pair(m.cls, g).is_empty(): promos.append({"name":m.name, "grade":g})
	camp.pendingPromos = promos

# retrait scénarisé du statut spécial (« son rôle est fait ») → devient mortel
func apply_mortal(names: Array) -> Array:
	var hit: Array = []
	for nm in names:
		var m := member(nm)
		if not m.is_empty() and bool(m.special): m.special = false; hit.append(nm)
	return hit

# ---------- sauvegarde ----------
const SAVE_PATH := "user://save.json"
func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(camp)); f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH): return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return false
	var data = JSON.parse_string(f.get_as_text()); f.close()
	if typeof(data) != TYPE_DICTIONARY or not data.has("roster"): return false
	camp = data
	return true
