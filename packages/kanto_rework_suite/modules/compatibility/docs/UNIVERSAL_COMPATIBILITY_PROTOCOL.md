# Kanto Rework — Protocole universel de compatibilité des mods


> **0.4.6 amendment — runtime contract gating (2026-08-13).** Release identity/version remains mandatory audit evidence, but a compatible version-only update MUST NOT be disabled solely because its version string changed. Runtime activation is gated by the capability contract actually present (exports, hook ownership, option schema, registry ownership). Exact version checks are reserved for proven incompatible/legacy contracts. A new release still requires audit to update `latestAudited`, but not a KRS release when the observed contract is unchanged.

**Identifiant :** `KRS-COMPAT-PROTOCOL-2`  
**Statut :** Validated foundation  
**Cible de référence :** Gen1Recomp `0.1.75`, Mod API `2`, LÖVE `11.5`  
**Modules propriétaires :** Core pour les contrats neutres, Compatibility pour les connaissances tierces, UI pour la présentation, module métier pour les comportements Kanto.

## 1. Objectif

Intégrer un mod tiers sans lui retirer la propriété de ses données, actions, règles et sauvegardes, tout en faisant passer ses fonctions joueur par l'arborescence, les composants, les modes d'entrée et l'accessibilité de Kanto Rework.

Le protocole ne promet pas qu'un adaptateur rend deux logiques concurrentes compatibles. Il distingue :

- la compatibilité de chargement ;
- la compatibilité fonctionnelle ;
- la compatibilité de présentation ;
- la compatibilité de sauvegarde et de reprise ;
- la compatibilité en jeu réel.

## 2. Sources de vérité

Pour chaque mod tiers, utiliser dans cet ordre :

1. dernière release GitHub réellement distribuée ;
2. artefact installable de cette release ;
3. `manifest.json`, code et assets contenus dans l'artefact ;
4. documentation de la même release ;
5. branche par défaut uniquement comme développement futur, jamais comme substitut silencieux à la release.

Chaque adaptateur est verrouillé sur l'identité vérifiée : `id`, nom, version et, lorsque nécessaire, empreinte de l'artefact. Une nouvelle release exige une nouvelle vérification et une décision explicite : compatible sans changement, nouvel adaptateur ou non supportée.

## 3. Séparation obligatoire des responsabilités

| Couche | Autorisé | Interdit |
|---|---|---|
| Core | Registres neutres, capacités, modèles normalisés, contrats de présentation, diagnostics | Noms, clés d'options ou correctifs propres à un mod tiers |
| Compatibility | Détection versionnée, mapping d'options, revendication des gateways, adaptateurs, diagnostics | Copier la logique métier du mod ou posséder son rendu final |
| UI | Arborescence, composants, lecture Wide, focus, pointeur, responsive et accessibilité | Réimplémenter les calculs, la progression ou la persistance du mod |
| Mod tiers | Valeurs, callbacks, validation, logique métier, progression et sauvegarde | Remplacer `ui.shell` lorsqu'il ne fournit pas lui-même l'UI active choisie |

## 4. Classification avant intégration

Chaque fonction du mod est enregistrée comme une capacité :

- `exclusive` : un seul fournisseur actif, par exemple `ui.shell` ou `bag.organization` ;
- `middleware` : plusieurs fournisseurs forment une chaîne ordonnée ;
- `additive` : fonctions cumulables ;
- `advisory` : recouvrement signalé, décision laissée au joueur.

L'intégration se fait par capacité, pas par verdict global sur le mod. Un conflit limité aux icônes, à une action ou à un écran ne doit pas désactiver toutes les autres fonctions.

## 5. Niveaux d'intégration

### 5.1 Niveau automatique — chemin par défaut

Le chemin plug-and-play ne dépend d'aucun identifiant ou libellé tiers :

1. le gestionnaire natif fournit la liste des mods installés et actifs ;
2. chaque `options_schema` standard devient automatiquement un groupe de réglages du mod propriétaire ;
3. Compatibility instrumente uniquement l'appel réel à `ui.start_menu.items` ;
4. chaque item ajouté est associé au champ `owner` du maillon de hook qui l'a introduit ;
5. l'item est retiré du Main Menu Kanto et ajouté sous `Mods → Installed Mods → [Mod] → Features` ;
6. son callback original est capturé une seule fois ;
7. les descendants `ListMenu` et `TextBox` utilisent le présentateur Wide générique.

La provenance est l'autorité. Une ressemblance de libellé, un ordre supposé ou une liste manuelle de noms ne constitue jamais une preuve de propriété.

### 5.2 Niveau déclaratif — coopération volontaire

Un mod peut publier directement des groupes, descriptions, capacités et intentions de présentation. Ce niveau complète la découverte automatique sans céder ses valeurs, callbacks ou sauvegardes à Kanto Rework.

### 5.3 Niveau adaptateur — exceptions seulement

Un adaptateur versionné reste requis pour :

- classer éditorialement des dizaines d'options sans métadonnées de groupe ;
- traduire un état graphique ou un modèle non standard ;
- préserver un timing, une saisie ou une transition spéciale ;
- arbitrer une incompatibilité fonctionnelle ou de sauvegarde prouvée ;
- corriger un contrat tiers instable en le verrouillant sur une release auditée.

### 5.4 Contrat minimal d'un adaptateur

Un adaptateur versionné doit fournir :

```lua
{
  id = "vendor_mod.1.2.3",
  modId = "vendor_mod",
  version = "1.2.3",
  match = function(manifest) return true_or_false end,
  decorateOptions = function(manifest, rows) return rows end,
  claimStartMenuItem = function(game, item) return true_or_false end,
  utilities = function(game, manifest)
    return {
      {
        id = "vendor_hub",
        label = "VENDOR HUB",
        group = "FEATURES",
        description = "...",
        presentation = {
          reader = {
            mode = "adaptive_document",
            mergeSourcePages = true,
            preserveLines = false,
          },
        },
        open = function() return native_state end,
      },
    }
  end,
}
```

Le contrat `presentation` est déclaratif. Compatibility décrit l'intention ; Kanto UI décide de la géométrie, des composants et des interactions.

## 6. Traduction de l'arborescence

Toutes les portes d'entrée dont la propriété est établie automatiquement, déclarativement ou par un adaptateur doivent être déplacées sous :

`Mods → Installed Mods → [Nom du mod] → [Groupe] → [Fonction]`

Règles :

- aucune entrée parallèle dans le Main Menu si la même fonction est intégrée sous Mods ;
- les gateways dynamiques liées à la progression sont détectées par la provenance du hook, un marqueur de propriété ou un contrat stable, jamais seulement par un libellé ;
- le callback original reste la seule autorité d'ouverture ;
- chaque état enfant compatible est enveloppé récursivement ;
- l'ordre des actions et le retour au parent sont conservés ;
- un état inconnu n'entraîne jamais le fallback de toute l'UI Kanto.

## 7. Traduction des réglages

Les options exposées par le moteur restent la source de vérité. L'adaptateur peut uniquement :

- regrouper et ordonner ;
- améliorer un libellé ou une description sans changer le sens ;
- déclarer une dépendance, une incompatibilité ou un état indisponible ;
- associer un composant Kanto adapté au type natif.

Les écritures passent par le setter du mod ou du gestionnaire officiel. Kanto ne crée pas une seconde copie persistante de la valeur.

## 8. Protocole de lecture Wide

Un `TextBox` vanilla est une source sémantique, pas une géométrie à agrandir.

### 8.1 Normalisation

- conserver l'ordre de toutes les pages et lignes ;
- recomposer les retours à la ligne imposés par la largeur vanilla ;
- préserver les coupures de mots avec trait d'union ;
- convertir chaque page source en section ordonnée du document ;
- recalculer les retours à la ligne avec la police et la largeur Wide réelles ;
- ne jamais tronquer silencieusement.

### 8.2 Lecture

- afficher autant de contenu que permet réellement la surface Wide ;
- utiliser un document défilable lorsque sa hauteur dépasse le viewport ;
- afficher une scrollbar avec une cible d'au moins 44 px ;
- permettre défilement ligne par ligne et par écran ;
- rendre la progression lisible sans dépendre de la couleur ;
- n'afficher un choix final qu'après la fin réelle du document ;
- conserver `defaultNo`, `choice`, `onDone` et les callbacks suivants.

### 8.3 Entrées

| Entrée | Comportement |
|---|---|
| Clavier / manette haut-bas | Défilement fin |
| Clavier / manette gauche-droite | Défilement par écran ou choix final |
| Confirmer | Écran suivant, puis action finale |
| Annuler / clic droit | Sémantique native du dialogue ou retour explicite défini par l'adaptateur |
| Molette | Défilement du document sous le pointeur |
| Souris / tactile | Activation, choix et déplacement de la scrollbar |

### 8.4 Limites sûres

Les `TextBox` automatiques, temporisés ou `stay` ne sont pas transformés sans adaptateur dédié : leur timing peut piloter une scène. Un écran entièrement graphique, une animation, une saisie texte ou un état sans modèle sémantique reconnu conserve son rendu natif local. Ce fallback doit être signalé ; il ne doit pas faire tomber tout `ui.shell` en vanilla.

## 9. Préservation des callbacks et de l'état

L'enveloppe Kanto doit :

- intercepter uniquement les états poussés pendant le callback concerné ;
- restaurer immédiatement la méthode `stack.push`, y compris après erreur ;
- conserver tous les états poussés et leur ordre ;
- appeler `onChoose`, `onCancel`, `choice` et `onDone` au même point logique ;
- ne jamais écrire directement dans la sauvegarde du mod ;
- attribuer toute erreur au mod ou à l'adaptateur concerné ;
- éviter les boucles d'enveloppement et les doubles activations.

## 10. Fallback et dégradation locale

Ordre de décision :

1. présenter le modèle normalisé avec Kanto UI ;
2. utiliser un adaptateur visuel spécialisé si le modèle générique ne suffit pas ;
3. conserver localement l'écran natif si sa sémantique n'est pas traduisible sans risque ;
4. bloquer uniquement la fonction concernée si son exécution serait destructive ou incohérente ;
5. bloquer le mod entier uniquement pour une incompatibilité prouvée de chargement, de sauvegarde ou d'identité.

## 11. Matrice de validation obligatoire

| Axe | Preuve minimale |
|---|---|
| Release | Tag, date, commit et artefact installable relevés |
| Chargement | Loader officiel, ordre, dépendances, zéro erreur non expliquée |
| Syntaxe | Tous les fichiers Lua de l'artefact et de l'adaptateur |
| Navigation | Clavier+souris, manette, tactile ou justification d'absence |
| Arborescence | Aucune gateway parallèle restante |
| Réglages | Lecture, modification, reset et persistance par le propriétaire |
| Lecture | Texte court, long, multisection, scrollbar, choix final |
| Accessibilité | Quatre profils couleur, focus/hover/selected/disabled non chromatiques |
| Fallback | État inconnu, erreur callback, écran graphique, layout non Wide |
| Régression | Core, UI, Compatibility et modules métier concernés |
| Jeu réel | Windows/OpenGL et parcours joueur ; sinon marquer explicitement non testé |

## 12. Critères d'acceptation

Une intégration est déclarée terminée uniquement si :

- le mod apparaît sous Installed Mods avec ses fonctions utiles ;
- aucune fonction intégrée ne réintroduit une arborescence parallèle ;
- Kanto UI présente les écrans sémantiques reconnus ;
- les valeurs, callbacks et sauvegardes restent détenus par le mod source ;
- les trois modes d'entrée couvrent les mêmes actions ;
- le fallback est local et documenté ;
- les tests techniques passent ;
- le test réel est confirmé ou explicitement indiqué comme restant à faire.

## 13. Transaction Save → Restart → Resume

Lorsqu'une activation ou désactivation exige un redémarrage, `Restart Now` signifie explicitement :

1. vérifier que l'overworld est stable ;
2. écrire la sauvegarde active et contrôler le résultat ;
3. enregistrer de façon ponctuelle la version du jeu et le slot actifs ;
4. armer un bypass ponctuel du routage « fermeture → launcher », puis relancer le processus avec le nouvel ensemble de mods ;
5. consommer et supprimer le contexte ponctuel ;
6. charger la sauvegarde écrite et reconstruire directement l'overworld.

Le bouton et la confirmation doivent annoncer que la sauvegarde est effectuée. Si la préparation de la reprise échoue après l'écriture, l'UI doit dire que la partie a été sauvegardée mais ne pas lancer un redémarrage qui aboutirait au launcher.

Sous Gen1Recomp `0.1.75`, ce mécanisme automatique repose sur les options de lancement `POKEPORT_GAME` et `POKEPORT_SLOT` et nécessite un environnement desktop capable de transmettre ponctuellement ces valeurs au redémarrage. Android, iOS et Nintendo Switch conservent un refus sûr tant que le moteur ne fournit pas un jeton public de reprise interprocessus.

Le bypass ne vaut que pour l'événement `quit("restart")` déjà demandé. Il restaure immédiatement le gestionnaire `love.quit` normal ; il ne modifie donc pas le comportement d'une fermeture de fenêtre ordinaire.

## 14. Références techniques

- Gen1Recomp officiel, wiki de modding : https://github.com/bryanthaboi/gen1recomp/wiki
- Gen1Recomp `0.1.75`, release auditée : https://github.com/bryanthaboi/gen1recomp/releases/tag/v0.1.75
- Source officielle auditée (`60cf07f`) : https://github.com/bryanthaboi/gen1recomp/tree/60cf07fb0a1ffce0ec6d5d0d2f78a921a6d0b7da
- Kanto Ascendant `6.0.11`, premier adaptateur complet : https://github.com/Roxas2712/kanto-ascendant/releases/tag/v6.0.11
