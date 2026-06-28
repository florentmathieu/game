extends Node3D
# Orchestrateur de campagne : geoscape ↔ combat. Lit/écrit Run (autoload).
# Boucle : afficher le territoire → région choisie → mission → issue → progression → territoire.

const Geo := preload("res://rules/Geo.gd")
const Narrative := preload("res://rules/Narrative.gd")
const GeoscapeScene := preload("res://scenes/Geoscape.tscn")
const BattleScene := preload("res://scenes/Battle.tscn")

const ACT_NAME := {1:"Acte I — La Marche", 2:"Acte II — La Faille s'étend", 3:"Acte III — Le Cœur"}

var geoscape: Node3D = null
var battle: Node3D = null
var banner: Label
var _ci: CanvasLayer

var _started := false
func _ready() -> void:
	randomize()
	_ci = CanvasLayer.new(); _ci.layer = 50; add_child(_ci)
	banner = Label.new(); banner.position = Vector2(14, 720 - 34)
	banner.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7)); _ci.add_child(banner)
	Run.load_game()        # progression existante (peut être remplacée si la campagne éditeur a changé)
	if OS.has_feature("web"):
		_fetch_campaign()  # campagne publiée par l'éditeur HTML (toujours prioritaire)
	else:
		_begin()

# récupère campaign.json (publié à côté du build par l'éditeur) ; URL ABSOLUE (l'URL relative
# ne se résout pas en web) ; accept_gzip=false (le navigateur décompresse déjà) ; anti-cache.
func _fetch_campaign() -> void:
	var http := HTTPRequest.new(); add_child(http)
	http.accept_gzip = false
	http.request_completed.connect(_on_campaign_fetched)
	var url := "campaign.json"
	var base = JavaScriptBridge.eval("window.location.href.replace(/[#?].*$/,'').replace(/[^/]*$/,'')", true)
	if typeof(base) == TYPE_STRING and String(base).begins_with("http"): url = String(base) + "campaign.json"
	url += "?_=" + str(Time.get_ticks_msec())
	if http.request(url) != OK: _begin(); return
	get_tree().create_timer(8.0).timeout.connect(_begin)

func _on_campaign_fetched(_result, code, _headers, body: PackedByteArray) -> void:
	var applied := false
	if code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and data.has("roster"):
			# le port charge TOUJOURS la dernière campagne publiée par l'éditeur, reconvertie à neuf
			# (une sauvegarde issue d'un ancien build pouvait rester incompatible et bloquer l'affichage)
			Run.apply_campaign(data, Run.campaign_sig(data)); applied = true
	_begin()

func _begin() -> void:
	if _started: return
	_started = true
	if Run.camp.is_empty():
		if not Run.load_campaign_file("res://campaigns/marche.json"): Run.new_campaign()
	if Run.has_graph():
		_run_node(String(Run.camp.get("nodeId", Run.camp.get("graphStart", ""))))   # campagne à graphe (éditeur)
	else:
		_show_geoscape()   # campagne procédurale (geoscape)

func _clear(node: Node) -> void:
	if node != null and is_instance_valid(node): node.queue_free()

# maillage geoscape de l'acte courant (déterministe = identique à celui rendu par Geoscape)
func _cur_geo() -> Geo:
	var g := Geo.new()
	g.generate(int(Run.camp.seed) ^ (int(Run.camp.act) * 97), int(Run.camp.act), int(Run.camp.want))
	return g

func _show_geoscape() -> void:
	if bool(Run.camp.get("done", false)): return _victory_screen()
	var raid_msg := _maybe_raid()
	var boss_revealed := _check_boss_unlock()
	geoscape = GeoscapeScene.instantiate()
	add_child(geoscape)
	geoscape.region_selected.connect(_on_region)
	_update_banner()
	if raid_msg != "": banner.text = raid_msg
	# narration : arrivée dans un acte (une fois), puis révélation du boss
	var act: int = int(Run.camp.act)
	var queue: Array = []
	if not (Run.camp.get("seenActs", []) as Array).has(act):
		Run.camp.seenActs.append(act); queue.append(_act_text(act, "arrive"))
	if boss_revealed: queue.append(_act_text(act, "boss"))
	if not queue.is_empty(): _play_text(queue, func(): pass)

# texte d'acte : override de la campagne scénarisée (camp.narr) sinon défaut Narrative.gd
func _act_text(act: int, key: String) -> String:
	var narr: Dictionary = Run.camp.get("narr", {})
	var a = narr.get(str(act), {})
	if typeof(a) == TYPE_DICTIONARY and a.has(key): return String(a[key])
	return Narrative.ACTS.get(act, {}).get(key, "...")

# ---------- lecteur de texte paginé ----------
var _txt_layer: CanvasLayer = null
var _txt_pages: Array = []
var _txt_idx := 0
var _txt_cb: Callable = func(): pass
func _play_text(texts, cb: Callable) -> void:
	var all: Array = texts if texts is Array else [texts]
	_txt_pages = []
	for t in all: _txt_pages.append_array(Narrative.pages(str(t)))
	_txt_idx = 0; _txt_cb = cb
	_txt_layer = CanvasLayer.new(); _txt_layer.layer = 30; add_child(_txt_layer)
	_render_text_page()

func _render_text_page() -> void:
	for c in _txt_layer.get_children(): c.queue_free()
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); _txt_layer.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.03, 0.03, 0.05, 0.94); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var rt := RichTextLabel.new(); rt.bbcode_enabled = true; rt.fit_content = true
	rt.position = Vector2(120, 200); rt.custom_minimum_size = Vector2(1040, 360)
	rt.add_theme_font_size_override("normal_font_size", 19); panel.add_child(rt)
	rt.text = _page_bbcode(_txt_pages[_txt_idx])
	var hint := Label.new(); hint.text = "[clic / Espace] suite  (%d / %d)" % [_txt_idx + 1, _txt_pages.size()]
	hint.position = Vector2(120, 580); hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65)); panel.add_child(hint)
	var btn := Button.new(); btn.text = "Suite"; btn.position = Vector2(120, 610); btn.pressed.connect(_text_next); panel.add_child(btn)

# « Nom: réplique » → nom en or ; sinon ligne simple
func _page_bbcode(page: String) -> String:
	var out: Array = []
	for raw in page.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty(): continue
		var ci := line.find(": ")
		if ci > 0 and ci <= 18 and not line.substr(0, ci).contains("  "):
			out.append("[color=#e0b341][b]%s[/b][/color] %s" % [line.substr(0, ci), line.substr(ci + 2)])
		else:
			out.append(line)
	return "\n\n".join(out)

func _text_next() -> void:
	_txt_idx += 1
	if _txt_idx >= _txt_pages.size():
		_clear(_txt_layer); _txt_layer = null
		var cb := _txt_cb; _txt_cb = func(): pass
		cb.call_deferred()   # hors du contexte du signal/bouton (sinon la suite casse en web)
	else:
		_render_text_page()

func _unhandled_input(e: InputEvent) -> void:
	if _txt_layer != null and ((e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
		or (e is InputEventKey and e.pressed and e.keycode == KEY_SPACE)):
		_text_next(); get_viewport().set_input_as_handled()

func _update_banner() -> void:
	var act: int = int(Run.camp.act)
	var title: String = String(Run.camp.get("title", ""))
	var prefix := (title + " — ") if title != "" else ""
	banner.text = "%s%s   |   missions %d   |   victoires %d   |   forges %d" % [
		prefix, ACT_NAME.get(act, "Acte %d" % act), int(Run.camp.missionN), int(Run.camp.winCount), int(Run.camp.get("forgeCount", 0))]

const Data := preload("res://rules/Data.gd")
var _sel_layer: CanvasLayer = null
var _pending := -1
var _sel_title := ""
var _sel_confirm: Callable = func(): pass
var _sel_cancel: Callable = func(): pass

# --- géoscape : choix d'une région → écran de sélection d'escouade ---
func _on_region(cell: int) -> void:
	_pending = cell
	var ginfo: Dictionary = geoscape.geo.info[cell]
	_sel_title = "Déploiement — %s  (%s, %d ennemis)" % [ginfo.name, ("BOSS" if ginfo.boss else "diff %d" % ginfo.diff), Run.mission_preview_enemies(ginfo)]
	_sel_confirm = _confirm_region
	_sel_cancel = _cancel_deploy
	_show_squad_select()

func _bar(frac: float, col: Color) -> Control:
	var bg := ColorRect.new(); bg.color = Color(0.17, 0.18, 0.23); bg.custom_minimum_size = Vector2(60, 8)
	var fg := ColorRect.new(); fg.color = col; fg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fg.size = Vector2(60.0 * clampf(frac, 0, 1), 8); fg.position = Vector2.ZERO
	bg.add_child(fg); return bg

func _show_squad_select() -> void:
	_sel_layer = CanvasLayer.new(); _sel_layer.layer = 20; add_child(_sel_layer)
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); _sel_layer.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.04, 0.04, 0.06, 1.0); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(dim)
	var box := VBoxContainer.new(); box.position = Vector2(60, 50); box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = _sel_title
	title.add_theme_font_size_override("font_size", 22); title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	box.add_child(title)
	var hint := Label.new(); hint.text = "Choisis jusqu'a %d soldats (clic pour selectionner). fat = fatigue, str = stress, PV au depart." % Run.SQUAD_MAX
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75)); box.add_child(hint)
	for m in Run.camp.roster:
		box.add_child(_member_row(m))
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 12); box.add_child(btns)
	var go := Button.new(); go.text = "Deployer"; go.pressed.connect(_fire_sel_confirm); btns.add_child(go)
	var back := Button.new(); back.text = "Retour"; back.pressed.connect(_fire_sel_cancel); btns.add_child(back)

func _fire_sel_confirm() -> void: _sel_confirm.call_deferred()
func _fire_sel_cancel() -> void: _sel_cancel.call_deferred()

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
	b.pressed.connect(_toggle_member.bind(String(m.name)))
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

func _toggle_member(nom: String) -> void:
	Run.toggle_select(nom); _refresh_select()

func _refresh_select() -> void:
	_clear(_sel_layer); _sel_layer = null
	_show_squad_select()

func _cancel_deploy() -> void:
	_clear(_sel_layer); _sel_layer = null; _pending = -1

func _confirm_region() -> void:
	if Run.camp.deploySel.is_empty(): return
	var cell := _pending; _pending = -1
	_clear(_sel_layer); _sel_layer = null
	Run.set_mission(cell, geoscape.geo.info[cell])
	_clear(geoscape); geoscape = null
	var intro := String(Run.mission.get("intro", ""))   # TON texte d'avant-mission
	if intro.strip_edges() != "": _play_text([intro], _launch_battle)
	else: _launch_battle()

func _launch_battle() -> void:
	battle = BattleScene.instantiate()
	add_child(battle)
	battle.mission_ended.connect(_on_mission_end)

# ---------- interpréteur de graphe de campagne (port de runNode) ----------
var _cur_node := {}
func _as_list(v) -> Array:
	return v if v is Array else String(v).split(",")

func _resume_node(id: String) -> void:
	_run_node(id)

func _run_node(id: String) -> void:
	var n: Dictionary = Run.node_by_id(id)
	if n.is_empty(): return _campaign_end("Campagne terminée.")
	Run.camp.nodeId = id
	if n.has("mortal"): Run.apply_mortal(_as_list(n.mortal))     # « son rôle est fait »
	if n.has("recruit"): Run.apply_recruit(n.recruit)            # renforts
	var t := String(n.get("type", "text"))
	match t:
		"text":
			Run.save_game()
			var txt := String(n.get("text", ""))
			var nxt := String(n.get("next", ""))
			if txt.strip_edges() == "": _run_node(nxt)
			else: _play_text([txt], _resume_node.bind(nxt))   # .bind() : fiable en export web (vs lambda capturée)
		"choice":
			Run.save_game(); _show_choice(n)
		"mission":
			_run_mission_node(n)
		_:
			_run_node(String(n.get("next", "")))   # geoscape/autre non géré en graphe → on enchaîne

func _node_label(n: Dictionary) -> String:
	if n.is_empty(): return "Suite"
	var t := String(n.get("type", ""))
	if t == "mission": return "Mission : " + String(n.get("mission", "mission"))
	if t == "choice": return String(n.get("title", "choix"))
	var tx := String(n.get("text", "")); return tx.substr(0, min(40, tx.length())) if tx != "" else "Suite"

func _show_choice(n: Dictionary) -> void:
	var lay := CanvasLayer.new(); lay.layer = 24; add_child(lay)
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); lay.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.03, 0.03, 0.05, 0.96); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var box := VBoxContainer.new(); box.position = Vector2(80, 150); box.add_theme_constant_override("separation", 12); panel.add_child(box)
	var t := Label.new(); t.text = String(n.get("title", "Quelle route ?"))
	t.add_theme_font_size_override("font_size", 23); t.add_theme_color_override("font_color", Color(1, 0.88, 0.5)); box.add_child(t)
	for opt in n.get("options", []):
		var oid := String(opt)
		var b := Button.new(); b.custom_minimum_size = Vector2(460, 0)
		b.text = _node_label(Run.node_by_id(oid))
		b.pressed.connect(_choose_option.bind(lay, oid))
		box.add_child(b)

func _choose_option(lay: CanvasLayer, oid: String) -> void:
	_clear(lay); _run_node.call_deferred(oid)

func _run_mission_node(n: Dictionary) -> void:
	_cur_node = n
	var mp = n.get("_map", {})
	Run.mission = {"seed": (int(Run.camp.seed) ^ String(n.get("id", "")).hash()) & 0x7fffffff | 1,
		"objective":"eliminate", "name":String(n.get("mission", "Mission")), "forge":false, "boss":false,
		"intro":String(n.get("intro", "")), "outro":String(n.get("outro", ""))}
	if typeof(mp) == TYPE_DICTIONARY and not mp.is_empty(): Run.mission["map"] = mp
	_sel_title = "Déploiement — " + String(n.get("mission", "Mission"))
	_sel_confirm = _confirm_node
	var self_id := String(n.get("id", ""))
	_sel_cancel = _cancel_node.bind(self_id)
	_show_squad_select()

func _cancel_node(id: String) -> void:
	_clear(_sel_layer); _sel_layer = null; _run_node.call_deferred(id)

func _confirm_node() -> void:
	if Run.camp.deploySel.is_empty(): return
	_clear(_sel_layer); _sel_layer = null
	var intro := String(Run.mission.get("intro", ""))
	if intro.strip_edges() != "": _play_text([intro], _launch_graph_battle)
	else: _launch_graph_battle()

func _launch_graph_battle() -> void:
	battle = BattleScene.instantiate(); add_child(battle)
	battle.mission_ended.connect(_on_graph_mission_end)

func _on_graph_mission_end(win: bool) -> void:
	var report: Dictionary = battle.build_report() if battle != null else {}
	if battle != null: Run.camp.potions = int(battle.potions)
	var deaths: Array = Run.resolve_node(win, report)
	Run.auto_promote()
	_clear(battle); battle = null
	var n: Dictionary = _cur_node
	var outro := String(Run.mission.get("outro", ""))
	var self_id := String(n.get("id", ""))
	var nxt := String(n.get("win", "")) if win else String(n.get("lose", ""))
	if outro.strip_edges() != "": _play_text([outro], _after_mission.bind(win, self_id, nxt))
	else: _after_mission(win, self_id, nxt)

func _after_mission(win: bool, self_id: String, nxt: String) -> void:
	if nxt == "":
		if win: _campaign_end("Campagne terminée — victoire !")
		else: _run_node(self_id)   # défaite sans branche → on rejoue le nœud
	else: _run_node(nxt)

func _campaign_end(msg: String) -> void:
	Run.camp.done = true; Run.save_game()
	banner.text = msg
	_victory_screen()

# --- issue de mission → progression → retour au territoire ---
func _on_mission_end(win: bool) -> void:
	var report: Dictionary = battle.build_report() if battle != null else {}
	if battle != null: Run.camp.potions = int(battle.potions)   # stock de soins restant
	var outro := String(Run.mission.get("outro", ""))           # TON texte de fin de mission
	var was_forge: bool = win and bool(Run.mission.get("forge", false))
	var was_boss: bool = bool(Run.mission.get("boss", false))
	var deaths: Array = Run.resolve_mission(win, report)
	_clear(battle); battle = null
	if win: _advance_if_boss()
	_show_geoscape()
	if was_forge:
		var fb: Dictionary = Run.camp.forgeBonus
		banner.text = Narrative.fmt(Narrative.MESSAGES.forge, {"thp": int(fb.hp), "tdmg": int(fb.dmg)})
	if not deaths.is_empty():
		banner.text = "+ " + ", ".join(deaths) + (" sont tombé·e·s." if deaths.size() > 1 else " est tombé·e.")
	if outro.strip_edges() != "": _play_text([outro], func(): pass)   # débrief narratif (par-dessus)
	if not (Run.camp.get("pendingPromos", []) as Array).is_empty():
		_show_promotions()
	elif win and not was_boss and not bool(Run.camp.get("done", false)):
		_maybe_offer_bonus()

# ---------- mission bonus enchaînée ----------
func _maybe_offer_bonus() -> void:
	if Run.ready_members().is_empty() or randf() >= 0.35: return
	var lay := CanvasLayer.new(); lay.layer = 22; add_child(lay)
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); lay.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0.04, 0.04, 0.06, 0.92); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var box := VBoxContainer.new(); box.position = Vector2(80, 180); box.add_theme_constant_override("separation", 14); panel.add_child(box)
	var t := Label.new(); t.add_theme_font_size_override("font_size", 21); t.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	t.text = "Une occasion se presente : une cible de plus, a decouvert.\nL'escouade est deja eprouvee — pousser plus loin ?\nReussir rapporte un soin ; echouer peut couter des soldats."
	box.add_child(t)
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 12); box.add_child(btns)
	var yes := Button.new(); yes.text = "Tenter la mission bonus"; btns.add_child(yes)
	var no := Button.new(); no.text = "Rentrer au camp"; btns.add_child(no)
	yes.pressed.connect(_bonus_yes.bind(lay))
	no.pressed.connect(_clear.bind(lay))

func _bonus_yes(lay: CanvasLayer) -> void:
	_clear(lay); _launch_bonus.call_deferred()

func _launch_bonus() -> void:
	Run.set_bonus_mission()
	_clear(geoscape); geoscape = null
	battle = BattleScene.instantiate(); add_child(battle)
	battle.mission_ended.connect(_on_bonus_end)

func _on_bonus_end(win: bool) -> void:
	var report: Dictionary = battle.build_report() if battle != null else {}
	if battle != null: Run.camp.potions = int(battle.potions)
	var deaths: Array = Run.resolve_bonus(win, report)
	_clear(battle); battle = null
	_show_geoscape()
	if win: banner.text = "Mission bonus reussie — +1 soin."
	else: banner.text = "Mission bonus echouee — repli."
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
		b.pressed.connect(_pick_promo.bind(String(p.name), slot))
		box.add_child(b)

func _pick_promo(nom: String, slot: String) -> void:
	Run.choose_promo(nom, slot); _show_promotions()

func _perk_desc(perk: Dictionary) -> String:
	if perk.has("abil"): return "capacité : " + str(perk.abil)
	var mod: Dictionary = perk.get("mod", {})
	var parts := []
	for k in mod: parts.append("+%d %s" % [int(mod[k]), k])
	return ", ".join(parts) if not parts.is_empty() else "bonus"

# le boss (région verrouillée) s'ouvre quand le front a nettoyé assez de régions
# renvoie true la première fois qu'il est révélé (déclenche la narration boss)
func _check_boss_unlock() -> bool:
	var g := _cur_geo()
	var states: Dictionary = Run.camp.geoStates
	var cleared := 0; var total := 0; var boss := -1
	for cell in g.info:
		total += 1
		if bool(g.info[cell].boss): boss = cell
		elif String(states.get(cell, "available")) == "cleared": cleared += 1
	if boss >= 0 and String(states.get(boss, "")) == "locked" and cleared >= int(ceil((total - 1) * 0.6)):
		states[boss] = "available"
		var seen: Array = Run.camp.get("seenBoss", [])
		if not seen.has(int(Run.camp.act)): seen.append(int(Run.camp.act)); Run.camp.seenBoss = seen; return true
	return false

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
		Run.camp.want = Run.want_for_act(act + 1)   # taille d'acte (surchargée par campagne scénarisée)
		Run.camp.geoStates = {}        # nouveau territoire pour le nouvel acte
		Run.camp.lastAttack = -99

# événement rare : une région nettoyée est réattaquée (à reprendre) — renvoie le message ou ""
func _maybe_raid() -> String:
	if int(Run.camp.missionN) - int(Run.camp.get("lastAttack", -99)) < 3: return ""
	if randf() > 0.14: return ""
	var g := _cur_geo()
	var states: Dictionary = Run.camp.geoStates
	var pool := []
	for cell in g.info:
		if String(states.get(cell, "")) == "cleared" and not bool(g.info[cell].boss): pool.append(cell)
	if pool.is_empty(): return ""
	var hit: int = pool[randi() % pool.size()]
	states[hit] = "attacked"
	Run.camp.lastAttack = int(Run.camp.missionN)
	return Narrative.fmt(Narrative.MESSAGES.attack, {"region": g.info[hit].name})

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
