# Port d'attache et économie (façon Sea of Thieves, rendu Eastward)

Décisions de l'utilisateur (2026-11-07) :
- **Or** : trésors trouvés sur les îles et revendus au port, quêtes données au port, butin de combat.
- **Ressources** : planches (réparer les trous), boulets de canon, nourriture (soigner), seau (écoper).
- **Port** : ville portuaire animée, dense, façon Eastward (pas un simple avant-poste).
- **Choix du bateau** : chez le charpentier de marine (PNJ + menu) ; le bateau apparaît à quai.

## Le port
Point d'arrivée de tout l'équipage à la connexion. Une ville sur une île :
- **Quai** (promenade pavée, bittes d'amarrage, caisses, filets) et **ponton principal** où le
  bateau choisi est amarré ; un petit ponton de pêcheurs avec des barques.
- **Place du marché** : étals à auvents rayés, puits, **tableau des quêtes**.
- **Boutiques** (façade, enseigne, PNJ devant la porte) :
  | Lieu | PNJ | Rôle |
  |---|---|---|
  | Chantier naval | charpentier | choisir le bateau (sloop, brigantin, galion) |
  | Tailleur | tailleur | skins de personnage (tenues, chapeaux) |
  | Voilerie | voilier | skins de bateau (voiles, coque, pavillon, figure de proue) |
  | Magasin général | marchand | ressources : planches, boulets, nourriture |
  | Taverne | receleur | rachète les trésors |
  | Place | tableau | quêtes |
- Maisons de remplissage, linge tendu, lanternes, palmiers, plage à l'ouest.

## Économie (à régler)
- Or par joueur, sauvegardé dans son profil (`user://profil.json`) avec les skins achetés et portés.
- Les skins sont visibles par tout l'équipage (envoyés avec l'état du joueur).
- Les ressources sont à bord, dans des tonneaux (stock partagé par l'équipage, géré par l'hôte) ;
  on se réapprovisionne au magasin général ou en trouvant des caisses.

## Ressources et dégâts (étape 4)
- Un boulet qui touche fait un trou ; l'eau monte dans la cale ; au-delà d'un seuil le bateau coule.
- Planche : boucher un trou. Seau : écoper. Nourriture : regagner de la vie. Boulets : stock limité.

## Étapes
1. Ville portuaire (modèle 3D, sols peints), bateau amarré — validation visuelle.
2. Arrivée au port à la connexion, marche à terre, monter à bord / descendre, charpentier.
3. Boutiques, or, profil sauvegardé, skins visibles en réseau.
4. Ressources, trous, eau, réparations.
5. Trésors et receleur, quêtes, butin de combat.
