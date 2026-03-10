#!/bin/bash
set -euo pipefail

# ╔══════════════════════════════════════════════════════════════╗
# ║         MINECRAFT SERVER — SETUP WIZARD v2.0                ║
# ║  Java 21 · Paper (Auto) · Plugins · MariaDB · Firewall     ║
# ╚══════════════════════════════════════════════════════════════╝

# ==============================================================
#  COULEURS & STYLES
# ==============================================================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[97m"
GRAY="\e[90m"
BOLD="\e[1m"
DIM="\e[2m"
RESET="\e[0m"

# ==============================================================
#  FONCTIONS VISUELLES
# ==============================================================

banner() {
  local text="$1"
  echo
  echo -e "  ${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
  printf "  ${CYAN}║${RESET}  ${BOLD}${WHITE}%-58s${RESET}${CYAN}║${RESET}\n" "$text"
  echo -e "  ${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
  echo
}

step_header() {
  local num="$1"
  local total="$2"
  local text="$3"
  echo
  echo -e "  ${YELLOW}┌──────────────────────────────────────────────────────────┐${RESET}"
  printf "  ${YELLOW}│${RESET}  ${BOLD}${WHITE}ÉTAPE %s/%s${RESET} ${GRAY}—${RESET} ${WHITE}%-40s${RESET} ${YELLOW}│${RESET}\n" "$num" "$total" "$text"
  echo -e "  ${YELLOW}└──────────────────────────────────────────────────────────┘${RESET}"
  echo
}

ok()   { echo -e "  ${GREEN}  ✔${RESET} $1"; }
fail() { echo -e "  ${RED}  ✘${RESET} $1"; }
info() { echo -e "  ${CYAN}  ℹ${RESET} $1"; }
warn() { echo -e "  ${YELLOW}  ⚠${RESET} $1"; }
ask()  { echo -ne "  ${MAGENTA}  ?${RESET} $1"; }

separator() {
  echo -e "  ${GRAY}──────────────────────────────────────────────────────────${RESET}"
}

run() {
  local name="$1"; shift
  echo -ne "  ${YELLOW}  ⏳${RESET} ${name}..."
  if "$@" >/dev/null 2>&1; then
    echo -e "\r  ${GREEN}  ✔${RESET} ${name}                    "
  else
    echo -e "\r  ${RED}  ✘${RESET} ${name}                    "
    return 1
  fi
}

# ---- Téléchargement avec barre de progression ----
download() {
  local url="$1"
  local output="$2"
  local label="${3:-$(basename "$output")}"
  local BAR_W=40

  # ══════════════════════════════════════════════════════════════
  #  IMPORTANT : set +e obligatoire dans cette fonction
  #  Bash avec set -e tue le script quand (( expr )) retourne 0
  #  (= false = exit code 1). Toute la logique de progression
  #  doit tourner sans errexit.
  # ══════════════════════════════════════════════════════════════
  set +e

  # Récupération taille du fichier (HEAD)
  local expected
  expected=$(curl -sIL "$url" 2>/dev/null | grep -i content-length | tail -1 | awk '{print $2}' | tr -dc '0-9')
  expected="${expected:-0}"
  # Protection contre les valeurs vides/invalides
  [[ ! "$expected" =~ ^[0-9]+$ ]] && expected=0

  # Affichage du label + taille
  if [[ "$expected" -gt 0 ]]; then
    local total_h
    if [[ "$expected" -gt 1048576 ]]; then
      total_h="$(awk "BEGIN{printf \"%.1f Mo\", $expected/1048576}")"
    else
      total_h="$(awk "BEGIN{printf \"%.0f Ko\", $expected/1024}")"
    fi
    echo -e "  ${CYAN}  ⬇${RESET}  ${WHITE}${BOLD}${label}${RESET}  ${DIM}(${total_h})${RESET}"
  else
    echo -e "  ${CYAN}  ⬇${RESET}  ${WHITE}${BOLD}${label}${RESET}"
  fi

  # Supprimer le fichier s'il existe déjà (évite stat sur ancien fichier)
  rm -f "$output" 2>/dev/null

  # Lancement du téléchargement en arrière-plan
  wget -q "$url" -O "$output" &
  local pid=$!
  local start_time=$SECONDS

  # Petite attente pour que le fichier soit créé
  sleep 0.5

  # Barre de progression en temps réel
  while kill -0 "$pid" 2>/dev/null; do

    if [[ -f "$output" ]] && [[ "$expected" -gt 0 ]]; then
      local current
      current=$(stat -c%s "$output" 2>/dev/null)
      current="${current:-0}"
      [[ ! "$current" =~ ^[0-9]+$ ]] && current=0

      local pct=0
      if [[ "$expected" -gt 0 ]] && [[ "$current" -gt 0 ]]; then
        pct=$((current * 100 / expected))
      fi
      if [[ "$pct" -gt 100 ]]; then
        pct=100
      fi

      local filled=$((pct * BAR_W / 100))
      local empty=$((BAR_W - filled))
      local bar_done bar_left
      bar_done=$(printf '%*s' "$filled" '' | tr ' ' '█')
      bar_left=$(printf '%*s' "$empty" '' | tr ' ' '░')

      local dl_h
      if [[ "$current" -gt 1048576 ]]; then
        dl_h="$(awk "BEGIN{printf \"%.1f Mo\", $current/1048576}")"
      else
        dl_h="$(awk "BEGIN{printf \"%.0f Ko\", $current/1024}")"
      fi

      # Calcul vitesse
      local elapsed=$(( SECONDS - start_time ))
      local speed_h=""
      if [[ "$elapsed" -gt 0 ]] && [[ "$current" -gt 0 ]]; then
        local bps=$((current / elapsed))
        if [[ "$bps" -gt 1048576 ]]; then
          speed_h="$(awk "BEGIN{printf \"%.1f Mo/s\", $bps/1048576}")"
        else
          speed_h="$(awk "BEGIN{printf \"%.0f Ko/s\", $bps/1024}")"
        fi
      fi

      printf "\r      ${BLUE}[${GREEN}${bar_done}${GRAY}${bar_left}${BLUE}]${RESET} ${WHITE}%3d%%${RESET}  ${DIM}%s  %s${RESET}    " "$pct" "$dl_h" "$speed_h"

    elif [[ -f "$output" ]]; then
      # Taille inconnue : spinner + taille téléchargée
      local current
      current=$(stat -c%s "$output" 2>/dev/null)
      current="${current:-0}"
      [[ ! "$current" =~ ^[0-9]+$ ]] && current=0

      local dl_h
      if [[ "$current" -gt 1048576 ]]; then
        dl_h="$(awk "BEGIN{printf \"%.1f Mo\", $current/1048576}")"
      else
        dl_h="$(awk "BEGIN{printf \"%.0f Ko\", $current/1024}")"
      fi
      local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
      local elapsed=$(( SECONDS - start_time ))
      local spin_idx=$(( elapsed % ${#spin_chars[@]} ))
      printf "\r      ${CYAN}${spin_chars[$spin_idx]}${RESET}  ${DIM}Téléchargé : %s${RESET}    " "$dl_h"
    fi

    sleep 0.3
  done

  wait "$pid"
  local rc=$?

  if [[ $rc -eq 0 ]]; then
    # Barre complète en vert
    local full_bar
    full_bar=$(printf '%*s' "$BAR_W" '' | tr ' ' '█')
    local final_size
    final_size=$(stat -c%s "$output" 2>/dev/null)
    final_size="${final_size:-0}"
    local final_h
    if [[ "$final_size" -gt 1048576 ]]; then
      final_h="$(awk "BEGIN{printf \"%.1f Mo\", $final_size/1048576}")"
    else
      final_h="$(awk "BEGIN{printf \"%.0f Ko\", $final_size/1024}")"
    fi
    printf "\r      ${BLUE}[${GREEN}${full_bar}${BLUE}]${RESET} ${GREEN}${BOLD}100%%${RESET}  ${DIM}${final_h}${RESET}$(printf '%20s' '')\n"
    ok "${label}"

    # Réactiver errexit et retourner succès
    set -e
    return 0
  else
    echo
    fail "${label} — échec du téléchargement"

    # Réactiver errexit et retourner échec
    set -e
    return 1
  fi
}

confirm() {
  local msg="$1"
  local default="${2:-n}"
  if [[ "$default" == "o" ]]; then
    ask "$msg [${GREEN}O${RESET}/${RED}n${RESET}] : "
  else
    ask "$msg [${GREEN}o${RESET}/${RED}N${RESET}] : "
  fi
  read -r rep
  rep="${rep,,}"
  if [[ "$default" == "o" ]]; then
    [[ "$rep" != "n" ]]
  else
    [[ "$rep" == "o" || "$rep" == "oui" || "$rep" == "y" || "$rep" == "yes" ]]
  fi
}

# ==============================================================
#  VÉRIFICATION ROOT
# ==============================================================

if [[ "$EUID" -ne 0 ]]; then
  fail "Ce script doit être exécuté en ${BOLD}root${RESET}."
  exit 1
fi

# ==============================================================
#  VARIABLES GLOBALES
# ==============================================================

TOTAL_STEPS=10
MC_DIR="/opt/minecraft"
SCRIPTS_DIR="/opt/scripts"
PLUGIN_DIR="$MC_DIR/plugins"
SERVICE_NAME="minecraft.service"
YQ="/usr/local/bin/yq"

declare -a DB_NAMES=()
declare -a DB_USERS=()
declare -a DB_PASSES=()
MARIA_ROOT_PASS=""
MANUAL_DB_MODE=false

# ==============================================================
#  WELCOME
# ==============================================================

clear
echo
echo -e "  ${CYAN}${BOLD}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║                                                            ║"
echo "  ║      ⛏️   MINECRAFT SERVER — SETUP WIZARD  v2.0   ⛏️     ║"
echo "  ║                                                            ║"
echo "  ║      Java 21 · Paper · Plugins · MariaDB · Firewall       ║"
echo "  ║                                                            ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "  ${RESET}"
echo
echo -e "  ${WHITE}Ce script va configurer un serveur Minecraft complet.${RESET}"
echo -e "  ${WHITE}Chaque étape est optionnelle et nécessite votre accord.${RESET}"
echo
separator
echo
echo -e "  ${WHITE}${BOLD}Étapes disponibles :${RESET}"
echo -e "    ${CYAN} 1.${RESET} Installation Java 21 Temurin"
echo -e "    ${CYAN} 2.${RESET} Téléchargement Paper ${DIM}(auto-détection dernier build)${RESET}"
echo -e "    ${CYAN} 3.${RESET} Création service systemd + premier démarrage"
echo -e "    ${CYAN} 4.${RESET} Configuration firewall (UFW)"
echo -e "    ${CYAN} 5.${RESET} Installation des plugins ${DIM}(archive tar.gz)${RESET}"
echo -e "    ${CYAN} 6.${RESET} Installation MCXboxBroadcast"
echo -e "    ${CYAN} 7.${RESET} Configuration RCON + Geyser"
echo -e "    ${CYAN} 8.${RESET} Configuration server.properties ${DIM}(monde)${RESET}"
echo -e "    ${CYAN} 9.${RESET} Installation MariaDB + création bases"
echo -e "    ${CYAN}10.${RESET} Liaison plugins → bases de données"
echo
separator
echo

if ! confirm "Démarrer le setup ?"; then
  info "Setup annulé."
  exit 0
fi

# ==============================================================
#  PRÉ-REQUIS — VÉRIFICATION DES DÉPENDANCES
# ==============================================================

echo
echo -e "  ${CYAN}╔════════════════════════════════════════════════════════════╗${RESET}"
printf "  ${CYAN}║${RESET}  ${BOLD}${WHITE}%-58s${RESET}${CYAN}║${RESET}\n" "VÉRIFICATION DES DÉPENDANCES SYSTÈME"
echo -e "  ${CYAN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo

# --- Paquets à vérifier (commande → paquet apt) ---
declare -A DEP_MAP=(
  ["wget"]="wget"
  ["curl"]="curl"
  ["jq"]="jq"
  ["sed"]="sed"
  ["tar"]="tar"
  ["gpg"]="gnupg"
  ["grep"]="grep"
  ["gawk"]="gawk"
  ["lsb_release"]="lsb-release"
  ["systemctl"]="systemd"
  ["useradd"]="passwd"
  ["chown"]="coreutils"
  ["chmod"]="coreutils"
  ["mkdir"]="coreutils"
  ["cp"]="coreutils"
  ["cat"]="coreutils"
  ["ls"]="coreutils"
  ["id"]="coreutils"
  ["bash"]="bash"
  ["ca-certificates"]="ca-certificates"
)

# On commence par un apt update silencieux
echo -ne "  ${YELLOW}  ⏳${RESET} Mise à jour des dépôts APT..."
apt update -qq >/dev/null 2>&1
echo -e "\r  ${GREEN}  ✔${RESET} Mise à jour des dépôts APT                    "

MISSING_PKGS=()
ALREADY_OK=()
declare -A SEEN_PKGS=()

for cmd in "${!DEP_MAP[@]}"; do
  pkg="${DEP_MAP[$cmd]}"

  # Éviter les doublons de paquet (coreutils, etc.)
  [[ -n "${SEEN_PKGS[$pkg]:-}" ]] && continue
  SEEN_PKGS["$pkg"]=1

  # Vérif spéciale pour ca-certificates (pas une commande)
  if [[ "$cmd" == "ca-certificates" ]]; then
    if dpkg -s ca-certificates >/dev/null 2>&1; then
      ALREADY_OK+=("$pkg")
    else
      MISSING_PKGS+=("$pkg")
    fi
    continue
  fi

  if command -v "$cmd" >/dev/null 2>&1; then
    ALREADY_OK+=("$pkg")
  else
    MISSING_PKGS+=("$pkg")
  fi
done

# --- Affichage résumé ---
echo
echo -e "  ${GREEN}${BOLD}  Déjà installés :${RESET}"
echo -e "  ${GREEN}  ┌──────────────────────────────────────────────────────┐${RESET}"
LINE=""
COUNT=0
for pkg in "${ALREADY_OK[@]}"; do
  LINE+="$(printf '%-16s' "$pkg")"
  COUNT=$((COUNT+1))
  if [[ $COUNT -ge 3 ]]; then
    echo -e "  ${GREEN}  │${RESET}  ${WHITE}${LINE}${RESET}  ${GREEN}│${RESET}"
    LINE=""
    COUNT=0
  fi
done
[[ -n "$LINE" ]] && echo -e "  ${GREEN}  │${RESET}  ${WHITE}${LINE}$(printf '%*s' $((48 - ${#LINE})) '')${RESET}  ${GREEN}│${RESET}"
echo -e "  ${GREEN}  └──────────────────────────────────────────────────────┘${RESET}"

if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
  echo
  echo -e "  ${YELLOW}${BOLD}  Manquants (seront installés) :${RESET}"
  echo -e "  ${YELLOW}  ┌──────────────────────────────────────────────────────┐${RESET}"
  LINE=""
  COUNT=0
  for pkg in "${MISSING_PKGS[@]}"; do
    LINE+="$(printf '%-16s' "$pkg")"
    COUNT=$((COUNT+1))
    if [[ $COUNT -ge 3 ]]; then
      echo -e "  ${YELLOW}  │${RESET}  ${RED}${LINE}${RESET}  ${YELLOW}│${RESET}"
      LINE=""
      COUNT=0
    fi
  done
  [[ -n "$LINE" ]] && echo -e "  ${YELLOW}  │${RESET}  ${RED}${LINE}$(printf '%*s' $((48 - ${#LINE})) '')${RESET}  ${YELLOW}│${RESET}"
  echo -e "  ${YELLOW}  └──────────────────────────────────────────────────────┘${RESET}"
  echo

  info "Installation des paquets manquants..."
  for pkg in "${MISSING_PKGS[@]}"; do
    run "Installation $pkg" apt install -y "$pkg"
  done
else
  echo
  ok "Toutes les dépendances sont déjà installées."
fi

echo
separator
echo

# ==============================================================
#  ÉTAPE 1 — JAVA 21 TEMURIN
# ==============================================================

step_header 1 $TOTAL_STEPS "Installation Java 21 Temurin"

if confirm "Installer Java 21 Temurin ?"; then

  run "Suppression ancienne clé Adoptium" rm -f /etc/apt/keyrings/adoptium.gpg
  run "Suppression ancien dépôt Adoptium" rm -f /etc/apt/sources.list.d/adoptium.list
  run "Création dossier keyrings" mkdir -p /etc/apt/keyrings
  download "https://packages.adoptium.net/artifactory/api/gpg/key/public" "/tmp/adoptium.asc" "Clé GPG Adoptium"

  run "Conversion clé GPG" gpg --dearmor -o /tmp/adoptium.asc.gpg /tmp/adoptium.asc
  run "Installation clé système" mv /tmp/adoptium.asc.gpg /etc/apt/keyrings/adoptium.gpg
  run "Permissions clé" chmod 644 /etc/apt/keyrings/adoptium.gpg

  DISTRO=$(lsb_release -cs 2>/dev/null || echo "bookworm")
  run "Ajout dépôt Adoptium ($DISTRO)" bash -c "echo 'deb [signed-by=/etc/apt/keyrings/adoptium.gpg arch=amd64] https://packages.adoptium.net/artifactory/deb $DISTRO main' > /etc/apt/sources.list.d/adoptium.list"

  run "Mise à jour dépôts" apt update
  run "Installation Temurin 21 JRE" apt install -y temurin-21-jre

  JAVA_VER=$(java -version 2>&1 | head -n1)
  if echo "$JAVA_VER" | grep -q "21"; then
    ok "Java 21 installé : ${DIM}${JAVA_VER}${RESET}"
  else
    fail "Java 21 non détecté"
    exit 1
  fi

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 2 — TÉLÉCHARGEMENT PAPER (AUTO API)
# ==============================================================

step_header 2 $TOTAL_STEPS "Téléchargement Paper"

if confirm "Télécharger Paper ?"; then

  mkdir -p "$MC_DIR"
  cd "$MC_DIR"

  info "Interrogation de l'API PaperMC..."

  API_BASE="https://api.papermc.io/v2/projects/paper"
  PAPER_VERSION=""
  PAPER_BUILD=""
  PAPER_FILE=""

  VERSIONS_JSON=$(curl -sf "$API_BASE" 2>/dev/null || echo "")

  if [[ -n "$VERSIONS_JSON" ]]; then
    PAPER_VERSION=$(echo "$VERSIONS_JSON" | jq -r '.versions[-1]' 2>/dev/null || echo "")

    if [[ -n "$PAPER_VERSION" && "$PAPER_VERSION" != "null" ]]; then
      BUILDS_JSON=$(curl -sf "$API_BASE/versions/$PAPER_VERSION/builds" 2>/dev/null || echo "")

      if [[ -n "$BUILDS_JSON" ]]; then
        PAPER_BUILD=$(echo "$BUILDS_JSON" | jq -r '.builds[-1].build' 2>/dev/null || echo "")
        PAPER_FILE=$(echo "$BUILDS_JSON"  | jq -r '.builds[-1].downloads.application.name' 2>/dev/null || echo "")
      fi
    fi
  fi

  if [[ -n "$PAPER_VERSION" && "$PAPER_VERSION" != "null" && \
        -n "$PAPER_BUILD"   && "$PAPER_BUILD"   != "null" && \
        -n "$PAPER_FILE"    && "$PAPER_FILE"    != "null" ]]; then

    DOWNLOAD_URL="$API_BASE/versions/$PAPER_VERSION/builds/$PAPER_BUILD/downloads/$PAPER_FILE"

    echo
    echo -e "  ${WHITE}  ┌───────────────────────────────────────────────────┐${RESET}"
    echo -e "  ${WHITE}  │${RESET}                                                   ${WHITE}│${RESET}"
    echo -e "  ${WHITE}  │${RESET}   ${BOLD}Fichier${RESET}  : ${GREEN}${PAPER_FILE}${RESET}"
    echo -e "  ${WHITE}  │${RESET}   ${BOLD}Version${RESET}  : ${GREEN}${PAPER_VERSION}${RESET} ${GRAY}(Build #${PAPER_BUILD})${RESET}"
    echo -e "  ${WHITE}  │${RESET}                                                   ${WHITE}│${RESET}"
    echo -e "  ${WHITE}  └───────────────────────────────────────────────────┘${RESET}"
    echo

    if confirm "Installer ce build ?"; then
      download "$DOWNLOAD_URL" "$MC_DIR/$PAPER_FILE" "$PAPER_FILE"
      ok "Paper enregistré : ${DIM}${MC_DIR}/${PAPER_FILE}${RESET}"
    else
      warn "Téléchargement auto annulé"
      echo
      ask "Collez l'URL manuellement : "
      read -r MANUAL_URL
      if [[ -n "$MANUAL_URL" ]]; then
        PAPER_FILE=$(basename "$MANUAL_URL")
        download "$MANUAL_URL" "$MC_DIR/$PAPER_FILE" "$PAPER_FILE"
        ok "Paper enregistré : ${DIM}${MC_DIR}/${PAPER_FILE}${RESET}"
      fi
    fi

  else
    warn "API PaperMC inaccessible — passage en mode manuel"
    echo
    ask "Collez l'URL de téléchargement Paper : "
    read -r MANUAL_URL
    if [[ -z "$MANUAL_URL" ]]; then
      fail "URL vide"
      exit 1
    fi
    PAPER_FILE=$(basename "$MANUAL_URL")
    download "$MANUAL_URL" "$MC_DIR/$PAPER_FILE" "$PAPER_FILE"
    ok "Paper enregistré : ${DIM}${MC_DIR}/${PAPER_FILE}${RESET}"
  fi

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 3 — SERVICE SYSTEMD + PREMIER DÉMARRAGE
# ==============================================================

step_header 3 $TOTAL_STEPS "Service systemd + démarrage"

if confirm "Créer le service systemd et démarrer le serveur ?"; then

  mkdir -p "$SCRIPTS_DIR"

  if id "minecraft" &>/dev/null; then
    info "Utilisateur ${BOLD}minecraft${RESET} déjà existant"
  else
    run "Création utilisateur minecraft" useradd -r -m -d "$MC_DIR" -s /bin/bash minecraft
  fi

  cd "$MC_DIR"
  JAR_FILE=$(ls -1 *.jar 2>/dev/null | head -n1)

  if [[ -z "$JAR_FILE" ]]; then
    fail "Aucun fichier .jar trouvé dans $MC_DIR"
    exit 1
  fi

  info "JAR détecté : ${BOLD}${JAR_FILE}${RESET}"

  echo "eula=true" > "$MC_DIR/eula.txt"
  ok "EULA accepté"

  echo
  ask "RAM minimum (ex: 8G) : "
  read -r RAM_MIN
  ask "RAM maximum (ex: 12G) : "
  read -r RAM_MAX
  RAM_MIN="${RAM_MIN:-8G}"
  RAM_MAX="${RAM_MAX:-12G}"

  # Auto-ajout du suffixe G si l'utilisateur entre juste un nombre
  [[ "$RAM_MIN" =~ ^[0-9]+$ ]] && RAM_MIN="${RAM_MIN}G"
  [[ "$RAM_MAX" =~ ^[0-9]+$ ]] && RAM_MAX="${RAM_MAX}G"

  # Validation format (nombre + G/M/K)
  if ! [[ "$RAM_MIN" =~ ^[0-9]+[GgMmKk]$ ]]; then
    warn "Format RAM min invalide (${RAM_MIN}), défaut : 8G"
    RAM_MIN="8G"
  fi
  if ! [[ "$RAM_MAX" =~ ^[0-9]+[GgMmKk]$ ]]; then
    warn "Format RAM max invalide (${RAM_MAX}), défaut : 12G"
    RAM_MAX="12G"
  fi

  # Conversion en majuscule pour Java
  RAM_MIN="${RAM_MIN^^}"
  RAM_MAX="${RAM_MAX^^}"
  echo

  cat > "$SCRIPTS_DIR/start.sh" <<STARTEOF
#!/bin/bash
cd $MC_DIR
java -Xms${RAM_MIN} -Xmx${RAM_MAX} -jar $JAR_FILE nogui
STARTEOF
  chmod +x "$SCRIPTS_DIR/start.sh"
  ok "Script start.sh créé (RAM: ${RAM_MIN} / ${RAM_MAX})"

  cat > /etc/systemd/system/minecraft.service <<SVCEOF
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
User=minecraft
Group=minecraft
WorkingDirectory=$MC_DIR
ExecStart=$SCRIPTS_DIR/start.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SVCEOF

  chown -R minecraft:minecraft "$MC_DIR"
  chown -R minecraft:minecraft "$SCRIPTS_DIR"

  run "Rechargement systemd" systemctl daemon-reload
  run "Activation service" systemctl enable minecraft
  run "Démarrage serveur" systemctl restart minecraft

  info "Attente du démarrage (premier lancement = plus long)..."
  sleep 8

  if systemctl is-active --quiet minecraft; then
    ok "Serveur Minecraft ${GREEN}actif${RESET}"
  else
    fail "Le service n'a pas démarré correctement"
    echo
    echo -e "  ${YELLOW}${BOLD}  ┌── DIAGNOSTIC ─────────────────────────────────────────┐${RESET}"
    echo -e "  ${YELLOW}${BOLD}  │${RESET} Contenu de ${DIM}start.sh${RESET} :"
    echo -e "  ${GRAY}$(cat "$SCRIPTS_DIR/start.sh" | sed 's/^/    /')${RESET}"
    echo -e "  ${YELLOW}${BOLD}  │${RESET}"
    echo -e "  ${YELLOW}${BOLD}  │${RESET} Dernières lignes du journal :"
    echo -e "  ${GRAY}$(journalctl -u minecraft --no-pager -n 15 2>/dev/null | sed 's/^/    /')${RESET}"
    echo -e "  ${YELLOW}${BOLD}  └─────────────────────────────────────────────────────────┘${RESET}"
    echo
    warn "Le serveur peut mettre du temps au 1er lancement (génération du monde)."
    warn "Vérifiez avec : ${BOLD}journalctl -u minecraft -f${RESET}"
    echo
    if ! confirm "Continuer le setup malgré l'erreur ?"; then
      exit 1
    fi
  fi

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 4 — FIREWALL UFW
# ==============================================================

step_header 4 $TOTAL_STEPS "Configuration Firewall (UFW)"

if confirm "Configurer le firewall UFW ?"; then

  run "Installation UFW" apt install -y ufw
  run "Port 22/tcp  (SSH)" ufw allow 22/tcp
  run "Port 25565/tcp (Java)" ufw allow 25565/tcp
  run "Port 25575/tcp (RCON)" ufw allow 25575/tcp
  run "Port 19132/udp (Bedrock)" ufw allow 19132/udp

  if ufw status | grep -q "Status: inactive"; then
    run "Activation UFW" ufw --force enable
  else
    info "UFW déjà actif"
  fi

  ok "Firewall configuré"

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 5 — INSTALLATION PLUGINS
# ==============================================================

step_header 5 $TOTAL_STEPS "Installation des plugins"

if confirm "Installer les plugins depuis une archive tar.gz ?"; then

  ask "URL du fichier Plugins.tar.gz : "
  read -r PLUGIN_URL

  if [[ -z "$PLUGIN_URL" ]]; then
    fail "URL vide"
  else

    # --- Vérification : le serveur tourne-t-il ? ---
    if ! systemctl is-active --quiet minecraft 2>/dev/null; then
      warn "Le serveur Minecraft n'est pas actif."
      info "Tentative de (re)démarrage..."
      chown -R minecraft:minecraft "$MC_DIR" 2>/dev/null || true
      chown -R minecraft:minecraft "$SCRIPTS_DIR" 2>/dev/null || true
      systemctl restart "$SERVICE_NAME" 2>/dev/null || true
    else
      info "Serveur Minecraft actif — attente de la création du dossier plugins..."
    fi

    # --- Attente du dossier plugins ---
    TIMEOUT=90
    ELAPSED=0
    while [[ ! -d "$PLUGIN_DIR" ]]; do
      sleep 3
      ELAPSED=$((ELAPSED+3))

      # Toutes les 30s, vérifier si le serveur tourne encore
      if (( ELAPSED % 30 == 0 )); then
        if ! systemctl is-active --quiet minecraft 2>/dev/null; then
          warn "Le serveur s'est arrêté. Tentative de relance..."
          systemctl restart "$SERVICE_NAME" 2>/dev/null || true
        fi
      fi

      if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
        warn "Timeout : le dossier plugins n'a pas été créé par le serveur."
        echo
        echo -e "  ${YELLOW}${BOLD}  ┌── DIAGNOSTIC ──────────────────────────────────────────┐${RESET}"
        echo -e "  ${YELLOW}${BOLD}  │${RESET} Statut du service :"
        echo -e "  ${GRAY}    $(systemctl is-active minecraft 2>/dev/null || echo 'inactif')${RESET}"
        echo -e "  ${YELLOW}${BOLD}  │${RESET} Dernières lignes du journal :"
        echo -e "  ${GRAY}$(journalctl -u minecraft --no-pager -n 10 2>/dev/null | sed 's/^/    /')${RESET}"
        echo -e "  ${YELLOW}${BOLD}  └──────────────────────────────────────────────────────────┘${RESET}"
        echo

        info "Création manuelle du dossier plugins..."
        mkdir -p "$PLUGIN_DIR"
        chown minecraft:minecraft "$PLUGIN_DIR"
        ok "Dossier ${BOLD}$PLUGIN_DIR${RESET}${GREEN} créé manuellement"
        warn "Les plugins seront chargés au prochain démarrage du serveur."
        break
      fi
    done

    [[ -d "$PLUGIN_DIR" ]] && ok "Dossier plugins prêt"

    cd "$PLUGIN_DIR"
    download "$PLUGIN_URL" "$PLUGIN_DIR/Plugins.tar.gz" "Plugins.tar.gz"
    run "Extraction archive" tar -xzf "$PLUGIN_DIR/Plugins.tar.gz" -C "$PLUGIN_DIR"

    if [[ -f "$PLUGIN_DIR/MCXboxBroadcastExtension.jar" ]]; then
      mv "$PLUGIN_DIR/MCXboxBroadcastExtension.jar" /tmp/
      info "MCXboxBroadcastExtension.jar → /tmp"
    fi

    rm -f "$PLUGIN_DIR/Plugins.tar.gz"

    chown -R minecraft:minecraft "$MC_DIR"
    ok "Plugins installés"

    info "Redémarrage du serveur pour charger les plugins..."
    run "Redémarrage serveur" systemctl restart "$SERVICE_NAME"

    # Attente pour laisser le serveur générer les configs des plugins
    info "Attente de la génération des configs plugins (30s)..."
    sleep 30
  fi

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 6 — MCXBOXBROADCAST
# ==============================================================

step_header 6 $TOTAL_STEPS "Installation MCXboxBroadcast"

if confirm "Installer et configurer MCXboxBroadcast ?"; then

  TARGET_EXT="$PLUGIN_DIR/Geyser-Spigot/extensions"
  CONFIG_XBOX="$TARGET_EXT/mcxboxbroadcast/config.yml"
  LOCAL_JAR="/tmp/MCXboxBroadcastExtension.jar"

  # Vérification serveur actif
  if ! systemctl is-active --quiet minecraft 2>/dev/null; then
    warn "Le serveur Minecraft n'est pas actif."
    info "Tentative de (re)démarrage..."
    chown -R minecraft:minecraft "$MC_DIR" 2>/dev/null || true
    systemctl restart "$SERVICE_NAME" 2>/dev/null || true
  fi

  info "Attente du dossier extensions Geyser..."
  TIMEOUT=90; ELAPSED=0
  while [[ ! -d "$TARGET_EXT" ]]; do
    sleep 3
    ELAPSED=$((ELAPSED+3))
    if (( ELAPSED % 30 == 0 )); then
      if ! systemctl is-active --quiet minecraft 2>/dev/null; then
        warn "Le serveur s'est arrêté. Tentative de relance..."
        systemctl restart "$SERVICE_NAME" 2>/dev/null || true
      fi
    fi
    if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
      warn "Timeout : dossier extensions non créé par Geyser."
      echo
      echo -e "  ${YELLOW}${BOLD}  ┌── DIAGNOSTIC ──────────────────────────────────────────┐${RESET}"
      echo -e "  ${YELLOW}${BOLD}  │${RESET} Statut du service : $(systemctl is-active minecraft 2>/dev/null || echo 'inactif')"
      echo -e "  ${YELLOW}${BOLD}  │${RESET} Geyser-Spigot présent : $(ls "$PLUGIN_DIR"/Geyser-Spigot*.jar 2>/dev/null && echo 'oui' || echo 'NON')"
      echo -e "  ${YELLOW}${BOLD}  │${RESET} Dernières lignes du journal :"
      echo -e "  ${GRAY}$(journalctl -u minecraft --no-pager -n 10 2>/dev/null | sed 's/^/    /')${RESET}"
      echo -e "  ${YELLOW}${BOLD}  └──────────────────────────────────────────────────────────┘${RESET}"
      echo

      info "Création manuelle du dossier extensions..."
      mkdir -p "$TARGET_EXT"
      chown -R minecraft:minecraft "$PLUGIN_DIR/Geyser-Spigot"
      ok "Dossier ${BOLD}$TARGET_EXT${RESET}${GREEN} créé manuellement"
      break
    fi
  done
  ok "Dossier extensions prêt"

  if [[ ! -f "$LOCAL_JAR" ]]; then
    fail "MCXboxBroadcastExtension.jar introuvable dans /tmp"
    warn "Étape ignorée"
  else
    run "Copie extension" cp "$LOCAL_JAR" "$TARGET_EXT/"
    chown -R minecraft:minecraft "$MC_DIR"
    run "Redémarrage serveur" systemctl restart "$SERVICE_NAME"

    info "Attente config.yml MCXboxBroadcast..."
    TIMEOUT=60; ELAPSED=0
    while [[ ! -f "$CONFIG_XBOX" ]]; do
      sleep 3
      ELAPSED=$((ELAPSED+3))
      if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
        warn "Timeout : config.yml non généré automatiquement."
        warn "Le fichier sera créé au prochain démarrage du serveur."
        warn "Vous pourrez configurer MCXboxBroadcast manuellement plus tard."
        break
      fi
    done

    if [[ -f "$CONFIG_XBOX" ]]; then
      ok "config.yml détecté"

    echo
    ask "Remote address : "
    read -r REMOTE_ADDRESS
    ask "Remote port : "
    read -r REMOTE_PORT
    echo

    if [[ -n "$REMOTE_ADDRESS" && -n "$REMOTE_PORT" ]]; then
      cp "$CONFIG_XBOX" "$CONFIG_XBOX.bak"
      sed -i "s/^ *remote-address: .*/  remote-address: $REMOTE_ADDRESS/" "$CONFIG_XBOX"
      sed -i "s/^ *remote-port: .*/  remote-port: $REMOTE_PORT/" "$CONFIG_XBOX"
      ok "MCXboxBroadcast configuré"
      run "Redémarrage serveur" systemctl restart "$SERVICE_NAME"
    else
      fail "Valeurs invalides"
    fi
    fi
  fi

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 7 — RCON + GEYSER
# ==============================================================

step_header 7 $TOTAL_STEPS "Configuration RCON + Geyser"

if confirm "Configurer RCON et Geyser ?"; then

  SERVER_PROPS="$MC_DIR/server.properties"
  GEYSER_CFG="$PLUGIN_DIR/Geyser-Spigot/config.yml"

  echo
  echo -e "  ${WHITE}${BOLD}  Configuration RCON${RESET}"
  separator
  ask "Mot de passe RCON : "
  read -rs RCON_PASS
  echo
  ask "Confirmation : "
  read -rs RCON_PASS_CONFIRM
  echo
  echo

  if [[ "$RCON_PASS" != "$RCON_PASS_CONFIRM" ]]; then
    fail "Les mots de passe ne correspondent pas"
    exit 1
  fi

  if [[ -f "$SERVER_PROPS" ]]; then
    sed -i "s/^enable-rcon=.*/enable-rcon=true/" "$SERVER_PROPS"
    sed -i "s/^rcon.port=.*/rcon.port=25575/" "$SERVER_PROPS"
    if grep -q "^rcon.password=" "$SERVER_PROPS"; then
      sed -i "s/^rcon.password=.*/rcon.password=$RCON_PASS/" "$SERVER_PROPS"
    else
      echo "rcon.password=$RCON_PASS" >> "$SERVER_PROPS"
    fi
    ok "RCON configuré"
  else
    fail "server.properties introuvable"
  fi

  if [[ -f "$GEYSER_CFG" ]]; then
    sed -i "s/auth-type:.*/auth-type: floodgate/" "$GEYSER_CFG"
    ok "Geyser configuré (auth-type: floodgate)"
  else
    warn "Config Geyser introuvable — ignoré"
  fi

  run "Redémarrage serveur" systemctl restart "$SERVICE_NAME"

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 8 — SERVER PROPERTIES (MONDE)
# ==============================================================

step_header 8 $TOTAL_STEPS "Configuration server.properties"

if confirm "Configurer un nouveau monde ?"; then

  SERVER_PROPS="$MC_DIR/server.properties"

  run "Arrêt serveur" systemctl stop "$SERVICE_NAME"

  for world_dir in "$MC_DIR/world" "$MC_DIR/world_nether" "$MC_DIR/world_the_end"; do
    if [[ -d "$world_dir" ]]; then
      rm -rf "$world_dir"
      ok "Supprimé : $(basename "$world_dir")"
    fi
  done

  echo
  echo -e "  ${WHITE}${BOLD}  Paramètres du nouveau monde${RESET}"
  separator
  ask "Nom du monde (level-name) : "
  read -r LEVEL_NAME
  ask "Seed (level-seed) : "
  read -r LEVEL_SEED
  ask "Difficulté (peaceful/easy/normal/hard) : "
  read -r DIFFICULTY
  echo

  if [[ -f "$SERVER_PROPS" ]]; then
    sed -i "s/^level-name=.*/level-name=$LEVEL_NAME/" "$SERVER_PROPS"
    sed -i "s/^level-seed=.*/level-seed=$LEVEL_SEED/" "$SERVER_PROPS"
    sed -i "s/^difficulty=.*/difficulty=$DIFFICULTY/" "$SERVER_PROPS"
    ok "server.properties mis à jour"
  else
    fail "server.properties introuvable"
  fi

  run "Redémarrage serveur" systemctl restart "$SERVICE_NAME"
  ok "Nouveau monde sera généré au prochain chargement"

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 9 — MARIADB + BASES DE DONNÉES
# ==============================================================

step_header 9 $TOTAL_STEPS "Installation MariaDB + création bases"

if confirm "Installer MariaDB et créer des bases de données ?"; then

  run "Installation MariaDB" apt install -y mariadb-server
  run "Activation MariaDB" systemctl enable mariadb
  run "Démarrage MariaDB" systemctl start mariadb

  # --- yq v4 ---
  if [[ ! -x "$YQ" ]] || ! "$YQ" --version 2>/dev/null | grep -q "v4"; then
    info "Installation de yq v4..."
    apt remove -y yq >/dev/null 2>&1 || true
    rm -f /usr/bin/yq /usr/local/bin/yq
    download "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64" "$YQ" "yq v4"
    chmod +x "$YQ"
    if ! "$YQ" --version | grep -q "v4"; then
      fail "Erreur installation yq"
      exit 1
    fi
    ok "yq v4 installé"
  else
    ok "yq v4 déjà présent"
  fi

  # --- Mot de passe root ---
  echo
  echo -e "  ${WHITE}${BOLD}  Mot de passe ROOT MariaDB${RESET}"
  separator
  ask "Nouveau mot de passe root : "
  read -rs MARIA_ROOT_PASS
  echo
  ask "Confirmation : "
  read -rs ROOT_PASS_CONFIRM
  echo
  echo

  if [[ "$MARIA_ROOT_PASS" != "$ROOT_PASS_CONFIRM" ]]; then
    fail "Les mots de passe ne correspondent pas"
    exit 1
  fi

  mysql -u root <<SQLEOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MARIA_ROOT_PASS';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQLEOF

  ok "MariaDB sécurisé"

  # --- Création des bases ---
  echo
  echo -e "  ${WHITE}${BOLD}  Création des bases de données${RESET}"
  separator
  ask "Combien de bases à créer ? "
  read -r DB_COUNT
  echo

  for ((i=1; i<=DB_COUNT; i++)); do
    echo -e "  ${CYAN}  ── Base $i/$DB_COUNT ──${RESET}"
    ask "Nom de la base : "
    read -r db_name
    ask "Utilisateur : "
    read -r db_user
    ask "Mot de passe : "
    read -rs db_pass
    echo
    echo

    mysql -u root -p"$MARIA_ROOT_PASS" <<DBEOF
CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_pass';
GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
DBEOF

    ok "Base ${BOLD}$db_name${RESET} créée (user: ${BOLD}$db_user${RESET})"

    DB_NAMES+=("$db_name")
    DB_USERS+=("$db_user")
    DB_PASSES+=("$db_pass")
  done

  # Résumé
  echo
  echo -e "  ${WHITE}${BOLD}  Récapitulatif des bases créées${RESET}"
  separator
  echo
  echo -e "  ${WHITE}  ┌───────────────────────┬───────────────────────┐${RESET}"
  printf "  ${WHITE}  │${RESET} ${BOLD}%-21s${RESET} ${WHITE}│${RESET} ${BOLD}%-21s${RESET} ${WHITE}│${RESET}\n" "Base" "Utilisateur"
  echo -e "  ${WHITE}  ├───────────────────────┼───────────────────────┤${RESET}"
  for idx in "${!DB_NAMES[@]}"; do
    printf "  ${WHITE}  │${RESET} ${GREEN}%-21s${RESET} ${WHITE}│${RESET} ${CYAN}%-21s${RESET} ${WHITE}│${RESET}\n" "${DB_NAMES[$idx]}" "${DB_USERS[$idx]}"
  done
  echo -e "  ${WHITE}  └───────────────────────┴───────────────────────┘${RESET}"
  echo

else
  warn "Étape ignorée"
fi

# ==============================================================
#  ÉTAPE 10 — LIAISON PLUGINS → BASES DE DONNÉES
# ==============================================================

step_header 10 $TOTAL_STEPS "Liaison plugins → bases de données"

if [[ ${#DB_NAMES[@]} -eq 0 ]]; then
  warn "Aucune base de données en mémoire."
  warn "Les credentials sont disponibles uniquement si l'étape 9 a été exécutée."
  echo
  if confirm "Continuer en saisie manuelle ?"; then
    MANUAL_DB_MODE=true
  else
    warn "Étape ignorée"
    # Sauter vers la fin
    SKIP_STEP10=true
  fi
fi

if [[ "${SKIP_STEP10:-false}" != "true" ]]; then

  if confirm "Configurer les plugins pour utiliser MariaDB ?"; then

    declare -A PLUGIN_CONFIGS=(
      ["LuckPerms"]="$PLUGIN_DIR/LuckPerms/config.yml"
      ["Jobs"]="$PLUGIN_DIR/Jobs/generalConfig.yml"
      ["Towny"]="$PLUGIN_DIR/Towny/settings/database.yml"
      ["AuraSkills"]="$PLUGIN_DIR/AuraSkills/config.yml"
    )

    for plugin in LuckPerms Jobs Towny AuraSkills; do

      CONFIG="${PLUGIN_CONFIGS[$plugin]}"

      if [[ ! -f "$CONFIG" ]]; then
        warn "Config ${BOLD}$plugin${RESET} introuvable — ignoré"
        continue
      fi

      echo
      echo -e "  ${MAGENTA}${BOLD}  ╔══════════════════════════════════╗${RESET}"
      printf "  ${MAGENTA}${BOLD}  ║${RESET}  ${WHITE}${BOLD}%-32s${RESET}${MAGENTA}${BOLD}║${RESET}\n" "$plugin"
      echo -e "  ${MAGENTA}${BOLD}  ╚══════════════════════════════════╝${RESET}"
      echo

      if ! confirm "Lier ${BOLD}$plugin${RESET} à une base de données ?"; then
        info "$plugin ignoré"
        continue
      fi

      DB_SEL=""
      USER_SEL=""
      PASS_SEL=""

      if [[ "$MANUAL_DB_MODE" == "false" && ${#DB_NAMES[@]} -gt 0 ]]; then

        echo
        echo -e "  ${WHITE}  Bases disponibles :${RESET}"
        echo
        for idx in "${!DB_NAMES[@]}"; do
          echo -e "    ${CYAN}  $((idx+1)))${RESET} ${BOLD}${DB_NAMES[$idx]}${RESET} ${GRAY}(user: ${DB_USERS[$idx]})${RESET}"
        done
        echo
        ask "Choix (1-${#DB_NAMES[@]}) : "
        read -r choice
        local_idx=$((choice - 1))

        if [[ $local_idx -ge 0 && $local_idx -lt ${#DB_NAMES[@]} ]]; then
          DB_SEL="${DB_NAMES[$local_idx]}"
          USER_SEL="${DB_USERS[$local_idx]}"
          PASS_SEL="${DB_PASSES[$local_idx]}"
        else
          fail "Choix invalide"
          continue
        fi

        ok "→ Base : ${BOLD}$DB_SEL${RESET} | User : ${BOLD}$USER_SEL${RESET}"

      else
        ask "Nom de la base : "
        read -r DB_SEL
        ask "Utilisateur : "
        read -r USER_SEL
        ask "Mot de passe : "
        read -rs PASS_SEL
        echo
      fi

      # Backup fichier config
      cp "$CONFIG" "$CONFIG.bak"

      # ─────────────────────────────────────────
      #  LUCKPERMS
      # ─────────────────────────────────────────
      if [[ "$plugin" == "LuckPerms" ]]; then

        # Clé avec tiret → yq syntaxe : ."storage-method"
        # Bug original : .storage.method ne correspondait pas
        "$YQ" -i '."storage-method" = "mysql"' "$CONFIG"

        # Connexion dans la section data
        "$YQ" -i '.data.address = "localhost:3306"' "$CONFIG"
        "$YQ" -i '.data.database = "'"$DB_SEL"'"' "$CONFIG"
        "$YQ" -i '.data.username = "'"$USER_SEL"'"' "$CONFIG"
        "$YQ" -i '.data.password = "'"$PASS_SEL"'"' "$CONFIG"

        ok "LuckPerms → storage-method: mysql"
      fi

      # ─────────────────────────────────────────
      #  JOBS
      # ─────────────────────────────────────────
      if [[ "$plugin" == "Jobs" ]]; then

        "$YQ" -i '.storage.method = "mysql"' "$CONFIG"
        "$YQ" -i '.mysql.username = "'"$USER_SEL"'"' "$CONFIG"
        "$YQ" -i '.mysql.password = "'"$PASS_SEL"'"' "$CONFIG"
        "$YQ" -i '.mysql.hostname = "localhost"' "$CONFIG"
        "$YQ" -i '.mysql.port = "3306"' "$CONFIG"
        "$YQ" -i '.mysql.database = "'"$DB_SEL"'"' "$CONFIG"

        ok "Jobs → storage.method: mysql"
      fi

      # ─────────────────────────────────────────
      #  TOWNY
      # ─────────────────────────────────────────
      if [[ "$plugin" == "Towny" ]]; then

        # Détection de la structure YAML (varie selon la version)
        # Structure A (récent) : database_load / sql.* au root
        # Structure B (ancien) : database.database_load / database.sql.*

        towny_root=$("$YQ" e '.database_load // ""' "$CONFIG" 2>/dev/null)
        towny_nested=$("$YQ" e '.database.database_load // ""' "$CONFIG" 2>/dev/null)

        if [[ -n "$towny_nested" && "$towny_nested" != "" ]]; then
          info "Structure Towny détectée : imbriquée (database.*)"
          "$YQ" -i '.database.database_load = "mysql"' "$CONFIG"
          "$YQ" -i '.database.database_save = "mysql"' "$CONFIG"
          "$YQ" -i '.database.sql.hostname = "localhost"' "$CONFIG"
          "$YQ" -i '.database.sql.port = 3306' "$CONFIG"
          "$YQ" -i '.database.sql.dbname = "'"$DB_SEL"'"' "$CONFIG"
          "$YQ" -i '.database.sql.username = "'"$USER_SEL"'"' "$CONFIG"
          "$YQ" -i '.database.sql.password = "'"$PASS_SEL"'"' "$CONFIG"

        elif [[ -n "$towny_root" && "$towny_root" != "" ]]; then
          # Bug original : utilisait .database.sql.* au lieu de .sql.*
          info "Structure Towny détectée : racine (sql.*)"
          "$YQ" -i '.database_load = "mysql"' "$CONFIG"
          "$YQ" -i '.database_save = "mysql"' "$CONFIG"
          "$YQ" -i '.sql.hostname = "localhost"' "$CONFIG"
          "$YQ" -i '.sql.port = 3306' "$CONFIG"
          "$YQ" -i '.sql.dbname = "'"$DB_SEL"'"' "$CONFIG"
          "$YQ" -i '.sql.username = "'"$USER_SEL"'"' "$CONFIG"
          "$YQ" -i '.sql.password = "'"$PASS_SEL"'"' "$CONFIG"

        else
          warn "Structure Towny non reconnue — application forcée (racine)"
          "$YQ" -i '.database_load = "mysql"' "$CONFIG"
          "$YQ" -i '.database_save = "mysql"' "$CONFIG"
          "$YQ" -i '.sql.hostname = "localhost"' "$CONFIG"
          "$YQ" -i '.sql.port = 3306' "$CONFIG"
          "$YQ" -i '.sql.dbname = "'"$DB_SEL"'"' "$CONFIG"
          "$YQ" -i '.sql.username = "'"$USER_SEL"'"' "$CONFIG"
          "$YQ" -i '.sql.password = "'"$PASS_SEL"'"' "$CONFIG"
        fi

        ok "Towny → database_load: mysql"
      fi

      # ─────────────────────────────────────────
      #  AURASKILLS
      # ─────────────────────────────────────────
      if [[ "$plugin" == "AuraSkills" ]]; then

        "$YQ" -i '.sql.enabled = true' "$CONFIG"
        "$YQ" -i '.sql.type = "mysql"' "$CONFIG"
        "$YQ" -i '.sql.host = "localhost"' "$CONFIG"
        "$YQ" -i '.sql.port = 3306' "$CONFIG"
        "$YQ" -i '.sql.database = "'"$DB_SEL"'"' "$CONFIG"
        "$YQ" -i '.sql.username = "'"$USER_SEL"'"' "$CONFIG"
        "$YQ" -i '.sql.password = "'"$PASS_SEL"'"' "$CONFIG"

        ok "AuraSkills → sql.enabled: true"
      fi

      # Validation YAML
      if ! "$YQ" e '.' "$CONFIG" >/dev/null 2>&1; then
        fail "YAML invalide après modification — rollback"
        mv "$CONFIG.bak" "$CONFIG"
      else
        rm -f "$CONFIG.bak"
        ok "$plugin validé ✓"
      fi

    done

    echo
    run "Redémarrage serveur" systemctl restart "$SERVICE_NAME" || true

  else
    warn "Étape ignorée"
  fi

fi

# ==============================================================
#  FIN
# ==============================================================

echo
echo -e "  ${GREEN}${BOLD}"
echo "  ╔════════════════════════════════════════════════════════════╗"
echo "  ║                                                            ║"
echo "  ║      ✅  SETUP TERMINÉ AVEC SUCCÈS                        ║"
echo "  ║                                                            ║"
echo "  ╚════════════════════════════════════════════════════════════╝"
echo -e "  ${RESET}"
echo -e "  ${WHITE}Commandes utiles :${RESET}"
echo -e "    ${CYAN}systemctl status minecraft${RESET}    — état du serveur"
echo -e "    ${CYAN}journalctl -u minecraft -f${RESET}    — logs temps réel"
echo -e "    ${CYAN}systemctl restart minecraft${RESET}   — redémarrer"
echo
