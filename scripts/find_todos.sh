#!/bin/bash

# --- Configuration des couleurs ---
BOLD_BLUE='\033[1;34m'
BOLD_PURPLE='\033[1;35m'
BOLD_RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
RESET='\033[0m'

# --- Configuration ---
BASE_BRANCH=""
for arg in "$@"; do
  case "$arg" in
    --from=*) BASE_BRANCH="${arg#--from=}" ;;
  esac
done

if [ -z "$BASE_BRANCH" ]; then
  if git show-ref --verify --quiet refs/heads/main; then BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master; then BASE_BRANCH="master"
  elif git show-ref --verify --quiet refs/heads/dev; then BASE_BRANCH="dev"
  else BASE_BRANCH="main"; fi
fi

if ! git show-ref --verify --quiet refs/heads/$BASE_BRANCH; then
  printf "${BOLD_RED}❌ Error: branch '${BASE_BRANCH}' does not exist.${RESET}\n"
  exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)

printf "${BOLD_PURPLE}🕵️  TODOS AUDIT 🕵️${RESET}\n"
printf "Branch : ${CYAN}$CURRENT_BRANCH${RESET} (vs ${CYAN}$BASE_BRANCH${RESET})\n\n"

# ==============================================================================
# ÉTAPE 1 : Branch history analysis
# ==============================================================================
printf "${BOLD_BLUE}1️⃣  Branch history debt :${RESET}\n"
git diff -U0 $BASE_BRANCH...HEAD | awk -v BLUE="$BOLD_BLUE" -v YEL="$YELLOW" -v GRY="$GRAY" -v RES="$RESET" '
    /^\+\+\+ b\// { cur=$NF; sub(/^b\//,"",cur) }
    /^\+/ && tolower($0) ~ /todo/ {
        c=substr($0,2); sub(/^[ \t]+/,"",c)
        print "   📂 " BLUE cur RES " | " YEL "Commited" RES " : " GRY c RES
        f=1
    }
    END { if (!f) print "   " GRY "Nothing found inside the branch commits." RES }
'
printf "\n"

# ==============================================================================
# ÉTAPE 2 : Local state analysis
# ==============================================================================
printf "${BOLD_BLUE}2️⃣  Ongoing changes :${RESET}\n"
git diff -U0 HEAD | awk -v BLUE="$BOLD_BLUE" -v GRN="$GREEN" -v RED="$YELLOW" -v GRY="$GRAY" -v RES="$RESET" '
    /^diff --git/ { cur=substr($NF,3); next }
    /^(\+\+\+|---) / { next }
    /^-/ && tolower($0) ~ /todo/ {
        c=substr($0,2); sub(/^[ \t]+/,"",c)
        print "   📂 " BLUE cur RES " | " GRN "✅ Resolved" RES " : " GRY c RES
        f=1
    }
    /^\+/ && tolower($0) ~ /todo/ {
        c=substr($0,2); sub(/^[ \t]+/,"",c)
        print "   📂 " BLUE cur RES " | " RED "🆕 Added" RES " : " GRY c RES
        f=1
    }
    END { if (!f) print "   " GRY "No uncommited changes." RES }
'
printf "\n"

# ==============================================================================
# ÉTAPE 3 : SYNTHÈSE FINALE
# ==============================================================================
printf "${BOLD_PURPLE}📝 Synthesis :${RESET}\n"

git diff -U0 $BASE_BRANCH | awk -v BLUE="$BOLD_BLUE" -v RED="$BOLD_RED" -v GRY="$GRAY" -v RES="$RESET" '
    /^diff --git/ { cur=substr($NF,3); next }
    /^(\+\+\+|---) / { next }

    /^\+/ && tolower($0) ~ /todo/ {
        c=substr($0,2); sub(/^[ \t]+/,"",c)
        print "👉 📂 " BLUE cur RES " : " RED c RES
        count++
    }
    END {
        if (count > 0) {
            print "\n" RED "⚠️  Total : " count " TODO(s) remaining." RES
        } else {
            print "\n" BLUE "✨ No residual TODO. Clean !" RES
        }
    }
'
printf "\n"
