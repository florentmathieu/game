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
	if Run.camp.is_empty(): Run.new_campaign()
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

# --- choix d'une région → préparer et lancer la mission ---
func _on_region(cell: int) -> void:
	var ginfo: Dictionary = geoscape.geo.info[cell]
	Run.set_mission(cell, ginfo)
	_clear(geoscape); geoscape = null
	battle = BattleScene.instantiate()
	add_child(battle)
	battle.mission_ended.connect(_on_mission_end)

# --- issue de mission → progression → retour au territoire ---
func _on_mission_end(win: bool) -> void:
	Run.resolve_mission(win)
	_clear(battle); battle = null
	if win: _advance_if_boss()
	_show_geoscape()

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
