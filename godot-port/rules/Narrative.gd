# Textes narratifs / macro du geoscape (port de GEO_TXT_DEFAULTS d'index.html).
# PLACEHOLDERS éditables : la prose finale est écrite par l'auteur du jeu, pas générée.
# Pages séparées par une ligne « _ » ; « Nom: réplique » → le nom est mis en avant.
class_name Narrative
extends RefCounted

const MESSAGES := {
	"attack": "/!\\ {region} est attaquee ! Reprends-la avant qu'elle ne tombe — sans elle, la route se coupe.",
	"forge": "Forge liberee — l'escouade gagne +3 PV et +1 degat (cumule : +{thp} PV / +{tdmg} degats). En reponse, l'ennemi resserre ses rangs.",
	"actEndWin": "Region securisee. L'acte s'acheve.",
	"clickLocked": "region coupee du camp — libere d'abord un chemin",
}

const ACTS := {
	1: {
		"arrive": "La Marche de Velhaur s'etend devant vous.\n_\n[... ce qu'on vous a dit que vous veniez faire ...]",
		"forge": "Une vieille forge dort sous la region.\n_\n[... la remettre en marche armerait mieux l'escouade ...]",
		"boss": "Le Bastion verrouille la Marche.\n_\n[... le prendre ouvre la suite ...]",
	},
	2: {
		"arrive": "La Faille s'ouvre sous le territoire.\n_\n[... la corruption, et ceux qui l'ont choisie ...]",
		"forge": "Une forge engloutie peut encore servir.\n_\n[... a quel prix ...]",
		"boss": "Le Verrou de la Faille barre la route du Coeur.\n_\n[... il faut le briser ...]",
	},
	3: {
		"arrive": "Le dernier territoire — la ou la Faille bat le plus fort.\n_\n[... presque au Coeur ...]",
		"forge": "La forge du gouffre, ultime atelier.\n_\n[... un dernier renfort ...]",
		"boss": "Le Coeur de la Faille bat devant vous.\n_\n[... l'etouffer sous l'otataral ...]",
	},
}

static func fmt(s: String, vars: Dictionary = {}) -> String:
	for k in vars: s = s.replace("{%s}" % k, str(vars[k]))
	return s

# découpe le texte en pages (séparateur : une ligne « _ »)
static func pages(text: String) -> Array:
	var out: Array = []; var buf: Array = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line == "_":
			if not buf.is_empty(): out.append("\n".join(buf)); buf = []
		else:
			buf.append(raw)
	if not buf.is_empty(): out.append("\n".join(buf))
	if out.is_empty(): out.append("...")
	return out
