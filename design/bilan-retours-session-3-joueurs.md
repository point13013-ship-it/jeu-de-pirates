# Bilan : retours de la session à 3 joueurs (nuit du 13/11/2026)

Plan d'origine et réponses de Jimmy : `plan-retours-session-3-joueurs.md`. Détail technique : `refonte-journal.md`.
Tout est commité en local sur `feature/refonte-gameplay`, rien n'est poussé ni publié. Protocole réseau 14 : tous les joueurs
devront mettre à jour. Tests : tous passent, sauf `test_town` (« 11 habitants au lieu de 10 », échec antérieur).

Presque tous les réglages sont dans `src/game_config.gd`, section « Retours de la session à 3 joueurs » en fin de fichier.

## Ce qui est fait, et comment le tester

| Lot | Fait | Comment tester en jeu |
|---|---|---|
| 1 Voiles, échelles, pavillon | Voile qui s'envole, vergues qui suivent les voiles, focs sur leurs étais, butée à 55°, échelles de coque posées sur la coque, crâne du pavillon | Hisser et affaler dix fois ; tourner les vergues à fond ; monter par les échelles ; regarder le pavillon doré |
| 2 Personnages, rendu | Pirate caché en vraies couleurs, pas visibles de face et de dos (y compris coffre en main), bicorne recalé, cercle de l'ancre, mer étendue depuis la vigie, brume sans traînées | Passer derrière une maison ; marcher vers la caméra avec un coffre ; parler à Armand ; monter à la vigie |
| 3 Collisions, multijoueur, naufrage | Nageur repoussé par les coques ennemies, sortie de l'eau sur les plages, canons des alliés qui tournent, indication et portée pour hisser un coéquipier, trésors du bord à la dérive au naufrage | À deux : viser au canon, nager près du bord (E pour hisser), couler avec des trésors à bord |
| 4 Navigation, météo | Barre lourde et inertie, ancre progressive, calmes et sautes de vent, arc des canons à 100°, portées, météo plus clémente | Virer de bord à pleine vitesse ; jeter l'ancre lancé ; viser au canon vers l'avant |
| 5 Combat, PNJ | Mobs renforcés, plus de « stun » par balle, précision en course et en saut, vitesse en portant, dégâts visibles des ennemis, équipages par rang, **abordage** | À la nage près de l'échelle d'un ennemi : E. Abattre le timonier, E au cabestan, Espace pour plonger |
| 6 Interactions | Postes bloqués les mains prises, clic gauche ou droit pour poser, échelle de mât à la main (Z / S), saut depuis la vigie, vigie dézoomée | Porter un coffre et essayer la barre ; monter au mât en s'arrêtant ; Espace dans le nid |
| 7 Coffre du bateau | Sac limité à 10 planches et 10 boulets, coffre commun tenu par l'hôte, réparation avec une planche du sac | E au coffre à boulets : clic pour ranger ou prendre, Maj + clic pour tout |
| 8 Bateau | Skins masqués, barre plus petite, trésors posés sur le pont, cale en trois pièces avec hublots, porte arrière et balcon praticable | Poser un coffre sur le pont (clic) et le reprendre (E) ; descendre dans la cale ; sortir sur le balcon par la cabine |
| 9 Haute ville | Maisons droites, fond aéré, bords solides | Monter par la porte des remparts |
| 10 Audio | Tromblon (prises faibles retirées), fusil refait, pluie -50 % avec accalmies et curseur, écoper et réparer variés, barre adoucie, volume des morceaux varié | Tirer vingt fois au tromblon ; attendre une averse ; réglages (Échap) : curseur « Pluie » |
| 11 Interface | HUD épuré, « [E] … » sous le centre, réputation au gain et dans le sac, boussole redessinée (seulement en main : B), pseudo à la nage, sirène qui s'en va, curseur du jeu | Jouer cinq minutes sans bandeau ; B pour la boussole ; Tab pour le sac |

## Refonte graphique reprise après les lots

| Point | Fait | Comment le voir |
|---|---|---|
| Herbe des îles | Taches aux contours souples (elles étaient carrées), verts de la palette v1 | Débarquer sur une île |
| Rivage | La houle s'apaise près des îles et ne traverse plus l'eau claire ; bord de l'eau claire irrégulier, sans trait | Longer une île en bateau : le bateau tangue moins près du bord |
| Menu principal | Coucher de soleil en gros pixels, pirate sur un ponton | Lancer le jeu |

Réglages : houle au bord d'une île 100 % → 20 % (), reprise sur 30 m ().
Reste de la refonte : silhouettes d'îles (falaises, épaves, ruines), menus de pause, de boutique et de création du pirate,
sillage persistant, reflets des lanternes.

## Ce qui n'est pas fait, ou pas comme demandé

- **Trésors : apparence.** Trois pistes proposées dans le plan (lot 9), aucune appliquée : il faut en choisir une.
- **Menu des coffres** : il liste « ton sac » puis « le coffre du bateau », en cases cliquables. Les deux panneaux côte à côte et le
  glisser-déposer ne sont pas faits.
- **Échelles de coque** : toujours automatiques (une seconde). Seule l'échelle de mât est passée à la main.
- **Abordage** : on monte seulement depuis l'eau (pas de saut de pont à pont, pas de crochet) ; les squelettes frappent ce qui
  passe à leur portée, ils ne poursuivent pas. Les armes servent sur notre pont, sans dégâts entre coéquipiers.
- **Nouvelles musiques et vrai nouveau son de fusil** : il faut des fichiers Epidemic Sound. Le fusil a été refait à partir des
  prises existantes (plus grave, écho).
- **« Finition de la coque »** et **« une voile traverse l'échelle qui sert à remonter à bord »** : à préciser. J'ai corrigé la
  voile qui passait dans l'échelle de mât ; je n'ai rien vu se croiser autour des échelles de coque.
- **Collision du « fond en herbe » de la ville basse** : je n'ai pas retrouvé l'endroit. Les bords du plateau de la haute ville
  sont maintenant solides ; si c'était ailleurs, il faut me dire où.

## À vérifier à plusieurs (je n'ai pu le tester que seul)

- Canons des alliés qui tournent, hisser un coéquipier, coffre du bateau à deux en même temps, trésors posés sur le pont.
- Coque ennemie contre la nôtre (on ne doit plus la traverser), abordage à plusieurs, timonier abattu vu par tous.
- Calmes et sautes de vent : fréquence et durée à ajuster après essai (`src/sea/wind_zones.gd`).

## Réglages à ajuster après essai (valeur avant → après)

| Réglage | Avant | Après |
|---|---|---|
| Barre, du centre à fond | 0,63 s | 1,6 s (`RUDDER_RATE`) |
| Inertie de virage | 0 | 1,2 s (`TURN_INERTIA`) |
| Puissance de virage | 100 % | 77 % (`PLAYER_TURN_SCALE`) |
| Freinage à l'ancre | x2,6 | x1,2 (`ANCHOR_BRAKE`) |
| Arc des canons | 360° | 100° (`GUN_ARC_DEG`) |
| Vitesse du boulet | 28 m/s | 31 m/s (`BALL_SPEED`) |
| Portée du crochet | 26 m | 22 m (`Hook.RANGE`) |
| Clair / brume / pluie / orage | 76 / 10 / 10 / 4 % | 83 / 8 / 6 / 3 % (`WEATHER_ODDS`) |
| PV des mobs | 2 / 3 / 4 / 8 / 18 | 3 / 5 / 6 / 11 / 24 (`data/enemies.json`) |
| Recul d'un mob touché par balle | 100 % | 30 % (`GUN_KNOCK_SCALE`) |
| Vie d'un squelette d'équipage, retour | — | 3 points, 30 s (`CREW_HP`, `CREW_RESPAWN`) |
| Sac : planches, boulets | 99 | 10 (`BAG_MAX`) |
| Zoom de la vigie | 0,45 | 0,30 (`NEST_ZOOM`) |
| Volume de la pluie | 100 % | 50 % (`RAIN_VOL`) |
| Portée pour hisser | 2,6 m | 4,5 m (`HOIST_REACH`) |
