#!/bin/bash

# ==============================
#  INSTALL SCRIPTS FROM ARCHIVE
# ==============================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
RESET="\e[0m"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Exécution en root requise.${RESET}"
  exit 1
fi

# Vérification et installation des dépendances
echo -e "${CYAN}Vérification des dépendances...${RESET}"

if ! command -v wget >/dev/null 2>&1; then
  echo -e "${YELLOW}Installation de wget...${RESET}"
  apt update -y
  apt install -y wget
fi

if ! command -v sed >/dev/null 2>&1; then
  echo -e "${YELLOW}Installation de sed...${RESET}"
  apt update -y
  apt install -y sed
fi

#====================================================================
# Demande URL archive scripts
#====================================================================

echo -e "${CYAN}Entrez l'URL complète de scripts.tar.gz :${RESET}"
read -r URL

if [ -z "$URL" ]; then
  echo -e "${RED}URL invalide.${RESET}"
  exit 1
fi

# Téléchargement
echo -e "${YELLOW}Téléchargement de l'archive...${RESET}"

if wget "$URL" -O /tmp/scripts.tar.gz; then
    echo -e "${GREEN}Téléchargement terminé.${RESET}"
else
    echo -e "${RED}Echec du téléchargement.${RESET}"
    exit 1
fi

mkdir -p /tmp/scripts-extract

tar -xzf /tmp/scripts.tar.gz -C /tmp/scripts-extract

echo -e "${CYAN}Tri des scripts...${RESET}"

mkdir -p /opt/scripts
mkdir -p /scripts-purge

for FILE in /tmp/scripts-extract/*.sh; do
    [ -f "$FILE" ] || continue

    BASENAME=$(basename "$FILE")

    if [[ "$BASENAME" == *purge* ]]; then
        mv "$FILE" /scripts-purge/
        echo -e "${YELLOW}Script purge détecté : $BASENAME${RESET}"
    else
        mv "$FILE" /opt/scripts/
        echo -e "${GREEN}Script normal : $BASENAME${RESET}"
    fi
done

# Correction CRLF
echo -e "${CYAN}Conversion des fins de ligne (CRLF → LF)...${RESET}"
find /opt/scripts -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;

find /scripts-purge -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Rendre exécutables tous les scripts .sh
echo -e "${CYAN}Activation des scripts trouvés...${RESET}"

COUNT=0
for FILE in /opt/scripts/*.sh; do
    if [ -f "$FILE" ]; then
        chmod +x "$FILE"
        echo -e "${GREEN}Activé : $(basename "$FILE")${RESET}"
        COUNT=$((COUNT+1))
    fi
done

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}Aucun script .sh trouvé dans l'archive.${RESET}"
else
    echo -e "${GREEN}$COUNT script(s) prêt(s).${RESET}"
fi

for FILE in /scripts-purge/*.sh; do
    if [ -f "$FILE" ]; then
        chmod +x "$FILE"
        echo -e "${GREEN}Activé : $(basename "$FILE")${RESET}"
        COUNT=$((COUNT+1))
    fi
done

if [ "$COUNT" -eq 0 ]; then
    echo -e "${YELLOW}Aucun script .sh trouvé dans l'archive.${RESET}"
else
    echo -e "${GREEN}$COUNT script(s) prêt(s).${RESET}"
fi

# ==============================
# EXECUTION DES SCRIPTS EN ORDRE NUMERIQUE
# ==============================

echo -e "${CYAN}Exécution des scripts dans l'ordre numérique...${RESET}"

for FILE in $(ls /opt/scripts/*.sh 2>/dev/null | sort -V); do
    BASENAME=$(basename "$FILE")

    # Vérifie que le nom commence par un chiffre suivi d'un tiret
    if [[ "$BASENAME" =~ ^[0-9]+- ]]; then
        echo -e "${YELLOW}Exécution de $BASENAME...${RESET}"

        if "$FILE"; then
            echo -e "${GREEN}$BASENAME exécuté avec succès.${RESET}"
        else
            echo -e "${RED}Erreur lors de l'exécution de $BASENAME.${RESET}"
            exit 1
        fi
    fi
done

echo -e "${GREEN}Tous les scripts numérotés ont été exécutés.${RESET}"

# Nettoyage
rm -f /tmp/scripts.tar.gz
rm -rf /tmp/scripts-extract

echo -e "${GREEN}Installation terminée.${RESET}"