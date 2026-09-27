@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

rem --- Definition des couleurs ANSI ---
for /f "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "BOLD=%ESC%[1m"
set "RESET=%ESC%[0m"

goto :main

:info
echo %BLUE%[INFO]%RESET% %~1
exit /b 0

:success
echo %GREEN%[OK]%RESET%   %~1
exit /b 0

:warn
echo %YELLOW%[WARN]%RESET% %~1
exit /b 0

:die
echo.
echo %RED%[ERR]%RESET%  %~1
echo.
pause
exit /b 1

:step
echo.
echo %BOLD%== %~1 %RESET%
exit /b 0

:check_deps
call :step "Vérification des dépendances"
where git >nul 2>&1 || (call :die "Git n'est pas installé." & exit /b 1)
if /i "!SKIP_SSH!"=="y" goto :deps_ssh_done
where ssh-keygen >nul 2>&1 || (call :die "ssh-keygen introuvable." & exit /b 1)
where ssh >nul 2>&1 || (call :die "ssh introuvable." & exit /b 1)
:deps_ssh_done
call :success "Dépendances OK."
exit /b 0

:ask_skip_options
call :step "Que voulez-vous faire ?"
echo.
set "_skip="
set /p "_skip=SSH déjà configurée (clé + ~/.ssh/config) ? Sauter cette étape ? (o/N) : "
if /i "!_skip!"=="o" (set "SKIP_SSH=y") else (set "SKIP_SSH=n")

echo.
set "_existing="
set /p "_existing=Repo déjà cloné ? Travailler sur un dossier existant ? (o/N) : "
if /i "!_existing!"=="o" (set "USE_EXISTING_REPO=y") else (set "USE_EXISTING_REPO=n")
exit /b 0

:collect_user_info
call :step "Informations utilisateur"

set "DEFAULT_NAME="
for /f "delims=" %%i in ('git config --global user.name 2^>nul') do set "DEFAULT_NAME=%%i"
set "DEFAULT_EMAIL="
for /f "delims=" %%i in ('git config --global user.email 2^>nul') do set "DEFAULT_EMAIL=%%i"

if defined DEFAULT_NAME (
    set /p "GIT_NAME=Votre prénom et nom [!DEFAULT_NAME!] : "
    if not defined GIT_NAME set "GIT_NAME=!DEFAULT_NAME!"
) else (
    set /p "GIT_NAME=Votre prénom et nom : "
)
if not defined GIT_NAME (call :die "Le nom ne peut pas être vide." & exit /b 1)

if defined DEFAULT_EMAIL (
    set /p "GIT_EMAIL=Votre email Gitea [!DEFAULT_EMAIL!] : "
    if not defined GIT_EMAIL set "GIT_EMAIL=!DEFAULT_EMAIL!"
) else (
    set /p "GIT_EMAIL=Votre email Gitea : "
)
if not defined GIT_EMAIL (call :die "L'email ne peut pas être vide." & exit /b 1)

:url_loop
set "REPO_SSH_URL="
set /p "REPO_SSH_URL=URL SSH du dépôt (ex: gitea@host:org/repo.git  ou  ssh://git@host:2222/org/repo.git) : "
if not defined REPO_SSH_URL (
    call :warn "L'URL ne peut pas être vide."
    goto :url_loop
)

set "SSH_USER="
set "SSH_HOST="
set "URL_PORT="
for /f "tokens=1,2,3 delims=|" %%A in ('powershell -NoProfile -Command "$u=$env:REPO_SSH_URL; if ($u -match '^ssh://([^@]+)@([^:/]+)(?::([0-9]+))?/(.+)$') { Write-Output ($Matches[1] + '|' + $Matches[2] + '|' + $Matches[3]) } elseif ($u -match '^([^@]+)@([^:]+):(.+)$') { Write-Output ($Matches[1] + '|' + $Matches[2] + '|') }"') do (
    set "SSH_USER=%%A"
    set "SSH_HOST=%%B"
    set "URL_PORT=%%C"
)

if not defined SSH_USER (
    call :warn "URL invalide — formats acceptés : user@host:org/repo.git  ou  ssh://user@host:port/org/repo.git"
    goto :url_loop
)

set /p "GITEA_USERNAME=Votre nom d'utilisateur Gitea (login du compte, ex: alice) : "
if not defined GITEA_USERNAME (call :die "Le nom d'utilisateur ne peut pas être vide." & exit /b 1)
for /f "delims=" %%i in ('powershell -NoProfile -Command "$env:GITEA_USERNAME.ToLower()"') do set "GITEA_USERNAME=%%i"

set "SSH_KEY_PATH=%USERPROFILE%\.ssh\id_ed25519_gitea_%GITEA_USERNAME%"
call :info "Clé SSH : !SSH_KEY_PATH!"

if defined URL_PORT (
    set "GITEA_SSH_PORT=!URL_PORT!"
    call :info "Port SSH extrait de l'URL : !GITEA_SSH_PORT!"
) else if "!SKIP_SSH!" neq "y" (
    set "GITEA_SSH_PORT="
    set /p "GITEA_SSH_PORT=Port SSH de Gitea [22] : "
    if not defined GITEA_SSH_PORT set "GITEA_SSH_PORT=22"
) else (
    set "EXISTING_PORT="
    if exist "%USERPROFILE%\.ssh\config" (
        for /f "tokens=2" %%p in ('powershell -NoProfile -Command "$content = Get-Content \"$env:USERPROFILE\.ssh\config\" -ErrorAction SilentlyContinue; $found = $false; foreach ($l in $content) { if ($l -match '^\s*Host\s+$([regex]::Escape($env:SSH_HOST))\b') { $found = $true; continue }; if ($found -and $l -match '^\s*Host\s+') { break }; if ($found -and $l -match '^\s*Port\s+(\d+)') { Write-Output $Matches[1]; break } }"') do set "EXISTING_PORT=%%p"
    )
    if not defined EXISTING_PORT set "EXISTING_PORT=22"
    set "GITEA_SSH_PORT=!EXISTING_PORT!"
    call :info "Port SSH détecté depuis ~/.ssh/config : !GITEA_SSH_PORT!"
)

if "!USE_EXISTING_REPO!"=="y" (
    set /p "REPO_DIR=Chemin vers le dossier du repo existant : "
    if defined REPO_DIR (
        if "!REPO_DIR:~0,2!"=="~\" set "REPO_DIR=%USERPROFILE%\!REPO_DIR:~2!"
        if "!REPO_DIR:~0,2!"=="~/" set "REPO_DIR=%USERPROFILE%\!REPO_DIR:~2!"
    )
    if not exist "!REPO_DIR!\.git" (
        call :die "Pas de dépôt Git trouvé dans '!REPO_DIR!'."
        exit /b 1
    )
) else (
    set "REPO_DIR="
    set /p "REPO_DIR=Dossier de destination pour le clone (défaut: ./repo) : "
    if not defined REPO_DIR set "REPO_DIR=repo"
    if "!REPO_DIR:~0,2!"=="~\" set "REPO_DIR=%USERPROFILE%\!REPO_DIR:~2!"
    if "!REPO_DIR:~0,2!"=="~/" set "REPO_DIR=%USERPROFILE%\!REPO_DIR:~2!"
)

call :info "Nom    : !GIT_NAME!"
call :info "Email  : !GIT_EMAIL!"
call :info "Gitea  : !SSH_USER!@!SSH_HOST!:!GITEA_SSH_PORT!"
call :info "Dépôt  : !REPO_SSH_URL! -> !REPO_DIR!"
exit /b 0

:generate_ssh_key
call :step "Génération de la clé SSH ed25519"
if exist "!SSH_KEY_PATH!" (
    call :warn "Une clé existe déjà à !SSH_KEY_PATH!"
    set "OVERWRITE="
    set /p "OVERWRITE=Écraser ? (o/N) : "
    if /i "!OVERWRITE!" neq "o" (
        call :info "Clé existante conservée."
        exit /b 0
    )
)

if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
ssh-keygen -t ed25519 -C "!GIT_EMAIL!" -f "!SSH_KEY_PATH!"
if errorlevel 1 (
    call :die "Échec de la génération de la clé SSH."
    exit /b 1
)
call :success "Clé générée : !SSH_KEY_PATH!"
exit /b 0

:configure_ssh_agent
call :step "Configuration de l'agent SSH"
net start ssh-agent >nul 2>&1
ssh-add "!SSH_KEY_PATH!" >nul 2>&1
if errorlevel 1 (
    call :warn "L'agent SSH n'a pas pu charger la clé (service ssh-agent arrêté ou désactivé)."
    call :info "Note : L'authentification fonctionnera via ~/.ssh/config sans problème."
    call :info "Pour activer l'agent SSH Windows (optionnel), exécutez dans un terminal Administrateur :"
    call :info "  powershell Set-Service ssh-agent -StartupType Manual; Start-Service ssh-agent"
) else (
    call :success "Clé ajoutée à l'agent SSH."
)
exit /b 0

:configure_ssh_config
call :step "Configuration de ~/.ssh/config"
set "SSH_CONFIG=%USERPROFILE%\.ssh\config"
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
set "KEY_FWD=!SSH_KEY_PATH:\=/!"

if exist "!SSH_CONFIG!" (
    findstr /I /C:"Host !SSH_HOST!" "!SSH_CONFIG!" >nul 2>&1
    if not errorlevel 1 (
        call :warn "Une entrée pour !SSH_HOST! existe déjà dans ~/.ssh/config. Pas de modification."
        exit /b 0
    )
)

(
    echo.
    echo Host !SSH_HOST!
    echo     HostName !SSH_HOST!
    echo     Port !GITEA_SSH_PORT!
    echo     User !SSH_USER!
    echo     IdentityFile !KEY_FWD!
    echo     IdentitiesOnly yes
) >> "!SSH_CONFIG!"
call :success "Entrée ajoutée dans ~/.ssh/config."
exit /b 0

:verify_key_on_platforms
call :step "Vérification de la clé"
set "LOCAL_FP="
for /f "tokens=2" %%A in ('ssh-keygen -lf "!SSH_KEY_PATH!.pub"') do (
    if not defined LOCAL_FP set "LOCAL_FP=%%A"
)

echo.
echo %BOLD%Fingerprint de votre clé locale :%RESET%
echo   %GREEN%!LOCAL_FP!%RESET%
echo.
echo Comparez ce fingerprint avec celui affiché dans vos paramètres SSH :
echo   • Gitea  -^> Settings -^> SSH/GPG Keys
echo.
set "CONFIRMED="
set /p "CONFIRMED=Le fingerprint correspond ? (o/N) : "
if /i "!CONFIRMED!" neq "o" (
    call :warn "Ajoutez la clé sur Gitea puis relancez cette vérification."
    call :die "Arrêt."
    exit /b 1
)
call :success "Fingerprint confirmé."

echo.
set "NEEDS_SIG="
set /p "NEEDS_SIG=La plateforme vous demande-t-elle de signer un token de vérification ? (o/N) : "
if /i "!NEEDS_SIG!"=="o" (
    call :step "Signature du token de vérification"
    set "VERIFY_TOKEN="
    set /p "VERIFY_TOKEN=Token : "
    if not defined VERIFY_TOKEN (call :die "Token vide." & exit /b 1)

    call :info "Génération de la signature..."
    powershell -NoProfile -Command "$t = $env:VERIFY_TOKEN; $kf = $env:SSH_KEY_PATH; $tmp = [System.IO.Path]::GetTempFileName(); [System.IO.File]::WriteAllText($tmp, $t); $p = Start-Process -FilePath 'ssh-keygen' -ArgumentList ('-Y', 'sign', '-n', 'gitea', '-f', $kf, $tmp) -NoNewWindow -Wait -PassThru; if (Test-Path ($tmp + '.sig')) { Get-Content ($tmp + '.sig'); Remove-Item ($tmp + '.sig') }; Remove-Item $tmp" > "%TEMP%\gitea_sig.txt" 2>&1
    if not exist "%TEMP%\gitea_sig.txt" (
        call :die "La signature a échoué."
        exit /b 1
    )
    echo.
    echo %BOLD%Copiez ce bloc dans le champ 'Armored SSH signature' :%RESET%
    echo.
    echo %GREEN%
    type "%TEMP%\gitea_sig.txt"
    echo %RESET%
    echo.
    pause
    del "%TEMP%\gitea_sig.txt" >nul 2>&1
    call :success "Signature de possession complétée."
)
exit /b 0

:add_key_to_gitea_and_test
call :step "Ajout de la clé publique sur Gitea"
echo.
echo %BOLD%Copiez cette clé publique et ajoutez-la sur Gitea :%RESET%
echo %YELLOW%Gitea -^> Settings -^> SSH/GPG Keys -^> Add Key%RESET%
echo.
type "!SSH_KEY_PATH!.pub"
echo.
pause

call :verify_key_on_platforms || exit /b 1

call :step "Test de la connexion SSH"
call :info "Test en cours : !SSH_USER!@!SSH_HOST! (port !GITEA_SSH_PORT!)..."
ssh -T -i "!SSH_KEY_PATH!" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o BatchMode=yes -p !GITEA_SSH_PORT! !SSH_USER!@!SSH_HOST! > "%TEMP%\ssh_test.log" 2>&1
findstr /I /C:"successfully" "%TEMP%\ssh_test.log" >nul 2>&1
if not errorlevel 1 (
    call :success "Connexion SSH à Gitea réussie !"
) else (
    call :warn "Connexion échouée. Détail :"
    type "%TEMP%\ssh_test.log"
    echo.
    call :info "Commande manuelle pour débugger :"
    call :info "  ssh -vT -i !SSH_KEY_PATH! -p !GITEA_SSH_PORT! !SSH_USER!@!SSH_HOST!"
    set "CONTINUE="
    set /p "CONTINUE=Continuer quand même ? (o/N) : "
    if /i "!CONTINUE!" neq "o" (
        del "%TEMP%\ssh_test.log" >nul 2>&1
        call :die "Arrêt."
        exit /b 1
    )
)
del "%TEMP%\ssh_test.log" >nul 2>&1
exit /b 0

:test_ssh_only
call :step "Test de la connexion SSH existante"
if not exist "!SSH_KEY_PATH!" (
    call :die "Clé !SSH_KEY_PATH! introuvable. Relancez sans l'option skip SSH."
    exit /b 1
)
call :info "Test en cours : !SSH_USER!@!SSH_HOST! (port !GITEA_SSH_PORT!)..."
ssh -T -i "!SSH_KEY_PATH!" -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o BatchMode=yes -p !GITEA_SSH_PORT! !SSH_USER!@!SSH_HOST! > "%TEMP%\ssh_test.log" 2>&1
findstr /I /C:"successfully" "%TEMP%\ssh_test.log" >nul 2>&1
if not errorlevel 1 (
    call :success "Connexion SSH à Gitea réussie !"
) else (
    call :warn "Connexion SSH échouée. Détail :"
    type "%TEMP%\ssh_test.log"
    call :warn "Si le problème persiste, relancez sans l'option skip SSH pour reconfigurer."
)
del "%TEMP%\ssh_test.log" >nul 2>&1
exit /b 0

:setup_repo
if "!USE_EXISTING_REPO!"=="y" (
    call :step "Configuration du remote sur le repo existant"
    set "CURRENT_REMOTE="
    for /f "delims=" %%R in ('git -C "!REPO_DIR!" remote get-url origin 2^>nul') do set "CURRENT_REMOTE=%%R"
    if defined CURRENT_REMOTE (
        call :info "Remote actuel : !CURRENT_REMOTE!"
        git -C "!REPO_DIR!" remote set-url origin "!REPO_SSH_URL!"
        call :success "Remote mis à jour -> !REPO_SSH_URL!"
    ) else (
        git -C "!REPO_DIR!" remote add origin "!REPO_SSH_URL!"
        call :success "Remote ajouté -> !REPO_SSH_URL!"
    )
) else (
    call :step "Clone du dépôt"
    if exist "!REPO_DIR!" (
        call :warn "Le dossier '!REPO_DIR!' existe déjà."
        set "USE_EXISTING="
        set /p "USE_EXISTING=Continuer dans ce dossier ? (o/N) : "
        if /i "!USE_EXISTING!" neq "o" (
            call :die "Arrêt. Choisissez un autre dossier."
            exit /b 1
        )
    ) else (
        git clone "!REPO_SSH_URL!" "!REPO_DIR!"
        if errorlevel 1 (
            call :die "Échec du git clone."
            exit /b 1
        )
        call :success "Dépôt cloné dans !REPO_DIR!"
    )
)
exit /b 0

:choose_signing_method
call :step "Méthode de signature des commits"
echo   1) SSH  - Réutilise votre clé SSH (recommandé)
echo   2) GPG  - Méthode classique
echo.
set "SIGN_METHOD="
set /p "SIGN_METHOD=Votre choix [1/2] : "
if "!SIGN_METHOD!" neq "1" if "!SIGN_METHOD!" neq "2" (
    call :warn "Choix invalide, 1 sélectionné par défaut."
    set "SIGN_METHOD=1"
)
exit /b 0

:configure_ssh_signing
set "KEY_FWD=!SSH_KEY_PATH:\=/!"
git -C "!REPO_DIR!" config gpg.format ssh
git -C "!REPO_DIR!" config user.signingkey "!KEY_FWD!.pub"
git -C "!REPO_DIR!" config commit.gpgsign true
git -C "!REPO_DIR!" config tag.gpgsign true

set "ALLOWED_SIGNERS=%USERPROFILE%\.ssh\allowed_signers"
set "PUBKEY="
if exist "!SSH_KEY_PATH!.pub" (
    set /p PUBKEY=<"!SSH_KEY_PATH!.pub"
)
if exist "!ALLOWED_SIGNERS!" (
    findstr /C:"!PUBKEY!" "!ALLOWED_SIGNERS!" >nul 2>&1
    if errorlevel 1 (
        echo !GIT_EMAIL! !PUBKEY!>> "!ALLOWED_SIGNERS!"
    )
) else (
    echo !GIT_EMAIL! !PUBKEY!> "!ALLOWED_SIGNERS!"
)
set "ALLOWED_FWD=!ALLOWED_SIGNERS:\=/!"
git -C "!REPO_DIR!" config gpg.ssh.allowedSignersFile "!ALLOWED_FWD!"

call :success "Signature SSH configurée."
call :warn "Ajoutez votre clé publique dans Gitea pour la vérification des commits :"
call :warn "Gitea -^> Settings -^> SSH/GPG Keys -^> Manage GPG Keys -^> Add Key"
exit /b 0

:configure_gpg_signing
where gpg >nul 2>&1 || (call :die "gpg n'est pas installé." & exit /b 1)

call :info "Génération d'une clé GPG ed25519..."
gpg --full-generate-key

echo.
gpg --list-secret-keys --keyid-format=long
echo.
set "GPG_KEY_ID="
set /p "GPG_KEY_ID=Collez l'ID de votre clé (ex: ABCD1234EFGH5678) : "
if not defined GPG_KEY_ID (call :die "L'ID de clé ne peut pas être vide." & exit /b 1)

git -C "!REPO_DIR!" config user.signingkey "!GPG_KEY_ID!"
git -C "!REPO_DIR!" config commit.gpgsign true
git -C "!REPO_DIR!" config tag.gpgsign true

call :success "Signature GPG configurée."
call :warn "Exportez et ajoutez votre clé sur Gitea :"
call :warn "Gitea -^> Settings -^> SSH/GPG Keys -^> Manage GPG Keys -^> Add Key"
echo.
gpg --armor --export "!GPG_KEY_ID!"
exit /b 0

:configure_git_local
call :step "Configuration Git locale dans !REPO_DIR!"
git -C "!REPO_DIR!" config user.name "!GIT_NAME!"
git -C "!REPO_DIR!" config user.email "!GIT_EMAIL!"

if "!SIGN_METHOD!"=="1" (
    call :configure_ssh_signing || exit /b 1
) else (
    call :configure_gpg_signing || exit /b 1
)
call :success "Config Git locale appliquée (votre config globale est intacte)."
exit /b 0

:print_summary
call :step "Tout est prêt"
echo.
echo %GREEN%%BOLD%Récapitulatif :%RESET%
if "!SKIP_SSH!" neq "y" echo   Clé SSH            : !SSH_KEY_PATH!
for %%F in ("!REPO_DIR!") do echo   Dépôt              : %%~fF
set "SUM_REMOTE="
for /f "delims=" %%R in ('git -C "!REPO_DIR!" remote get-url origin 2^>nul') do set "SUM_REMOTE=%%R"
if not defined SUM_REMOTE set "SUM_REMOTE=—"
echo   Remote origin      : !SUM_REMOTE!
for /f "delims=" %%N in ('git -C "!REPO_DIR!" config user.name 2^>nul') do echo   user.name (local)  : %%N
for /f "delims=" %%E in ('git -C "!REPO_DIR!" config user.email 2^>nul') do echo   user.email (local) : %%E
set "SUM_GPG_FMT="
for /f "delims=" %%G in ('git -C "!REPO_DIR!" config gpg.format 2^>nul') do set "SUM_GPG_FMT=%%G"
if not defined SUM_GPG_FMT set "SUM_GPG_FMT=gpg (défaut)"
echo   gpg.format         : !SUM_GPG_FMT!
set "SUM_GPG_SIGN="
for /f "delims=" %%S in ('git -C "!REPO_DIR!" config commit.gpgsign 2^>nul') do set "SUM_GPG_SIGN=%%S"
if not defined SUM_GPG_SIGN set "SUM_GPG_SIGN=non défini"
echo   commit.gpgsign     : !SUM_GPG_SIGN!
echo.
echo %BOLD%Config globale (inchangée) :%RESET%
set "GL_NAME=—"
set "GL_EMAIL=—"
for /f "delims=" %%N in ('git config --global user.name 2^>nul') do set "GL_NAME=%%N"
for /f "delims=" %%E in ('git config --global user.email 2^>nul') do set "GL_EMAIL=%%E"
echo   user.name  : !GL_NAME!
echo   user.email : !GL_EMAIL!
echo.
pause
exit /b 0

:main
echo.
echo %BOLD%+----------------------------------------------+%RESET%
echo %BOLD%^|   Configuration SSH ^& Git Remote - Gitea    ^|%RESET%
echo %BOLD%+----------------------------------------------+%RESET%
echo.
echo %YELLOW%Votre config Git globale ne sera pas modifiée.%RESET%
echo.

call :ask_skip_options || exit /b 1
call :check_deps || exit /b 1
call :collect_user_info || exit /b 1

if "!SKIP_SSH!" neq "y" (
    call :generate_ssh_key || exit /b 1
    call :configure_ssh_agent || exit /b 1
    call :configure_ssh_config || exit /b 1
    call :add_key_to_gitea_and_test || exit /b 1
) else (
    call :test_ssh_only || exit /b 1
)

call :setup_repo || exit /b 1
call :choose_signing_method || exit /b 1
call :configure_git_local || exit /b 1
call :print_summary || exit /b 1
exit /b 0
