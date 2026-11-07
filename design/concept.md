# Concept — jeu de pirates en pixel art (titre provisoire)

## Pitch
Aventure de pirates coop (1 à 4 joueurs), mélange de l'esprit One Piece (équipage
coloré, îles à thème, pouvoirs mystérieux) et de Sea of Thieves (navigation
physique, un bateau par équipage, quêtes de trésor, PvE et PvP en mer).

## Direction visuelle
- Référence : Eastward. Pixel art dense et détaillé, vue 3/4 oblique (pas du
  dessus pur), éclairage et ambiance peints, décors très chargés.
- Même résolution native et même échelle que Eastward (à mesurer : voir questions).
- Mer : bateau vu en 3/4, vagues, vent et tempêtes animés.

## Boucle de jeu
1. Naviguer en mer (voile, gouvernail, vent, canons).
2. Accoster des îles, les explorer à pied, trouver des trésors, des PNJ, des fruits.
3. Combattre en temps réel (à pied et en mer).
4. Revenir au bateau, améliorer, repartir.

## Multijoueur
- 1 à 4 joueurs en coop.
- Plusieurs bateaux dans un même monde, comme Sea of Thieves.
- PvE (monstres marins, marine, forts) et PvP (abordages, batailles navales).

- Décidé : mode en ligne avec un joueur qui héberge (comme l'autre jeu, ENet).
- Trois bateaux : 2 places (sloop), 3 places (brigantin), 4 places (galion),
  définis dans `data/ships.json`.

## Système de pouvoirs : les baies des dieux
- Au départ, aucun pouvoir.
- Des baies des dieux sont éparpillées dans le monde.
- Chaque baie a un nom différent. Un pouvoir inconnu à la prise : on le découvre en jouant.
- (À décider) une seule baie par personnage ? Peut-on perdre une baie ?

## Style graphique (décidé)
- Pixel art dessiné à la Eastward, pas de rendu 3D.

## Questions ouvertes
- Résolution native exacte (Eastward est en 16:9 bas-résolution, à confirmer).
- Réseau : serveur dédié ou hébergement par un joueur ? Entre amis, hôte = joueur.
- Le monde est-il généré, ou dessiné à la main ?
- Le PvP est-il toujours actif, ou en zones / par choix ?
- Taille de l'équipe : seul avec l'IA ? Budget temps ?
