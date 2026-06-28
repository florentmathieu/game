extends Node3D
# Carte stratégique 3D : régions Voronoï colorées par difficulté/état, camp, brouillard de front.
signal region_selected(cell)

const Geo := preload("res://rules/Geo.gd")
const S := 0.05
const Hh := 0.5          # épaisseur des tuiles geoscape

var geo: Geo
var states := {}
var cam: Camera3D
var pivot: Node3D
var hud: Label
var hover := -1
var _labels: Array = []
var _yaw := 0.5
var _dist := 56.0
var _dragging := false

func _ready() -> void:
	randomize()
	if Run.camp.is_empty(): Run.new_campaign()
	var act: int = Run.camp.act
	geo = Geo.new()
	geo.generate(int(Run.camp.seed) ^ (act * 97), act, int(Run.camp.want))
	geo.mesh.distort((act - 1) * 0.12)   # le territoire se tord d'acte en acte (la Faille s'étend)
	states = Run.camp.geoStates
	if states.is_empty():
		for cell in geo.info: states[cell] = ("locked" if geo.info[cell].boss else "available")
	_setup_world(); _build(); _setup_camera(); _refresh()

func _setup_world() -> void:
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6, 0.6, 0.65); env.ambient_light_energy = 1.1
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(30), 0); sun.light_energy = 1.3; add_child(sun)
	hud = Label.new(); hud.position = Vector2(14, 10); hud.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	var ci := CanvasLayer.new(); ci.add_child(hud); add_child(ci)
	_build_roster_panel(ci)

# panneau roster (gauche) : un membre par ligne, usure et état lisibles d'un coup d'œil
func _build_roster_panel(ci: CanvasLayer) -> void:
	var box := VBoxContainer.new(); box.position = Vector2(14, 44); box.add_theme_constant_override("separation", 2)
	var h := Label.new(); h.text = "— Escouade —"; h.add_theme_color_override("font_color", Color(0.88, 0.7, 0.4)); box.add_child(h)
	for m in Run.camp.get("roster", []):
		var ready: bool = Run.mem_ready(m)
		var tag := "[+]" if bool(m.dead) else ("[!]" if not ready else ("[*]" if bool(m.special) else "[ ]"))
		var l := Label.new()
		if bool(m.dead):
			l.text = "%s %s — tombe-e" % [tag, m.name]
			l.add_theme_color_override("font_color", Color(0.5, 0.45, 0.45))
		else:
			var dh: Dictionary = Run.mem_deploy_hp(m)
			l.text = "%s %s  PV %d/%d  fat %d  str %d" % [tag, m.name, dh.hp, dh.max, int(m.fatigue), int(m.stress)]
			l.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78) if ready else Color(0.75, 0.55, 0.4))
		box.add_child(l)
	ci.add_child(box)

func _diff_col(d: int) -> Color:
	return [Color(0.18,0.49,0.31), Color(0.37,0.54,0.21), Color(0.54,0.49,0.18), Color(0.61,0.35,0.15), Color(0.61,0.23,0.16)][clampi(d - 1, 0, 4)]

func _cell_col(cell: int) -> Color:
	if cell == geo.camp: return Color(0.42, 0.33, 0.16)
	var st: String = states.get(cell, "available")
	if st == "attacked": return Color(0.69, 0.23, 0.16)
	if st == "cleared": return Color(0.22, 0.34, 0.5)
	if st == "locked": return Color(0.2, 0.2, 0.22)
	return _diff_col(geo.info[cell].diff)

func _build() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in geo.mesh.cells:
		var col := _cell_col(c.id); var p: Array = c.poly; var ctr := Vector3(c.cx * S, Hh, c.cy * S)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(ctr)
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(Vector3(b.x * S, Hh, b.y * S))
			st.set_normal(Vector3.UP); st.set_color(col); st.add_vertex(Vector3(a.x * S, Hh, a.y * S))
		var side := col.darkened(0.4)
		for k in p.size():
			var a: Vector2 = p[k]; var b: Vector2 = p[(k + 1) % p.size()]
			var ta := Vector3(a.x*S,Hh,a.y*S); var tb := Vector3(b.x*S,Hh,b.y*S); var ba := Vector3(a.x*S,0,a.y*S); var bb := Vector3(b.x*S,0,b.y*S)
			var nd := (Vector2((a.x+b.x)/2,(a.y+b.y)/2) - Vector2(c.cx,c.cy)).normalized()
			for v in [ta,bb,tb,ta,ba,bb]:
				st.set_normal(Vector3(nd.x,0,nd.y)); st.set_color(side); st.add_vertex(v)
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.roughness = 0.9
	st.set_material(mat); var mi := MeshInstance3D.new(); mi.mesh = st.commit(); add_child(mi)

func _setup_camera() -> void:
	pivot = Node3D.new(); pivot.position = Vector3(Geo.GEO_W * S * 0.5, 0, Geo.GEO_H * S * 0.5); add_child(pivot)
	cam = Camera3D.new(); cam.fov = 50; pivot.add_child(cam); _update_cam()

func _update_cam() -> void:
	var pitch := deg_to_rad(60.0)
	cam.position = Vector3(sin(_yaw)*cos(pitch)*_dist, sin(pitch)*_dist, cos(_yaw)*cos(pitch)*_dist)
	cam.look_at(pivot.global_position, Vector3.UP)

func _pick(screen: Vector2) -> int:
	var from := cam.project_ray_origin(screen); var dir := cam.project_ray_normal(screen)
	var hit = Plane(Vector3.UP, Hh).intersects_ray(from, dir)
	if hit == null: return -1
	return geo.mesh.cell_at(hit.x / S, hit.z / S)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT: _dragging = e.pressed
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed: _dist = max(24, _dist-4); _update_cam()
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed: _dist = min(110, _dist+4); _update_cam()
		elif e.button_index == MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
	elif e is InputEventMouseMotion:
		if _dragging: _yaw -= e.relative.x*0.01; _update_cam()
		else: var h := _pick(e.position); if h != hover: hover = h; _refresh()

# rotation clavier fluide : pivote le territoire tant que Q/E (ou ←/→) est tenue
func _process(delta: float) -> void:
	if cam == null: return
	var d := 0.0
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_LEFT): d -= 1.0
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_RIGHT): d += 1.0
	if d != 0.0: _yaw += d * 1.8 * delta; _update_cam()

func _click(screen: Vector2) -> void:
	var cell := _pick(screen)
	if cell < 0 or cell == geo.camp or not geo.info.has(cell): return
	var acc := geo.accessible(states)
	if not acc.has(cell): hud.text = "Région coupée du camp — libère d'abord un chemin"; return
	region_selected.emit(cell)

func _refresh() -> void:
	for l in _labels: l.queue_free()
	_labels.clear()
	var acc := geo.accessible(states)
	for c in geo.mesh.cells:
		var cell: int = c.id; var pos := Vector3(c.cx*S, Hh+0.1, c.cy*S)
		var nm := ""; var sub := ""
		if cell == geo.camp: nm = "Camp"
		elif geo.info.has(cell):
			var st: String = states.get(cell, "available")
			nm = geo.info[cell].name
			if st == "cleared": sub = "pris"
			elif st == "locked": sub = "?"
			elif geo.info[cell].forge: sub = "FORGE " + "*".repeat(geo.info[cell].diff)
			else: sub = "*".repeat(geo.info[cell].diff)
		var lab := Label3D.new(); lab.text = nm + ("\n" + sub if sub != "" else "")
		lab.font_size = 64; lab.outline_size = 10; lab.pixel_size = 0.022
		lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lab.no_depth_test = true; lab.render_priority = 2
		lab.modulate = Color(1,1,1) if acc.has(cell) or cell == geo.camp or states.get(cell,"")=="cleared" else Color(0.6,0.6,0.65)
		if cell == hover and acc.has(cell): lab.modulate = Color(1, 0.9, 0.4)
		lab.position = pos; add_child(lab); _labels.append(lab)
	var front := acc.size()
	hud.text = "ACTE %d — territoire (%d régions sur le front)   |   [clic] région  [clic-droit]/[Q/E]/[←→] pivoter  [molette] zoom" % [Run.camp.act, front]
