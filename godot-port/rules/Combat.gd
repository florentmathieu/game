# Résolution de combat (port simplifié de chance()/doAttack() du jeu JS).
class_name Combat
extends RefCounted
const HEIGHT_BONUS := 6
const COVER_PEN := 30
const PB := {1:30, 2:15}   # pénalité à bout portant (tir)

# u = unité {cls, aim, cell, elev...}; renvoie 5..95
static func hit_chance(mesh, att, tgt) -> int:
	var ranged: bool = att.range > 0
	var cover := 0
	if ranged:
		if mesh.cells[tgt.cell].terr == "rough" or mesh.cells[tgt.cell].terr == "cover": cover = COVER_PEN
	var dh := clampi(mesh.cells[att.cell].elev - mesh.cells[tgt.cell].elev, -3, 3) * HEIGHT_BONUS
	var pb := 0
	if ranged:
		var h: int = mesh.hops(att.cell, tgt.cell)
		pb = PB.get(h, 0)
	return clampi(att.aim - cover + dh - pb, 5, 95)
