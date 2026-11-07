# Navigation façon Sea of Thieves — principes retenus

Chaque poste du bateau est une activité physique : on se déplace à pied sur le pont, on va
au poste, on appuie sur E. Personne ne « pilote » depuis un menu.

| Poste | Où | Effet | État |
|---|---|---|---|
| Barre | devant la cabine | gouverner (gauche/droite) ; tant qu'on y est, on ne marche plus | fait |
| Voiles | au pied des mâts | hisser (E) / affaler (R) en 3 crans, elles se déploient en quelques secondes | fait |
| Ancre | cabestan | stoppe le bateau net, il ne pivote plus que lentement | fait |
| Canons | flancs | prendre un boulet au tonneau, charger, tirer ; bâbord et tribord | fait (tir simple) |
| Cabine | château arrière | entrer par la porte ; toit et murs côté caméra disparaissent | fait |
| Table de cartes | cabine | choisir la destination | à faire |
| Vigie | nid-de-pie | voir loin, signaler | à faire |
| Réparations / écopage | coque | planches, seau, voie d'eau après un tir | à faire |

## Vent
Le vent a une direction. Le rendement des voiles va de 12 % (face au vent) à 100 % (vent arrière) ;
le vent de travers donne environ 70 %. Il reste à régler l'orientation des voiles (comme la
manœuvre des cordages de Sea of Thieves) et à faire varier le vent lentement.

## Barre
La barre agit d'autant plus que le bateau avance (12 % à l'arrêt, 100 % aux deux tiers de la
vitesse maximale). À l'ancre, le bateau pivote à 30 % de son taux de virage.

## Équipage et réseau (à venir)
Le bateau avance dans le monde ; les joueurs marchent dans le repère du bateau. Pour le réseau,
l'hôte envoie la position et le cap du bateau, et chaque joueur envoie sa position locale sur le
pont. Les actions des postes (voiles, barre, ancre, canons) passent par l'hôte.

## Réglages (data/ship_stats.json)
`max_speed` (m/s), `turn_rate` (rad/s), `accel` (m/s²), `sail_speed` (ouverture par seconde).
