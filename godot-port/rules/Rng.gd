# Réplique exacte de mk() du jeu JS (Mulberry32, arithmétique 32 bits).
# Garantit une génération procédurale identique au moteur d'origine (test croisé).
class_name Rng
extends RefCounted

var _s: int

func _init(seed_value: int) -> void:
	_s = seed_value & 0xffffffff

static func _imul(a: int, b: int) -> int:
	return (a * b) & 0xffffffff           # = Math.imul (multiplication 32 bits)

func next() -> float:                     # ∈ [0,1)
	_s = (_s + 0x6D2B79F5) & 0xffffffff
	var t := _imul(_s ^ (_s >> 15), _s | 1)
	t = (_imul(t ^ (t >> 7), t | 61) + t) ^ t
	t &= 0xffffffff
	return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
