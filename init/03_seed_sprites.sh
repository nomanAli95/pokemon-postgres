#!/usr/bin/env bash
set -e

SPRITE_BASE="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"

psql_as_ash() {
    psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-ash}" -d "${POSTGRES_DB:-pokedex}" "$@"
}

# Convert binary file to hex string using python3
to_hex() {
    python3 -c "
import sys
with open(sys.argv[1], 'rb') as f:
    data = f.read()
sys.stdout.write(data.hex())
" "$1"
}

echo "--> Fetching Pokemon IDs from DB..." >&2
IDS=$(psql_as_ash -t -A -c "SELECT id FROM pokemon ORDER BY id")
TOTAL=$(echo "$IDS" | wc -w | tr -d ' ')
echo "--> Downloading sprites for ${TOTAL} Pokemon (this may take a while)..." >&2

SQL_FILE="/tmp/sprites_insert.sql"
echo "BEGIN;" > "$SQL_FILE"

COUNT=0
for id in $IDS; do
    COUNT=$((COUNT + 1))
    echo "--> [${COUNT}/${TOTAL}] Pokemon #${id}" >&2

    rm -f /tmp/sp_front.png /tmp/sp_shiny.png /tmp/sp_back.png

    curl -fsSL "${SPRITE_BASE}/${id}.png"       -o /tmp/sp_front.png 2>/dev/null || true
    curl -fsSL "${SPRITE_BASE}/shiny/${id}.png" -o /tmp/sp_shiny.png 2>/dev/null || true
    curl -fsSL "${SPRITE_BASE}/back/${id}.png"  -o /tmp/sp_back.png  2>/dev/null || true

    front_hex=$([ -s /tmp/sp_front.png ] && to_hex /tmp/sp_front.png || echo "")
    shiny_hex=$([ -s /tmp/sp_shiny.png ] && to_hex /tmp/sp_shiny.png || echo "")
    back_hex=$([ -s /tmp/sp_back.png  ] && to_hex /tmp/sp_back.png  || echo "")

    front_val=$([ -n "$front_hex" ] && echo "decode('${front_hex}','hex')" || echo "NULL")
    shiny_val=$([ -n "$shiny_hex" ] && echo "decode('${shiny_hex}','hex')" || echo "NULL")
    back_val=$([ -n "$back_hex"  ] && echo "decode('${back_hex}','hex')"  || echo "NULL")

    artwork_url="${SPRITE_BASE}/other/official-artwork/${id}.png"

    echo "INSERT INTO pokemon_sprites (pokemon_id, front_default, front_shiny, back_default, official_artwork_url) VALUES (${id}, ${front_val}, ${shiny_val}, ${back_val}, '${artwork_url}') ON CONFLICT DO NOTHING;" >> "$SQL_FILE"
done

echo "COMMIT;" >> "$SQL_FILE"

echo "--> Inserting sprites into database..." >&2
psql_as_ash -f "$SQL_FILE"
rm -f "$SQL_FILE" /tmp/sp_front.png /tmp/sp_shiny.png /tmp/sp_back.png

echo ""
echo "==> Sprites done! Try: SELECT id, name, official_artwork_url FROM pokemon_overview LIMIT 5;"
