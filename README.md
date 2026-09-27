# Tools — Scripts de configuration

> Scripts d'outillage pour la configuration de postes de développement.

---

## `setup-git.sh` & `setup-git.bat`

Configure en une commande une clé SSH, la configuration SSH (`~/.ssh/config`), le clone d'un dépôt Gitea et la signature de commits.

* `setup-git.sh` pour **Linux / macOS**
* `setup-git.bat` pour **Windows**

---

### Prérequis

| Outil | Requis |
|-------|--------|
| `git` | toujours |
| `ssh-keygen` | sauf si l'étape SSH est sautée (inclus avec Git for Windows ou OpenSSH) |
| `gpg` | uniquement si signature GPG choisie |

---

### Téléchargement rapide

**Linux / macOS (`setup-git.sh`)**
```bash
curl -fsSL https://raw.githubusercontent.com/Swythabeast/tools/develop/setup-git.sh -o setup-git.sh
```
ou
```bash
wget -q https://raw.githubusercontent.com/Swythabeast/tools/develop/setup-git.sh
```

**Windows (`setup-git.bat`)**
```cmd
curl.exe -fsSL https://raw.githubusercontent.com/Swythabeast/tools/develop/setup-git.bat -o setup-git.bat
```
ou en PowerShell :
```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Swythabeast/tools/develop/setup-git.bat" -OutFile "setup-git.bat"
```

---

### Usage

**Linux / macOS :**
```bash
bash setup-git.sh
```

**Windows :**
Double-cliquez sur `setup-git.bat` ou lancez-le dans un terminal (`cmd` ou PowerShell) :
```cmd
setup-git.bat
```

> **Notice Windows :**
> - Les clés et configurations SSH sont stockées dans `%USERPROFILE%\.ssh` (ex: `C:\Users\<Nom>\.ssh`).
> - Le script utilise la configuration dans `config` (`IdentityFile`), l'agent SSH n'est donc pas obligatoire pour se connecter.
> - Si vous souhaitez activer le service Windows OpenSSH Agent :
>   ```powershell
>   Set-Service ssh-agent -StartupType Manual; Start-Service ssh-agent
>   ```
>   *(à exécuter dans un terminal PowerShell ouvert en tant qu'Administrateur)*.

---

### Étapes

| # | Étape | Optionnel |
|---|-------|-----------|
| 1 | Génération clé SSH ed25519 + `~/.ssh/config` | oui — sautez si déjà configuré |
| 2 | Ajout de la clé sur Gitea + test de connexion | oui — lié à l'étape 1 |
| 3 | Clone du dépôt ou configuration du remote `origin` | |
| 4 | Choix de la méthode de signature (SSH recommandé / GPG) | |
| 5 | Config Git locale (`user.name`, `user.email`, signature) | |

> La config Git **globale** n'est jamais modifiée.

---

### Formats d'URL SSH acceptés

| Format | Exemple |
|--------|---------|
| scp-like | `git@gitea.mon-domaine.com:org/repo.git` |
| `ssh://` avec port | `ssh://git@gitea.mon-domaine.com:2222/org/repo.git` |

Avec le format `ssh://`, le port est extrait automatiquement — il ne sera pas demandé séparément.
