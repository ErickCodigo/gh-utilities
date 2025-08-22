#!/bin/bash

SOURCE_BRANCH=$1
USERNAME=$2
BASENAME=$3
LINE_LIMIT=10
MAIN_BRANCH="master"

git fetch origin
git checkout $SOURCE_BRANCH

COMMITS=($(git rev-list --reverse $SOURCE_BRANCH ^$MAIN_BRANCH))

CHUNK=1
CHUNK_LINES=0
CHUNK_COMMITS=()
PREV_BRANCH=$MAIN_BRANCH

for COMMIT in "${COMMITS[@]}"; do
  LINES=$(git show --numstat $COMMIT | awk '{ add += $1 + $2 } END { print add }') # Command substitution | awk mini-language

  if [ $((CHUNK_LINES + LINES)) -gt $LINE_LIMIT ]; then # Sintaxis de test | Expansión aritmatica | greater than
    if [ ${#CHUNK_COMMITS[@]} -gt 0 ]; then # Longitud
      # Crear nueva rama
      BRANCH_NAME="$USERNAME/$BASENAME-chunk-$CHUNK"
      git checkout -b $BRANCH_NAME $PREV_BRANCH

      for c in "${CHUNK_COMMITS[@]}"; do
        git cherry-pick $c
      done

      git push "$REPO" "$BRANCH_NAME"

      gh pr create \
        --base "$PREV_BRANCH" \
        --head "$BRANCH_NAME" \
        --title "Chunk $CHUNK: $BASENAME" \
        --body "Auto-generated chunk of changes."

      # Preparar siguiente grupo
      PREV_BRANCH=$BRANCH_NAME
      CHUNK=$((CHUNK + 1))
      CHUNK_COMMITS=()
      CHUNK_LINES=0
    fi
  fi

  CHUNK_COMMITS+=($COMMIT) # Añadir un elemento al final
  CHUNK_LINES=$((CHUNK_LINES + LINES))
done

# Último grupo
if [ ${#CHUNK_COMMITS[@]} -gt 0 ]; then
  BRANCH_NAME="$USERNAME/$BASENAME-chunk-$CHUNK"
  git checkout -b $BRANCH_NAME $PREV_BRANCH

  for c in "${CHUNK_COMMITS[@]}"; do
    git cherry-pick $c
  done

  git push "$REPO" "$BRANCH_NAME"

  gh pr create \
    --base "$PREV_BRANCH" \
    --head "$BRANCH_NAME" \
    --title "Chunk $CHUNK: $BASENAME" \
    --body "Auto-generated chunk of changes."
fi
