# Combat — port fidèle de index.html (chance/doAttack/flank/muretCover/adjacent/inRange).
# Opère sur des dicts (mesh + tableau d'unités). Hasard gameplay = randf() (non déterministe).
class_name Combat
extends RefCounted

const Data := preload("res://rules/Data.gd")
const HEIGHT_BONUS := Data.HEIGHT_BONUS
const COVER_PEN := Data.COVER_PEN
const DEF_BRACE := Data.DEF_BRACE

static func _norm(a: float) -> float:
	while a <= -PI: a += TAU
	while a > PI: a -= TAU
	return a

static func _share_edge(mesh, a: int, b: int) -> bool:
	var pa: Array = mesh.cells[a].poly; var pb: Array = mesh.cells[b].poly
	var n := 0
	for p in pa:
		for q in pb:
			if abs(p.x - q.x) < 1.5 and abs(p.y - q.y) < 1.5: n += 1; break
		if n >= 2: return true
	return false

static func adjacent(mesh, a: int, b: int) -> bool:
	if mesh.hops(a, b) <= 1 or _share_edge(mesh, a, b): return true
	var A = mesh.cells[a]; var B = mesh.cells[b]
	if A.nb.is_empty(): return false
	var s := 0.0
	for nb in A.nb: s += Vector2(mesh.cells[nb].cx - A.cx, mesh.cells[nb].cy - A.cy).length()
	var avg: float = s / A.nb.size()
	return Vector2(B.cx - A.cx, B.cy - A.cy).length() <= avg * 1.6

static func in_range(mesh, att, tgt, m: String) -> bool:
	var w = att.w.get(m)
	if w == null: return false
	if w.type == "ranged":
		return mesh.hops(att.cell, tgt.cell) <= (int(w.range) + int(att.get("rangeBonus", 0))) and mesh.los(att.cell, tgt.cell)
	return adjacent(mesh, att.cell, tgt.cell)

static func flank_of(mesh, att, tgt) -> String:
	var diff := abs(_norm(atan2(mesh.cells[att.cell].cy - mesh.cells[tgt.cell].cy, mesh.cells[att.cell].cx - mesh.cells[tgt.cell].cx) - float(tgt.facing)))
	return "back" if diff > 2.2 else ("side" if diff > 1.0 else "front")

static func muret_cover(mesh, tgt, att) -> int:
	var T = mesh.cells[tgt.cell]; var A = mesh.cells[att.cell]
	var av := Vector2(A.cx - T.cx, A.cy - T.cy); av = av.normalized() if av.length() > 0.001 else Vector2(1, 0)
	var best := 0.0
	for nb in T.nb:
		if not mesh.wall_between(tgt.cell, nb): continue
		if T.elev > mesh.cells[nb].elev: continue
		var dv := Vector2(mesh.cells[nb].cx - T.cx, mesh.cells[nb].cy - T.cy); dv = dv.normalized() if dv.length() > 0.001 else Vector2(1, 0)
		var align := av.dot(dv)
		if align <= 0: continue
		best = max(best, (COVER_PEN / 2.0) * align)
	return int(round(best))

static func chance(mesh, units: Array, att, tgt, m: String) -> int:
	var w = att.w[m]
	var cover := 0
	if w.type == "ranged":
		if mesh.cells[tgt.cell].terr == "cover": cover = COVER_PEN
		cover = max(cover, muret_cover(mesh, tgt, att))
		for a in units:
			if a.hp > 0 and a.team == tgt.team and a != tgt and a.get("wallStance", false) and adjacent(mesh, a.cell, tgt.cell):
				cover = max(cover, int(round(COVER_PEN * 0.5)))
	var dh := clampi(mesh.cells[att.cell].elev - mesh.cells[tgt.cell].elev, -3, 3) * HEIGHT_BONUS
	var pb := 0
	if w.type == "ranged": pb = Data.PB.get(mesh.hops(att.cell, tgt.cell), 0)
	var def := DEF_BRACE if tgt.get("bracing", false) else 0
	return clampi(int(round(w.aim + int(att.get("aimBonus", 0)) - cover + dh - pb - def)), 5, 95)

# Renvoie {hit, result, dmg, killed, txt, target} ; mute l'état (hp, ap, ammo, facing).
static func do_attack(mesh, units: Array, att, tgt, m: String, reaction := false) -> Dictionary:
	# Bouclier protecteur : un garde adjacent intercepte un coup visant un joueur
	if not reaction and tgt.team == "player" and not tgt.get("protect", false):
		for o in units:
			if o != tgt and o.team == "player" and o.hp > 0 and o.get("protect", false) and not o.get("reacted", false) and adjacent(mesh, o.cell, tgt.cell):
				o.reacted = true; tgt = o; break
	var w = att.w[m]
	att.facing = atan2(mesh.cells[tgt.cell].cy - mesh.cells[att.cell].cy, mesh.cells[tgt.cell].cx - mesh.cells[att.cell].cx)
	if not reaction: att.ap = 0
	if w.type == "ranged" and att.has("ammo"): att.ammo -= 1
	var ch: int = max(5, chance(mesh, units, att, tgt, m) - (15 if reaction else 0))
	var hit := randf() * 100.0 < ch
	var back := flank_of(mesh, att, tgt) == "back"
	var res := {"hit":hit, "result":"miss", "dmg":0, "killed":false, "txt":"raté", "target":tgt}
	if not hit:
		pass
	elif not back and int(tgt.get("shieldBlock", 0)) > 0 and randf() * 100.0 < int(tgt.shieldBlock):
		res.result = "blocked"; res.txt = "bloqué"
	elif not back and w.type == "melee" and int(tgt.get("parry", 0)) > 0 and randf() * 100.0 < int(tgt.parry):
		res.result = "blocked"; res.txt = "paré"
	else:
		res.result = "hit"
		var dmg: int = w.dmg_min + (randi() % (w.dmg_max - w.dmg_min + 1)) + int(att.get("dmgBonus", 0))
		if w.has("flank") and w.type == "melee":
			var f := flank_of(mesh, att, tgt)
			if f == "back": dmg += int(w.flank.back)
			elif f == "side": dmg += int(w.flank.side)
		if att.team == "enemy": dmg = max(1, dmg - 1)
		tgt.hp -= dmg
		res.dmg = dmg
		if tgt.hp <= 0: tgt.hp = 0; res.killed = true
		res.txt = "touché %d" % dmg
	return res

const ENEMY_VIS := 7
const SLEEP_VIS := 4

# espérance de tir depuis une case quelconque (0 si hors portée / sans vue) — pour l'IA
static func shot_from(mesh, units: Array, att, from_cell: int, tgt, m: String) -> int:
	var w = att.w.get(m)
	if w == null: return 0
	if w.type == "ranged":
		if mesh.hops(from_cell, tgt.cell) > (int(w.range) + int(att.get("rangeBonus", 0))) or not mesh.los(from_cell, tgt.cell): return 0
	elif mesh.hops(from_cell, tgt.cell) > 1:
		return 0
	var ghost := {"cell":from_cell, "w":att.w, "team":att.team, "aimBonus":att.get("aimBonus", 0), "rangeBonus":att.get("rangeBonus", 0)}
	return chance(mesh, units, ghost, tgt, m)

# un ennemi voit-il un joueur ? portée selon éveil + LdV + cône (furtif = cône avant ; normal = hors angle mort arrière)
static func enemy_sees_p(mesh, e, p) -> bool:
	if p.get("hidden", false): return false
	var vis := SLEEP_VIS if e.get("asleep", false) else ENEMY_VIS
	if mesh.hops(e.cell, p.cell) > vis or not mesh.los(e.cell, p.cell): return false
	var fl := flank_of(mesh, p, e)
	return (fl == "front") if p.get("stealth", false) else (fl != "back")
