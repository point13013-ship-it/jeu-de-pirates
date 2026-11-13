# Port-Cayonne : conception de la nouvelle ville (v3)

> 13/11/2026. Document de conception : **rien n'est construit**. Il sert à valider la ville sur le papier avant de modéliser.
> S'appuie sur `design/connaissances/02-direction-artistique-level-design.md` (§ 4 et 7), `03-rendu-godot.md` (§ 1 et 6),
> `design/bible-v2.md`, et sur une recherche complémentaire (ports réels, méthode, vie d'une ville) résumée au § 8.
> Maquette en plan : `plan-maquette.svg` (et `.png`), produite par `tools/art/town_plan_svg.py`.
> Le nom « Port-Cayonne » est provisoire (Cayona était la ville des flibustiers de la Tortue).

## 1. Ce qui ne va pas aujourd'hui (constats de Jimmy, 13/11)

| Constat | Cause |
|---|---|
| Maisons trop alignées, trop proches, trop rectilignes | La ville est une grille : trois rangées parallèles au quai, tous les bâtiments dans le même axe |
| Ville trop petite pour être « la » ville du jeu | 83 x 92 m, haute ville comprise |
| On traverse la colline, du linge, des éléments de décor | Les collisions sont des rectangles écrits à la main, à part du modèle : ce qui est ajouté au modèle n'a pas de collision |
| La colline « pas belle », un arbre qui vole, la finition du bord ouest | Décor posé par script sans contrôle du sol ni des bords |
| Pas de vraies sources de lumière, pas de reflets | Lanternes sans flaque de lumière au sol, fenêtres blanches uniformes, rien sur les pavés ni sur l'eau |
| On ne peut pas sortir de l'eau le long du quai | Aucune échelle sur les pontons ni sur les quais |
| Ville vide | 11 habitants fixes, 4 promeneurs, aucun son attaché à un lieu |

Conclusion : on ne corrige pas la ville actuelle, on la remplace. Elle reste en place tant que la nouvelle n'est pas jouable.

## 2. Programme : ce que la ville doit contenir

Fréquence = combien de fois par session un équipage y va. Plus c'est fréquent, plus c'est près du bateau.

| Service | PNJ | Fréquence | Distance voulue depuis le bateau |
|---|---|---|---|
| Vendre les trésors | Corbin le Receleur | à chaque retour | moins de 30 m (8 s à pied) |
| Tableau des quêtes | — | à chaque retour | moins de 30 m |
| Planches, boulets | Mère Pétronille (magasin général) | à chaque retour | moins de 35 m |
| Taverne (quêtes, équipage, musique) | Barnabé, Ysolde | souvent | sur la place du débarcadère |
| Changer de bateau | Mathurin (chantier naval) | rare | au bout du quai (60 m) |
| Voiles et couleurs | Ariane (voilerie) | rare | 40 à 60 m |
| Armes et dorure | Armand, Prosper | parfois | 40 m |
| Tenues | Gaspard (tailleur) | rare | place du marché (60 m) |
| Forge, lavoir, église, moulin, cimetière, fort, phare | figurants, quêtes | exploration | 60 à 130 m |

Règle : **tout ce qui sert à chaque retour tient dans le cercle des 30 m**. Le reste récompense la promenade.

## 3. Les idées qui structurent le plan

Tirées de nos recherches (Lynch, Alexander, Level Design Book, BotW) et des ports réels et de jeux :

1. **Une baie en croissant.** Le quai n'est plus une ligne droite : il suit la baie. Depuis le bateau on voit toute la
   ville en éventail, et rien n'est aligné sur la caméra.
2. **Le grand ponton dans l'axe de la Grand-Rue**, qui monte en serpentant du débarcadère au clocher.
3. **Trois repères hauts, jamais groupés** : le clocher (centre haut), le phare sur le cap (est, vu de la mer), le moulin
   sur sa colline (ouest). On se situe par triangulation.
4. **Le dénivelé raconte la ville** : cabanes de pêcheurs et chantier au ras de l'eau, taverne et marché au milieu,
   église et maison du gouverneur en haut (+3 à +5 m), derrière un mur de soutènement.
5. **Quatre quartiers reconnaissables** : le Bassin (pierre, cordages, entrepôts), le Marché (auvents rayés, façades
   pastel), les Cordiers (bois goudronné, ateliers), la Haute ville (chaux claire, jardins clos). Plus la Grève des
   pêcheurs (cabanes sur pilotis, filets) et le Cap (fort, phare).
6. **Trois largeurs de rue** : quai et Grand-Rue (6 à 7 m, quatre joueurs de front), rues (3,5 à 4 m), ruelles (1,8 m,
   raccourcis). Des boucles partout, aucun cul-de-sac sans récompense.
7. **Des places petites** (15 à 24 m), vivantes sur leurs bords, centre dégagé.
8. **Rien de droit** : chaque maison tourne de quelques degrés, les façades avancent ou reculent de 0,3 à 1,6 m, des
   trous entre les maisons (cours, jardins, passages).
9. **Un lieu à l'écart par chemin unique** (le moulin, puis la sortie vers la jungle) pour les quêtes.

## 4. La maquette en plan (v0)

Voir `plan-maquette.png`. Emprise : environ 215 x 125 m de terre, soit un peu plus de 3 fois la ville actuelle (dessinée en
pointillés blancs à la même échelle). 36 maisons de remplissage et 19 bâtiments nommés ; c'est un ordre de grandeur, les
maisons sont posées par le script pour juger la densité, pas une à une.

| Quartier | Contenu | Identité |
|---|---|---|
| **Le Bassin** | quai en arc, grand ponton (bateau de l'équipage), ponton des pêcheurs, ponton des marchands, cale du chantier ; place du Débarcadère avec receleur, tableau des quêtes, taverne, magasin général | pierre, bittes, caisses, grue, lanternes |
| **Quartier du Marché** (ouest) | place du marché et sa halle, tailleur, forge, armurier et doreur | auvents rayés, étals, poules, façades pastel |
| **Quartier des Cordiers** (est) | voilerie, entrepôts, chantier naval, fontaine | bois sombre, cordes qui sèchent, copeaux |
| **Grève des pêcheurs** (ouest) | cabanes, barques tirées au sec, filets, feu de camp | sable, bois flotté, pilotis |
| **Le Cap** (est, +3 m) | batterie du fort, phare | pierre grise, canons, pavillon |
| **Haute ville** (nord, +3 à +5 m) | église et clocher, maison du gouverneur, bains et lavoir, cimetière marin, maisons de notables | chaux, tuiles, jardins clos |
| **Colline du moulin** (nord-ouest) | moulin, point de vue, chemin de la jungle | herbe, vent |

Montées vers la haute ville : la Grand-Rue (rampe, pour tout le monde), deux escaliers en raccourci (ouest et est).

**Échelles pour sortir de l'eau** (carrés rouges) : deux par ponton (bout et milieu), une tous les 18 à 22 m le long du quai
et autour du cap, plus la grève où l'on sort à pied. Aucun point du quai n'est à plus de 11 m d'une sortie.

## 5. Métriques (à vérifier en marchant dans la maquette grise)

| Élément | Valeur | D'où ça vient |
|---|---|---|
| Marche, course | 3,6 m/s, environ 5,5 m/s | `WALK_SPEED`, sprint |
| Quai, Grand-Rue | 6 à 7 m | quatre joueurs de front |
| Rues, ruelles | 3,5 à 4 m ; 1,8 m | Level Design Book : un passage de deux largeurs de joueur paraît encore étroit |
| Porte | 1,25 x 2,5 m | Level Design Book |
| Étage | 3 m ; maisons de 1 à 3 étages | sprite de 1,8 m |
| Maison | 6 à 9,5 m de façade, 5,5 à 8 m de profondeur | lisible sous la caméra |
| Bateau au receleur, au tableau, au magasin | moins de 30 à 35 m | 8 à 10 s |
| Traversée complète (grève au phare) | environ 190 m | 50 s en marchant, 35 s en courant |
| Du bateau au clocher | environ 95 m | 26 s |
| Escaliers | 30 à 35° | Level Design Book |

## 6. Vie et son

Principe retenu de la recherche : **peu de vrais PNJ, beaucoup de figurants bon marché**, et on reproche à Skull and Bones
ses PNJ qui répètent le même geste. Budget proposé :

- **12 PNJ nommés** (les 11 actuels, plus un capitaine de port), avec un horaire à 3 ou 4 points sur la journée (comme
  Stardew Valley) : au comptoir le jour, à la taverne le soir.
- **20 à 25 figurants** en boucles courtes : dockers qui portent des caisses, forgeron qui martèle, lavandières, pêcheur qui
  ravaude un filet, ivrogne, quatre enfants qui courent en boucle (tracé rose), garde qui fait sa ronde (tracé bleu),
  prêtre, marchandes du marché. Animaux : poules, chats, un chien, mouettes sur les pieux.
- **Sons attachés aux lieux** (cercles orange du plan) : plein volume à 3 ou 4 m, inaudible vers 15 à 18 m. Musicien de la
  taverne, chants au feu de camp des pêcheurs le soir, marteau de la forge, scies du chantier, cris du marché, fontaine,
  ailes du moulin. Portée sur toute la ville : la cloche (aux heures) et le ressac. La musique du jeu baisse près d'un musicien.
- La nuit : moins de monde dehors, fenêtres allumées, taverne bruyante, veilleur avec une lanterne.

## 7. Lumière et rendu : ce qu'on peut faire, honnêtement

Tu demandes un rendu « comme le HDRP d'Unity » (sources de lumière, ombres, reflets). Ce que Godot permet **avec notre caméra** :

| Effet | Possible ? | Comment |
|---|---|---|
| Illumination globale temps réel (SDFGI, VoxelGI) | **non** | pas prise en charge avec une caméra orthographique (la nôtre) |
| Reflets en espace écran (SSR) | non pour l'eau | ne voit pas les transparents, rendus faux en orthographique |
| Vraies lanternes qui éclairent le sol et les murs | **oui** | OmniLight par lanterne (une trentaine sans ombre coûtent peu), 2 ou 3 lanternes clés avec ombres portées |
| Fenêtres allumées qui éclairent la rue | **oui** | vitres émissives et halo (glow), plus une tache de lumière chaude projetée au sol devant chaque fenêtre |
| Reflets des lanternes sur les pavés mouillés et sur l'eau | **oui, truqués** | traînées verticales additives sous chaque lumière, ondulées par l'eau ; pavés brillants après la pluie |
| Ombres du soleil et de la lune | **oui** | ombres dures déjà en place ; ajouter une vraie lune (lumière froide avec ombres) |
| Feux, braseros, forge | **oui** | lumière qui vacille, braises en particules |
| Brume du matin, rayons entre les maisons | oui, truqués | nappes et faisceaux en quads transparents |

Autrement dit : pas de lumière « physique » comme le HDRP, mais une nuit où chaque lanterne, chaque fenêtre et chaque feu
éclaire vraiment son coin, avec des reflets dessinés. C'est ce que font Eastward et Octopath Traveler.

## 8. Ce que la recherche complémentaire apporte

- **Ports réels** : Port Royal (2 000 bâtiments serrés sur 21 ha, forts aux extrémités, une taverne pour dix habitants),
  Nassau (ville le long de la rive, fort à un bout), la Tortue (fort sur un rocher qui domine la baie), La Havane et
  Carthagène (place principale au débarcadère, forts à l'entrée du port).
- **Jeux** : les avant-postes de Sea of Thieves ont tous le même programme (un exemplaire de chaque boutique, taverne,
  tableau sur le quai) ; Port Merrick ancre le quai avec une grande auberge et deux repères hauts de part et d'autre.
  Black Flag donne une identité tranchée à chaque ville (« en arrivant, tu sais où tu es »). Mêlée Island met le manoir à
  l'écart, par un seul chemin.
- **Méthode** (Level Design Book, World of Level Design) : références, programme, diagramme, repères, plan 2D, métriques,
  maquette grise, tests de parcours, services, éclairage, **puis seulement** passe d'art, habillage, vie, optimisation.
  « Une passe d'art prématurée fige les erreurs. »
- **Limites de cette recherche** : les plans détaillés des villes de jeux n'ont pas pu être vérifiés ; les chiffres de
  hub (temps de marche, nombre de PNJ, portée des sons) sont des recommandations, pas des normes publiées.

## 9. Les étapes, avec ce qu'on valide à chacune

| # | Étape | Ce que je livre | Tu valides |
|---|---|---|---|
| 0 | Conception (ce document) | programme, plan v0, questions | la forme générale, les quartiers, les réponses aux questions |
| 1 | Plan v1 | plan corrigé d'après tes retours, écrit dans un fichier de données (`data/town_plan.json`) : rues, places, bâtiments tournés, niveaux, échelles | le plan |
| 2 | Socle technique | collisions tirées **du plan** (bâtiments tournés, polygones, pentes), plus rien écrit à la main ; test automatique « rien ne se traverse, tout est atteignable » | rien à voir, mais plus de murs traversables |
| 3 | **Maquette grise jouable** | la ville en volumes gris dans le jeu : on marche, on monte, on tombe à l'eau, on remonte par les échelles ; services en place (boutiques, receleur, quêtes) | les distances, les vues, ce que la caméra cache ; chrono du bateau au receleur |
| 4 | Lumière sur la maquette grise | jour, coucher, nuit avec lanternes et fenêtres | on s'y retrouve la nuit |
| 5 | Kit de bâtiments | 8 à 10 maisons modulaires, toits, portes, volets, enseignes, en palette v1 | une rue témoin terminée |
| 6 | Passe d'art, quartier par quartier | Bassin, puis Marché, Cordiers, Haute ville, Grève, Cap | chaque quartier |
| 7 | Habillage et bordures | caisses, linge, étals, jardins, transitions entre matériaux | — |
| 8 | Vie | figurants, horaires, animaux, sons par lieu, musiciens | la ville n'a aucune zone muette ou vide |
| 9 | Optimisation, tests à plusieurs | images par seconde tenues à 4, tests, publication | — |

Les étapes 1 à 4 se font sans un seul bel objet : c'est voulu. L'ancienne ville reste jouable jusqu'à l'étape 6.

## 10. Décisions de Jimmy (13/11)

| Question | Décision |
|---|---|
| Forme | **Baie en croissant**, celle de la maquette |
| Ambiance | **Port caribéen coloré** |
| Boutiques | **Mixte.** Quelques vraies maisons où l'on entre (taverne, magasin général, tailleur), pour l'ambiance. Des **grandes tentes ouvertes sur la rue**, façon Sea of Thieves, où l'on voit l'intérieur sans entrer ni charger (receleur, armurier et doreur, voilerie). Des comptoirs et des halles (tableau des quêtes, forge, marché, chantier naval) |
| Modèles | Bâtiments, quais et relief par nos scripts Blender ; petits objets (tonneaux, caisses, étals, barques) depuis un kit libre CC0 repeint à notre palette. Pas de kit payant : le dépôt est public |
| Sortie de l'eau | Dans la nouvelle ville, on ne sort de l'eau que par une échelle ou par la grève (`LADDER_EXIT_REACH`) : le quai est trop haut |
| Publication | Publier dans le lanceur à chaque palier jouable, sans redemander |

### Retour de Jimmy sur la première maquette grise (13/11) : « des cubes qui s'empilent »

Le plan vu à plat paraissait aéré, la maquette en 3D non : les maisons se touchaient par les coins et montaient à 2 ou 3
étages, donc se cachaient les unes les autres sous la caméra. Même leçon que pour le bateau : **de la place pour circuler**.
Règles ajoutées, vérifiées par le test :

| Règle | Valeur |
|---|---|
| Écart minimal entre deux bâtiments fermés | 3 m (2,8 m contrôlés par le test) : une ruelle où l'on passe à deux |
| Écart autour d'un service ou d'un repère | 3,2 m |
| Recul d'un mur par rapport au bord d'une rue | 0,8 m au moins, aucun mur sur une rue |
| Hauteur des maisons | surtout rez-de-chaussée plus un étage (2,7 m par étage), toits plus bas ; les repères seuls dépassent |
| Densité | 36 maisons et 19 bâtiments nommés (au lieu de 54 + 19) : on resserrera à la main là où un quartier doit l'être |

## 11. Où on en est

- **Étape 1, plan v1 : fait.** `data/town_plan.json`, écrit par `tools/art/town_plan_svg.py` (ne pas le modifier à la main).
- **Étape 2, socle technique : fait.** `src/land.gd` lit le plan (`load_plan`) : sol en polygones, murs tournés, terrasses en
  polygones, rampes orientées, terre qui arrête les bateaux. Test : `tests/unit/test_town_v3.gd` (aucun bâtiment fermé ne se
  traverse, chaque rampe se monte et se redescend, receleur et magasin à moins de 35 m du bateau, une échelle à moins de 12 m
  de tout point du quai).
- **Étape 3, maquette grise jouable : première version.** `src/town/town_greybox.gd`. Essai : lancer le jeu avec `--town=v3`
  (ou `GameConfig.TOWN_V3`). Laiton = un service, blanc = un repère, carrés rouges = échelles. Les 11 habitants sont devant
  leur boutique, quatre promeneurs suivent les rues. Captures : `maquette-grise-vue-large.png`, `maquette-grise-quai.png`.
- **Étape 4, lumière : première version.** `src/town/town_lights.gd`. Lanternes le long des rues (une tous les 13 m sur le
  quai et la Grand-Rue, 21 m ailleurs, une au bout de chaque ponton, trois par place) : poteau, lanterne qui brille, vraie
  lumière sur le sol et les murs, ombres portées pour les deux plus proches du pirate. Fenêtres allumées dans sept maisons
  sur dix, avec une tache de lumière au pied de la façade. Reflets en tirets sur l'eau sous les lanternes du quai. Tout
  s'allume au crépuscule. Le bassin est calme (la baie abrite de la houle, `TOWN_SHELTER`). Réglages : `LAMP_*`, `WINDOW_GLOW`.
- **Étape 5, kit de maisons : première version.** `src/town/town_house.gd` : le kit est une recette, pas des modèles figés.
  Chaque maison est fabriquée à la taille de son emprise : soubassement de pierre, enduit aux couleurs du port (7 teintes),
  bandeaux, porte, fenêtres à volets, balcon de bois pour certaines, toit de tuiles à débord, cheminée. Les trois services
  « intérieur » (taverne, magasin, tailleur) ont une porte double et une potence d'enseigne. Captures : `ville-jour-large.png`,
  `ville-jour-rue.png`, `ville-soir-marche.png`, `ville-nuit-quai.png`.
- **Repères et lieux ouverts : faits.** `src/town/town_landmarks.gd` : église et clocher, maison du gouverneur, moulin (ailes
  qui tournent), phare (feu et faisceaux la nuit), batterie, lavoir, cabanes de pêcheurs, halles (marché, chantier naval avec
  une coque sur cale), tentes rayées ouvertes, tableau des quêtes, forge.
- **Intérieurs : faits.** Taverne (avec sa terrasse et ses marches), magasin général, tailleur : ce sont les intérieurs de
  l'ancienne ville (`data/town.json`), replacés et tournés sur leur bâtiment du plan (`xf` dans `src/land.gd`).
- **Retour de Jimmy (13/11) : « des maisons posées au hasard, la porte donne dans l'herbe ».** Chaque maison regarde
  maintenant la rue le long de laquelle elle est posée ; une maison en retrait a un sentier de sa porte à la rue (`paths`).
- **Pas encore dans la maquette** : les intérieurs (taverne, magasin, tailleur : on parle aux marchands à leur porte), la
  colline du moulin (à plat), la pente de la grève (à plat, à la hauteur du quai), les lanternes, les figurants et les sons.
- L'ancienne ville reste celle du jeu publié.
