# ══════════════════════════════════════════════════════════════════
# texts/ — Textes narratifs de Cœur maillage
# ══════════════════════════════════════════════════════════════════

À QUOI ÇA SERT
  Un fichier .txt par moment de narration, modifiable indépendamment.
  Tu écris ici ; le câblage dans le jeu (events du geoscape, nœuds de
  campagne) se fait ensuite en pointant vers ces fichiers.

OÙ COMMENCER
  AVANCEMENT.txt ......... vue d'ensemble + cases à cocher de l'écriture.
  acte1/ , acte2/ ........ un fichier par mission (début ET fin séparés),
                           plus ouverture / transition / finale.
  Chaque fichier commence par un brief en commentaire (# ...) : rôle
  narratif, beat de l'allégorie, persos suggérés. Remplace les [...].

FORMAT DU LECTEUR DE TEXTE (déjà en place dans le jeu)
  _            une ligne contenant seulement « _ » = saut de page.
  Nom:         une ligne « Nom: réplique » affiche le nom en gras doré.
  …            une page « … » = temps d'attente / silence (sautable).
  # ...        lignes de commentaire (briefs) — à retirer avant câblage,
               ou à laisser tant que le fichier n'est pas branché.

CONVENTION DE NOMMAGE
  <ordre>-<region>-debut.txt   texte AVANT la mission (event « before »).
  <ordre>-<region>-fin.txt     texte APRÈS la mission (event « after »).
  Le préfixe numérique = ordre de lecture suggéré (par difficulté), pas
  un ordre imposé : le geoscape reste concurrent.

GEOSCAPE (carte stratégique) — textes éditables
  geoscape.json ......... TOUS les textes de la carte stratégique, au même
                          endroit : messages système (région attaquée, forge
                          libérée, prime, bannières, fin d'acte) ET narration
                          par acte (arrivée / avant la forge / avant le boss).
                          Le geoscape étant PROCÉDURAL (régions tirées au
                          hasard à chaque campagne), la narration y est par
                          ACTE, pas par région nommée. Rechargé à chaque
                          entrée sur la carte → édite et relance.

NOTE
  Les fichiers acte1/ et acte2/ par mission nommée ci-dessus servent pour des
  geoscapes FAITS-MAIN (éditeur). Le mode campagne procédural utilise
  geoscape.json. Les anciens fichiers du prototype anglais (Opening.txt,
  Mission1-*, Interlude*) restent comme référence de ton/format.
