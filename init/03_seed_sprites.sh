#!/usr/bin/env bash
set -e

SPRITE_BASE="https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon"

psql_as_ash() {
    psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-ash}" -d "${POSTGRES_DB:-pokedex}" "$@"
}

echo "--> Fetching Pokemon IDs from DB..." >&2
psql_as_ash -t -A -c "SELECT id FROM pokemon ORDER BY id" > /tmp/pokemon_ids.txt
TOTAL=$(wc -l < /tmp/pokemon_ids.txt | tr -d ' ')
echo "--> Downloading sprites for ${TOTAL} Pokemon in parallel..." >&2

SPRITE_BASE="$SPRITE_BASE" python3 << 'PYEOF'
import os, sys, base64, subprocess, urllib.request, concurrent.futures

sprite_base = os.environ['SPRITE_BASE']
sprite_dir  = '/tmp/sprites'
os.makedirs(sprite_dir, exist_ok=True)

with open('/tmp/pokemon_ids.txt') as f:
    ids = [line.strip() for line in f if line.strip()]

def fetch(url, dest):
    try:
        urllib.request.urlretrieve(url, dest)
        if os.path.getsize(dest) == 0:
            os.remove(dest)
    except Exception:
        if os.path.exists(dest):
            os.remove(dest)

def fetch_task(args):
    fetch(*args)

tasks = []
for pid in ids:
    tasks.extend([
        (f"{sprite_base}/{pid}.png",       f"{sprite_dir}/{pid}_front.png"),
        (f"{sprite_base}/shiny/{pid}.png", f"{sprite_dir}/{pid}_shiny.png"),
        (f"{sprite_base}/back/{pid}.png",  f"{sprite_dir}/{pid}_back.png"),
    ])

print(f"--> Fetching {len(tasks)} sprites with 30 concurrent workers...", file=sys.stderr, flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=30) as executor:
    list(executor.map(fetch_task, tasks))

print("--> Streaming SQL to psql...", file=sys.stderr, flush=True)

def to_sql_val(path):
    if os.path.exists(path):
        b64 = base64.b64encode(open(path, 'rb').read()).decode()
        return f"decode('{b64}','base64')"
    return 'NULL'

psql_env = os.environ.copy()
proc = subprocess.Popen(
    ['psql', '-v', 'ON_ERROR_STOP=1',
     '-U', os.environ.get('POSTGRES_USER', 'ash'),
     '-d', os.environ.get('POSTGRES_DB', 'pokedex')],
    stdin=subprocess.PIPE, text=True, env=psql_env
)

proc.stdin.write('BEGIN;\n')
for pid in ids:
    front_val   = to_sql_val(f"{sprite_dir}/{pid}_front.png")
    shiny_val   = to_sql_val(f"{sprite_dir}/{pid}_shiny.png")
    back_val    = to_sql_val(f"{sprite_dir}/{pid}_back.png")
    artwork_url = f"{sprite_base}/other/official-artwork/{pid}.png"
    proc.stdin.write(
        f"INSERT INTO pokemon_sprites "
        f"(pokemon_id, front_default, front_shiny, back_default, official_artwork_url) "
        f"VALUES ({pid}, {front_val}, {shiny_val}, {back_val}, '{artwork_url}') "
        f"ON CONFLICT DO NOTHING;\n"
    )
proc.stdin.write('COMMIT;\n')
proc.stdin.close()

rc = proc.wait()
if rc != 0:
    sys.exit(rc)
PYEOF

rm -rf /tmp/sprites /tmp/pokemon_ids.txt

echo ""
echo "==> Sprites done! Try: SELECT id, name, official_artwork_url FROM pokemon_overview LIMIT 5;"
