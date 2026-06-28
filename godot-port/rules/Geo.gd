# Geoscape procédural (port de genGeoMap) : maillage Voronoï grossier annoté
# (camp central, difficulté par distance, forge, boss) + accessibilité (front).
class_name Geo
extends RefCounted

const VMesh := preload("res://rules/Mesh.gd")
const GEO_W := 820.0
const GEO_H := 620.0

const NAMES := {
	1:["Bois brûlé","Gué de l'aval","Carrière noyée","Hameau muet","Tourbière","Crête venteuse","Vieux moulin","Lisière grise","Ravin","Tertre","Saulaie","Fondrière","Combe","Friche","Aulnaie","Layon","Guéret","Marécage","Sente creuse","Pâture"],
	2:["Marais blême","Verrière brisée","Tour engloutie","Dédale noyé","Ravins de cendre","Pont rompu","Crevasse","Sente grise","Brèche","Spire noire","Caldeira","Estran gris","Vasière","Gouffre","Récif sec","Cendrier","Étier mort","Noue","Suintement","Faille mineure"],
	3:["Anse calcinée","Verse noire","Antre","Vallée close","Os blanchis","Schiste","Maelström","Brisure","Galerie","Ossuaire","Bief","Crassier","Plaie","Abîme","Terril","Lande grise","Goulet","Vortex","Faille mère","Carrière haute"] }
const BOSS := {1:"Bastion", 2:"Verrou de la Faille", 3:"Cœur de la Faille"}
const FORGE := {1:"Vieille forge", 2:"Forge engloutie", 3:"Forge du gouffre"}

var mesh: VMesh
var camp := -1
var info := {}        # cell -> {name, diff, forge, boss}

func generate(seed_value: int, act: int, want: int) -> void:
	var target := want + 1
	var g := max(48.0, round(sqrt(GEO_W * GEO_H / float(target)) * 0.92))
	mesh = VMesh.new()
	for it in 40:
		mesh.generate(seed_value, GEO_W, GEO_H, g, 28.0)
		var n := mesh.cells.size()
		if n > target + 1: g = round(g * 1.04)
		elif n < target: g = round(g * 0.96)
		else: break
	# tri par distance au centre → camp central, régions du plus proche au plus loin
	var cx0 := GEO_W * 0.5; var cy0 := GEO_H * 0.5
	var order := []
	for c in mesh.cells: order.append({"i":c.id, "d":Vector2(c.cx - cx0, c.cy - cy0).length()})
	order.sort_custom(func(a, b): return a.d < b.d)
	camp = order[0].i
	var regs := order.slice(1)
	var maxr := regs.size()
	var rng := VMesh.Rng.new(seed_value ^ 0x9e37)
	var names: Array = NAMES[act].duplicate()
	for k in range(names.size() - 1, 0, -1):
		var j := int(rng.next() * (k + 1)); var tmp = names[k]; names[k] = names[j]; names[j] = tmp
	var forge_rank := clampi(int(round(maxr * 0.62)), 1, max(1, maxr - 2))
	info = {}
	for rank in maxr:
		var cell: int = regs[rank].i
		var is_boss := rank == maxr - 1
		var d := 5 if is_boss else clampi(1 + int(float(rank) / max(1, maxr - 1) * 3.999), 1, 4)
		var nm := ""
		var forge := false; var boss := false
		if is_boss: nm = BOSS[act]; boss = true
		elif rank == forge_rank: nm = FORGE[act]; forge = true; d = clampi(d, 3, 4)
		else: nm = names[rank % names.size()]
		info[cell] = {"name":nm, "diff":d, "forge":forge, "boss":boss}

# régions accessibles : adjacentes au camp ou à une région déjà nettoyée (front)
func accessible(states: Dictionary) -> Dictionary:
	var controlled := {camp: true}
	for cell in info:
		if states.get(cell, "available") == "cleared": controlled[cell] = true
	var acc := {}
	for cell in info:
		var st: String = states.get(cell, "available")
		if st == "attacked": acc[cell] = true; continue
		if st == "cleared" or st == "locked": continue
		for nb in mesh.cells[cell].nb:
			if controlled.has(nb): acc[cell] = true; break
	return acc
