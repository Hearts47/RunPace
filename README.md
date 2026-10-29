# RunPace

Un addon pour **Azeroth Survivors** qui affiche ton rythme de jeu pendant la run (kills par minute, XP par minute) et te prévient par une alerte à l'écran quand il se passe quelque chose d'important.

> Projet de fan, non officiel. Il n'est affilié ni à Blizzard Entertainment ni aux créateurs d'Azeroth Survivors.

## Fonctionnalités

### Rythme de la run

Un cadre affiche :

```
Kills/min : 195  (moy 190)
XP/min : 41  (moy 38)
```

- Le chiffre sans parenthèses est ton rythme sur les **60 dernières secondes**.
- Le chiffre entre parenthèses (`moy`) est la **moyenne depuis le début de la run**. Pour l'XP, c'est depuis que l'addon a vu la run pour la première fois (si tu recharges l'interface en pleine partie, la moyenne repart de zéro à ce moment-là).

### Alertes

Un bandeau au milieu de l'écran et un son te préviennent quand :

| Alerte | Déclenchement par défaut |
|---|---|
| Vie basse | ta vie passe sous 30 % |
| Beaucoup d'ennemis | 40 ennemis en vie ou plus |
| Boss | 15 secondes avant l'arrivée du prochain boss |

Chaque alerte ne se déclenche qu'une fois, puis se réarme quand la situation redevient normale (chaque boss n'est annoncé qu'une seule fois). Changer un réglage ne déclenche jamais d'alerte.

## Réglages

- **Dans les options du jeu** : Échap → Options → **RunPace** (en bas de la liste des catégories). Tu y règles les seuils des alertes, le son, et tu peux tester une alerte.
- **Fenêtre de réglages** : tape `/rp` ou fais un **clic droit** sur le cadre. Elle contient aussi une explication de l'addon.
- Raccourcis :
  - `/rp hp 30` : alerte vie basse sous 30 %
  - `/rp ennemis 40` : alerte à partir de 40 ennemis
  - `/rp boss 15` : alerte 15 s avant un boss
  - `0` désactive l'alerte correspondante
  - `/rp test` : affiche une alerte de test
  - `/rp debug` : affiche dans le chat l'état du compteur de boss (utile pour signaler un bug)
- Le cadre se déplace au clic gauche maintenu.

## Installation

1. Télécharge le dossier `RunPace` de ce dépôt (ou la dernière *release*).
2. Dans le jeu, ouvre **Options → AddOns → Ouvrir le dossier AddOns**.
3. Place le dossier `RunPace` dedans (le dossier doit s'appeler exactement `RunPace`).
4. Relance le jeu, puis vérifie que l'addon est coché dans la liste des AddOns.

## Fonctionnement

L'addon lit la table `AZS_RUN` fournie par le jeu (`kills`, `t`, `xp`, `xpn`, `lvl`, `hp`, `hpm`, `en`, `nb`, `nbn`, `ph`). Il ne modifie rien dans le jeu.

## Limites connues

- Les réglages ne sont accessibles qu'en partie : les addons ne tournent pas dans le menu principal.
- La catégorie dans les options du jeu est ajoutée sans toucher au code du jeu : si son apparence ou son comportement te semble bizarre, ouvre une *issue*.
- Si tu gagnes plusieurs niveaux d'un coup, l'XP/min est légèrement sous-estimée.

## Licence

[MIT](LICENSE)
