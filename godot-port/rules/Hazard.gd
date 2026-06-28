# Hasard de GAMEPLAY (tirs, dégâts, stun, dispersion) — RNG partagé seedable.
# Seedé par mission → combat reproductible (parité avec le RND seedé d'index.html).
# Distinct du Rng de génération (maillage) ; ici c'est le hasard tactique.
class_name Hazard
extends RefCounted

static var _rng := RandomNumberGenerator.new()

static func seed_with(s: int) -> void:
	_rng.seed = s

static func randomize_now() -> void:
	_rng.randomize()

static func f100() -> float:            # 0..100
	return _rng.randf() * 100.0

static func chance(pct: float) -> bool:  # vrai avec probabilité pct %
	return _rng.randf() * 100.0 < pct

static func rint(n: int) -> int:         # entier 0..n-1
	return _rng.randi() % max(1, n)
