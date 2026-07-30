# JEIKO Installer v2

Installe et maintient un site JEIKO sur Debian 12 : Django + Gunicorn + Nginx +
PostgreSQL + Memcached, avec TLS, sauvegardes et mise à jour depuis l'interface
d'administration.

---

## Ce qui a changé par rapport à la v1

La mise à jour depuis l'administration ne fonctionnait pas, pour quatre raisons
qui se cumulaient :

| Symptôme | Cause |
|---|---|
| Rien ne se passe, ou erreur sudo | Le fichier sudoers n'autorisait que `systemctl`, alors que la vue lançait `sudo <script>`. Sudo réclamait un mot de passe, sans terminal pour le saisir. |
| Le script se comporte de façon erratique | Il vivait dans `site-packages/jeiko/scripts/` et `pip install` le réécrivait pendant sa propre exécution. D'où les rustines « SELF-FIX » et un `chown` codé en dur sur un seul site. |
| La page ne revient jamais | Le script redémarrait Gunicorn, donc tuait le processus Django qui l'attendait. |
| Erreur 504 | La mise à jour dépassait le `proxy_read_timeout` de 60 s de Nginx. |

**Le correctif structurel** : l'updater sort de l'application.

```
avant   Django ──sudo──▶ script dans site-packages   (inscriptible par le site)
après   Django ──sudo──▶ systemctl start jeiko-update@<site>
                              └──▶ /usr/local/sbin/jeiko-client-update  (root:root)
```

L'application ne peut plus que **déclencher** sa propre mise à jour. Elle ne
peut plus décider de ce qui s'exécute sous privilèges.

### Deux scripts, deux responsabilités

| | Lancé par | Périmètre |
|---|---|---|
| `jeiko-server-update` | toi, en SSH | nginx, systemd, sudoers, permissions, sauvegardes. Installe aussi le script client. |
| `jeiko-client-update` | l'interface d'administration, ou toi | le package, `settings.py`, `urls.py`, migrations, statiques. |

Le client ne touche jamais à la configuration serveur : un clic dans
l'administration ne réécrit pas un vhost Nginx. Et comme c'est le script
serveur qui met à jour le script client, ce dernier n'a pas besoin de vivre
dans le package ni de se réécrire lui-même — ce qui supprime d'un coup
l'auto-écrasement par pip et le chemin d'élévation par `site-packages`.

`settings.py` et `urls.py` voyagent **dans le package**
(`jeiko/project_template/`). C'est ce qui permet à une version qui ajoute une
application à `INSTALLED_APPS` d'arriver avec le `settings.py` qui la déclare :
le client réaligne le fichier, sans terminal.

### Faille corrigée au passage

`site-packages` est inscriptible par l'utilisateur du site, et ce même
utilisateur pouvait `sudo` un script qui s'y trouvait. Toute exécution de code
dans Django (upload, désérialisation, dépendance compromise) donnait donc
**root sur la machine en une étape**. C'est ce chemin qui disparaît.

### Autres corrections

- Le package est vérifié par **sha256** avant installation. Auparavant, une
  archive était téléchargée puis construite et installée sans aucun contrôle.
- **Rollback automatique** : dump PostgreSQL avant migration, wheel précédent
  conservé, restauration si les migrations, les statiques ou le contrôle de
  santé échouent.
- `SECURE_SSL_REDIRECT` était à `True` en dur : répondre « n » à Let's Encrypt
  produisait une boucle de redirection et un site inaccessible. Piloté par
  `JEIKO_SSL` dans le `.env`.
- Permissions unifiées. L'installation posait `2750/0640`, la mise à jour
  `2775/0664` : chaque mise à jour rendait un peu plus de fichiers inscriptibles
  par le groupe. Une seule implémentation désormais, dans `lib/jeiko-common.sh`.
- `client_max_body_size` absent : tout upload de plus de 1 Mo renvoyait un 413
  sans message côté application.
- Le renouvellement Let's Encrypt reposait sur un vhost qui redirigeait
  `/.well-known/acme-challenge/` en 301. Certbot passe désormais par `webroot`,
  et le renouvellement est testé à l'installation.
- Les secrets (`.env.<site>`, 0644, mot de passe PostgreSQL **et** mot de passe
  superuser en clair) sont remplacés par `/etc/jeiko/sites/<site>.conf` en 0600
  root:root, sans le mot de passe superuser qui ne sert qu'une fois.
- Injection SQL possible via le mot de passe PostgreSQL (interpolé dans la
  chaîne SQL) : passage par des variables `psql` et `format()`.
- `/tmp/jeiko_latest.zip` en chemin fixe (collision entre sites, attaque par
  lien symbolique) → `mktemp -d`.
- Verrou `flock` : deux mises à jour simultanées corrompaient le venv.
- Fail2ban activait un jail `nginx-req-limit` alors qu'aucune zone `limit_req`
  n'existait dans Nginx : la protection était décorative. La zone est créée.

---

## Prérequis

- Debian 12, utilisateur avec `sudo`
- Ports 22, 80, 443 ouverts
- Un domaine pointant vers le VPS (obligatoire si tu actives TLS)

---

## Installation d'un nouveau site

```bash
sudo apt-get update -y && sudo apt-get install -y curl unzip
sudo mkdir -p /var/www && cd /var/www
sudo curl -fL -o jeiko-installer.zip \
  https://raw.githubusercontent.com/gderouineau/jeiko_installer/main/jeiko-installer-latest.zip
sudo unzip -o jeiko-installer.zip -d jeiko-installer
cd jeiko-installer && sudo chmod +x install.sh && sudo ./install.sh
```

L'installeur pose les questions, affiche un récapitulatif, puis enchaîne les
étapes `00` à `14`. Chaque étape est idempotente : en cas d'échec, corrige la
cause et relance `./install.sh`.

---

## Migrer un site existant

**À faire avant toute autre chose sur un serveur déjà en production.** Les sites
installés en v1 n'ont ni updater, ni fiche, ni sudoers correct.

```bash
sudo ./migrate_site.sh --list           # ce qui est détecté, et ce qui est déjà migré
sudo ./migrate_site.sh monsite --dry-run  # montre sans rien modifier
sudo ./migrate_site.sh monsite            # migration réelle, interactive
```

Le script dumpe la base et sauvegarde toutes les configurations **avant** de
toucher à quoi que ce soit, demande confirmation à chaque changement sensible
(settings.py, vhost Nginx), teste `nginx -t` avant de recharger et restaure la
configuration précédente si le test échoue. Tout est conservé dans
`/var/backups/jeiko/<site>/migration_<horodatage>/`.

Si le site ne répond plus après migration :

```bash
sudo jeiko-restore monsite /var/backups/jeiko/monsite/migration_<horodatage>
```

---

## Publier une version

Double-clic sur **`Publier JEIKO`** sur le bureau, ou :

```bash
~/Documents/Projects/packages/jeiko/publier.sh
```

Il demande le type de version, puis fait tout le reste :

```
1) Correction  → 0.6.5   (corrections de bugs)
2) Mineure     → 0.7.0   (nouveautés, compatible)
3) Majeure     → 1.0.0   (changement de fond)
```

Déroulé : miroir de `Art/ENV/…/jeiko` et `Art/INSTALLER` vers le dossier de
publication → contrôle des doublons → gabarits recopiés dans le package →
version dans `pyproject.toml` → wheel → `version.json` avec l'empreinte →
archives → publication sur les deux dépôts.

| Dépôt | Contenu |
|---|---|
| `gderouineau/jeiko` | `version.json`, `dist/*.whl`, `jeiko-latest.zip`, `jeiko-v<version>.zip` |
| `gderouineau/jeiko_installer` | `jeiko-installer-latest.zip`, `jeiko-installer-v<version>.zip` |

Chaque archive existe en deux exemplaires : `latest`, que téléchargent les
serveurs déjà installés, et une copie versionnée qui garde l'historique.

`version.json` est ce que les serveurs lisent pour savoir s'il y a une mise à
jour, et le `sha256` est **le seul lien de confiance** entre ce que tu publies
et ce qui s'exécute en production.

Options : `--dry-run` montre tout sans rien modifier, `--local` prépare les
archives sans publier.

### Le miroir, plutôt que le copier-coller

La copie manuelle par le Finder ajoutait `fichier 2.py` à côté de l'original au
lieu de le remplacer. 89 doublons s'étaient accumulés dans le dossier de
publication, dont **101 sont partis dans l'archive publiée** — donc en
production, depuis février. `rsync --delete --delete-excluded` règle le
problème, et le script refuse de publier s'il détecte un doublon côté source.

---

## Mettre à jour un site

Depuis l'interface : **Administration ▸ Mettre à jour JEIKO**. La page affiche
le journal en direct et survit au redémarrage du site.

Depuis le serveur :

```bash
sudo jeiko-client-update monsite --check     # compare les versions, n'installe rien
sudo jeiko-client-update monsite             # mise à jour du package
sudo jeiko-client-update monsite --force     # réinstalle la même version
sudo jeiko-client-update monsite --rollback  # revient à la version précédente
```

Déroulé : manifeste → vérification sha256 → dump PostgreSQL → installation →
réalignement de `settings.py` et `urls.py` → `django check` → migrations →
collectstatic → permissions → redémarrage → contrôle de santé. **Toute erreur
après l'installation déclenche un rollback** (wheel précédent réinstallé,
gabarits restaurés, base restaurée si les migrations avaient tourné).

### Mettre à jour la configuration serveur

Le package et le serveur évoluent séparément. Quand une version de l'installeur
apporte des corrections de configuration :

```bash
sudo jeiko-server-update monsite       # un site
sudo jeiko-server-update --all         # tous les sites de la machine
sudo jeiko-server-update monsite --with-client   # config serveur puis package
sudo jeiko-server-update --list        # sites enregistrés
```

Idempotent : le relancer sur un site déjà à jour ne change rien. Sauvegarde
avant, `nginx -t` avant rechargement, restauration si le test échoue.

---

## Sauvegardes

Quotidiennes, à une heure décalée par site pour ne pas saturer la machine.

```bash
sudo jeiko-backup monsite                                   # à la demande
sudo jeiko-restore monsite /var/backups/jeiko/monsite/daily/<horodatage>
```

Chaque sauvegarde contient un dump PostgreSQL (vérifié par `pg_restore --list`),
les médias, et les fichiers de configuration. Rétention : 30 jours.

---

## Surveillance

```bash
sudo jeiko-verifier          # à la demande
```

Tourne aussi chaque jour à 7h30, journal dans `/var/log/jeiko/verification.log`.
Contrôle le disque, la mémoire disponible, l'expiration des certificats, l'état
des services et l'âge des sauvegardes.

Aucun de ces problèmes ne se signale de lui-même avant que le site ne tombe : un
disque plein arrête les écritures PostgreSQL, un certificat expiré rend le
domaine inaccessible d'un coup, et une sauvegarde qui a cessé de tourner ne se
remarque que le jour où on en a besoin.

## Ajouter une clé SSH après l'installation

```bash
sudo jeiko-ssh-key 'ssh-ed25519 AAAA…'
```

Installe la clé, coupe l'authentification par mot de passe, vérifie la
configuration **avant** de recharger — impossible de s'enfermer dehors. Si le
test échoue, rien n'est appliqué.

---

## Organisation

```
INSTALLER/
├── install.sh                    installation d'un nouveau site
├── migrate_site.sh               amorçage de l'outillage sur un serveur
├── lib/
│   └── jeiko-common.sh           → /usr/local/lib/jeiko/common.sh
│                                   modèle de permissions, registre des sites,
│                                   vérification d'intégrité. Un seul exemplaire.
├── updater/
│   ├── jeiko-server-update       → /usr/local/sbin/  (root:root) — terminal
│   ├── jeiko-client-update       → /usr/local/sbin/  (root:root) — interface
│   └── jeiko-update@.service     → /etc/systemd/system/
├── scripts/                      étapes 00 à 14
└── templates/
    ├── settings.template.py      SOURCE UNIQUE — recopiée dans le package
    └── urls.template.py            par publier.sh, à chaque publication
```

Le script de publication, lui, vit avec le dossier de publication :
`packages/jeiko/publier.sh`.

### Sur le serveur

| Chemin | Contenu | Droits |
|---|---|---|
| `/etc/jeiko/sites/<site>.conf` | fiche du site (domaine, DB, chemins) | `0600 root:root` |
| `/usr/local/lib/jeiko/common.sh` | bibliothèque partagée | `0644 root:root` |
| `/usr/local/sbin/jeiko-server-update` | convergence serveur | `0755 root:root` |
| `/usr/local/sbin/jeiko-client-update` | mise à jour du package | `0755 root:root` |
| `/usr/local/sbin/jeiko-verifier` | contrôle de santé quotidien | `0755 root:root` |
| `/usr/local/sbin/jeiko-ssh-key` | ajout d'une clé + coupure du mot de passe | `0755 root:root` |
| `/usr/local/sbin/jeiko-backup` / `-restore` | sauvegarde et restauration | `0700 root:root` |
| `/usr/local/share/jeiko/` | gabarits nginx, unités, scripts d'étape | `0755 root:root` |
| `/var/lib/jeiko/<site>/wheels/` | wheels conservés pour le rollback | `0750 root:root` |
| `/var/lib/jeiko/<site>/update.state` | état lu par l'administration | `0640 root:<site>` |
| `/var/log/jeiko/<site>/update.log` | journal de mise à jour | `0640 root:<site>` |
| `/etc/sudoers.d/jeiko-<site>` | 2 commandes autorisées, rien d'autre | `0440 root:root` |

### Modèle de permissions

| Élément | Mode | Pourquoi |
|---|---|---|
| Dossiers du projet | `2750` | setgid : le groupe `www-data` est hérité, Nginx lit sans intervention |
| Fichiers | `0640` | Nginx lit via le groupe, aucun autre compte local ne voit rien |
| `.env` | `0600` | contient `DB_PASS`, jamais lisible par le groupe |
| `venv/bin/*` | `0750` | exécutable par le site uniquement |
| Socket Gunicorn | `0660` | **exception** : Nginx doit pouvoir y écrire pour s'y connecter |

Le socket étant nécessairement inscriptible par le groupe, `settings.py` force
`FILE_UPLOAD_PERMISSIONS = 0o640` : les fichiers uploadés ne dépendent pas du
umask du processus, et une compromission de Nginx ne permet pas de réécrire les
médias.

---

## Dépannage

**La mise à jour ne démarre pas depuis l'interface**

```bash
sudo -u jeiko-monsite sudo -n /usr/bin/systemctl start --no-block jeiko-update@monsite.service
cat /etc/sudoers.d/jeiko-monsite
```

La commande dans le sudoers doit correspondre **au caractère près** à celle
qu'émet la vue. `/bin/systemctl` et `/usr/bin/systemctl` désignent le même
fichier mais sont deux chaînes différentes pour sudo.

**La mise à jour échoue**

```bash
sudo journalctl -u jeiko-update@monsite -n 100
sudo cat /var/log/jeiko/monsite/update.log
```

Le rollback est automatique. Pour le forcer :
`sudo jeiko-client-update monsite --rollback`

**502 Bad Gateway**

```bash
sudo systemctl status gunicorn-monsite
sudo tail -50 /var/log/gunicorn/monsite/error.log
ls -l /run/gunicorn-monsite/gunicorn.sock   # doit être en 0660, groupe www-data
```

**Le site boucle en redirection**

`JEIKO_SSL="True"` dans le `.env` alors qu'aucun certificat n'est en place.
Passe-le à `False` et redémarre, ou installe le certificat :

```bash
sudo /var/www/jeiko-installer/scripts/12_setup_tls_letsencrypt.sh
```

**413 Request Entity Too Large**

Le vhost n'a pas été régénéré : `sudo jeiko-server-update monsite`.
