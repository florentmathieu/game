extends Node3D
# Orchestrateur de campagne : geoscape ↔ combat. Lit/écrit Run (autoload).
# Boucle : afficher le territoire → région choisie → mission → issue → progression → territoire.

const Geo := preload("res://rules/Geo.gd")
const GeoscapeScene := preload("res://scenes/Geoscape.tscn")
const BattleScene := preload("res://scenes/Battle.tscn")

const ACT_NAME := {1:"Acte I — La Marche", 2:"Acte II — La Faille s'étend", 3:"Acte III — Le Cœur"}

var geoscape: Node3D = null
var battle: Node3D = null
var banner: Label
var _ci: CanvasLayer

func _ready() -> void:
	randomize()
	if Run.camp.is_empty():
		if not Run.load_game(): Run.new_campaign()
	_ci = CanvasLayer.new(); add_child(_ci)
	banner = Label.new(); banner.position = Vector2(14, 720 - 34)
	banner.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7)); _ci.add_child(banner)
	_show_geoscape()

func _clear(node: Node) -> void:
	if node != null and is_instance_valid(node): node.queue_free()

# maillage geoscape de l'acte courant (déterministe = identique à celui rendu par Geoscape)
func _cur_geo() -> Geo:
	var g := Geo.new()
	g.generate(int(Run.camp.seed) ^ (int(Run.camp.act) * 97), int(Run.camp.act), int(Run.camp.want))
	return g

func _show_geoscape() -> void:
	if bool(Run.camp.get("done", false)): return _victory_screen()
	_maybe_raid()
	_check_boss_unlock()
	geoscape = GeoscapeScene.instantiate()
	add_child(geoscape)
	geoscape.region_selected.connect(_on_region)
	_update_banner()

func _update_banner() -> void:
	var act: int = int(Run.camp.act)
	banner.text = "%s   |   missions %d   |   victoires %d   |   forges %d" % [
		ACT_NAME.get(act, "Acte %d" % act), int(Run.camp.missionN), int(Run.camp.winCount), int(Run.camp.get("forgeCount", 0))]

const Data := preload("res://rules/Data.gd")
var _sel_layer: CanvasLayer = null
var _pending := -1

# --- choix d'une région → écran de sélection d'escouade ---
func _on_region(cell: int) -> void:
	_pending = cell
	_show_squad_select(geoscape.geo.info[cell])

func _bar(frac: float, col: Color) -> Control:
	var bg := ColorRect.new(); bg.color = Color(0.17, 0.18, 0.23); bg.custom_minimum_size = Vector2(60, 8)
	var fg := ColorRect.new(); fg.color = col; fg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fg.size = Vector2(60.0 * clampf(frac, 0, 1), 8); fg.position = Vector2.ZERO
	bg.add_child(fg); return bg

func _show_squad_select(ginfo: Dictionary) -> void:
	_sel_layer = CanvasLayer.new(); _sel_layer.layer = 20; add_child(_sel_layer)
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); _sel_layer.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.04, 0.04, 0.06, 1.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := VBoxContainer.new(); box.position = Vector2(60, 50); box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Déploiement — %s  (%s, %d ennemis)" % [ginfo.name, ("BOSS" if ginfo.boss else "diff %d" % ginfo.diff), Run.mission_preview_enemies(ginfo)]
	title.add_theme_font_size_override("font_size", 22); title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	box.add_child(title)
	var hint := Label.new(); hint.text = "Choisis jusqu'a %d soldats (clic pour selectionner). fat = fatigue, str = stress, PV au depart." % Run.SQUAD_MAX
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75)); box.add_child(hint)
	for m in Run.camp.roster:
		box.add_child(_member_row(m))
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 12); box.add_child(btns)
	var go := Button.new(); go.text = "Deployer"; go.pressed.connect(_confirm_deploy); btns.add_child(go)
	var back := Button.new(); back.text = "Retour"; back.pressed.connect(_cancel_deploy); btns.add_child(back)

func _member_row(m: Dictionary) -> Control:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	var ready: bool = Run.mem_ready(m)
	var selected: bool = Run.camp.deploySel.has(m.name)
	var grade: String = Data.GRADES[Data.grade_from_xp(int(m.get("xp", 0)))]
	var tag := "[+]" if bool(m.dead) else ("[!]" if not ready else ("[*]" if bool(m.special) else "[ ]"))
	var b := Button.new(); b.custom_minimum_size = Vector2(280, 0)
	b.text = "%s %s — %s (%s)" % [tag, m.name, Data.classes()[m.cls].name, grade]
	b.disabled = not ready
	if selected: b.modulate = Color(0.6, 1.0, 0.6)
	b.pressed.connect(func(): Run.toggle_select(m.name); _refresh_select())
	row.add_child(b)
	if not bool(m.dead):
		var dh: Dictionary = Run.mem_deploy_hp(m)
		var hpl := Label.new(); hpl.text = "PV %d/%d" % [dh.hp, dh.max]; hpl.custom_minimum_size = Vector2(78, 0)
		hpl.add_theme_color_override("font_color", Color(0.45, 0.82, 0.45) if dh.full else Color(0.85, 0.64, 0.25))
		row.add_child(hpl)
		var fl := Label.new(); fl.text = "fat"; row.add_child(fl); row.add_child(_bar(int(m.fatigue) / 100.0, Color(0.37, 0.66, 0.85)))
		var sl := Label.new(); sl.text = "str"; row.add_child(sl); row.add_child(_bar(int(m.stress) / 100.0, Color(0.85, 0.64, 0.25)))
	else:
		var dead := Label.new(); dead.text = "tombé·e au combat"; dead.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3)); row.add_child(dead)
	return row

func _refresh_select() -> void:
	var ginfo: Dictionary = geoscape.geo.info[_pending]
	_clear(_sel_layer); _sel_layer = null
	_show_squad_select(ginfo)

func _cancel_deploy() -> void:
	_clear(_sel_layer); _sel_layer = null; _pending = -1

func _confirm_deploy() -> void:
	if Run.camp.deploySel.is_empty(): return
	var cell := _pending; _pending = -1
	_clear(_sel_layer); _sel_layer = null
	Run.set_mission(cell, geoscape.geo.info[cell])
	_clear(geoscape); geoscape = null
	battle = BattleScene.instantiate()
	add_child(battle)
	battle.mission_ended.connect(_on_mission_end)

# --- issue de mission → progression → retour au territoire ---
func _on_mission_end(win: bool) -> void:
	var report: Dictionary = battle.build_report() if battle != null else {}
	var deaths: Array = Run.resolve_mission(win, report)
	_clear(battle); battle = null
	if win: _advance_if_boss()
	_show_geoscape()
	if not deaths.is_empty():
		banner.text = "+ " + ", ".join(deaths) + (" sont tombé·e·s." if deaths.size() > 1 else " est tombé·e.")
	if not (Run.camp.get("pendingPromos", []) as Array).is_empty():
		_show_promotions()

# ---------- promotions A/B (choix de perk à chaque montée de grade) ----------
var _promo_layer: CanvasLayer = null
func _show_promotions() -> void:
	if _promo_layer != null: _clear(_promo_layer)
	var promos: Array = Run.camp.pendingPromos
	if promos.is_empty(): _promo_layer = null; return
	_promo_layer = CanvasLayer.new(); _promo_layer.layer = 25; add_child(_promo_layer)
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); _promo_layer.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.05, 0.04, 0.07, 1.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var box := VBoxContainer.new(); box.position = Vector2(60, 60); box.add_theme_constant_override("separation", 10); panel.add_child(box)
	var p: Dictionary = promos[0]
	var m: Dictionary = Run.member(p.name)
	var grade: String = Data.GRADES[int(p.grade)]
	var t := Label.new(); t.text = "Promotion — %s passe %s" % [p.name, grade]
	t.add_theme_font_size_override("font_size", 24); t.add_theme_color_override("font_color", Color(1, 0.88, 0.5)); box.add_child(t)
	var sub := Label.new(); sub.text = "Choisis une aptitude (%d promotion(s) en attente) :" % promos.size()
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75)); box.add_child(sub)
	var pair: Dictionary = Run.promo_pair(m.cls, int(p.grade))
	for slot in ["A", "B"]:
		var perk: Dictionary = pair[slot]
		var b := Button.new(); b.custom_minimum_size = Vector2(420, 0)
		b.text = "%s — %s" % [perk.name, _perk_desc(perk)]
		b.pressed.connect(func(): Run.choose_promo(p.name, slot); _show_promotions())
		box.add_child(b)

func _perk_desc(perk: Dictionary) -> String:
	if perk.has("abil"): return "capacité : " + str(perk.abil)
	var mod: Dictionary = perk.get("mod", {})
	var parts := []
	for k in mod: parts.append("+%d %s" % [int(mod[k]), k])
	return ", ".join(parts) if not parts.is_empty() else "bonus"

# le boss (région verrouillée) s'ouvre quand le front a nettoyé assez de régions
func _check_boss_unlock() -> void:
	var g := _cur_geo()
	var states: Dictionary = Run.camp.geoStates
	var cleared := 0; var total := 0; var boss := -1
	for cell in g.info:
		total += 1
		if bool(g.info[cell].boss): boss = cell
		elif String(states.get(cell, "available")) == "cleared": cleared += 1
	if boss >= 0 and String(states.get(boss, "")) == "locked" and cleared >= int(ceil((total - 1) * 0.6)):
		states[boss] = "available"

# boss vaincu → acte suivant (ou fin de campagne après l'acte III)
func _advance_if_boss() -> void:
	var g := _cur_geo()
	var cell: int = int(Run.mission.cell)
	if not (g.info.has(cell) and bool(g.info[cell].boss)): return
	var act: int = int(Run.camp.act)
	if act >= 3:
		Run.camp.done = true
	else:
		Run.camp.act = act + 1
		Run.camp.want = Run.ACT_MISSIONS.get(act + 1, 20)
		Run.camp.geoStates = {}        # nouveau territoire pour le nouvel acte
		Run.camp.lastAttack = -99

# événement rare : une région nettoyée est réattaquée (à reprendre) — avec temporisation
func _maybe_raid() -> void:
	if int(Run.camp.missionN) - int(Run.camp.get("lastAttack", -99)) < 3: return
	if randf() > 0.14: return
	var g := _cur_geo()
	var states: Dictionary = Run.camp.geoStates
	var pool := []
	for cell in g.info:
		if String(states.get(cell, "")) == "cleared" and not bool(g.info[cell].boss): pool.append(cell)
	if pool.is_empty(): return
	states[pool[randi() % pool.size()]] = "attacked"
	Run.camp.lastAttack = int(Run.camp.missionN)

func _victory_screen() -> void:
	_clear(geoscape); geoscape = null
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.04, 0.03, 0.05)
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var big := Label.new()
	big.text = "LA FAILLE EST REFERMÉE\n\nCampagne achevée en %d missions (%d victoires, %d forges).\n\nLa Marche de Velhaur respire de nouveau." % [
		int(Run.camp.missionN), int(Run.camp.winCount), int(Run.camp.get("forgeCount", 0))]
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.anchor_left = 0.5; big.anchor_right = 0.5; big.anchor_top = 0.4; big.anchor_bottom = 0.4
	big.offset_left = -360; big.offset_right = 360
	big.add_theme_color_override("font_color", Color(1, 0.9, 0.55)); big.add_theme_font_size_override("font_size", 26)
	_ci.add_child(big)
	banner.text = "fin"
