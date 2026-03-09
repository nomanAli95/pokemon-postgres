#!/usr/bin/env bash
set -e

BASE_URL="https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv"

psql_as_ash() {
    psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-ash}" -d "${POSTGRES_DB:-pokedex}" "$@"
}

# Download all CSVs in parallel upfront
echo "--> Downloading all CSV files in parallel..." >&2
_pids=()
for _name in \
    generations regions types \
    pokemon_species pokemon_colors pokemon_shapes pokemon_habitats growth_rates \
    pokemon_species_names \
    pokemon pokemon_stats pokemon_types \
    abilities pokemon_abilities \
    moves move_targets move_names \
    egg_groups pokemon_egg_groups \
    type_efficacy \
    ability_prose \
    pokemon_species_flavor_text \
    pokemon_evolution evolution_triggers items \
    pokemon_moves pokemon_move_methods; do
    curl -fsSL "${BASE_URL}/${_name}.csv" -o "/tmp/${_name}.csv" &
    _pids+=($!)
done
for _pid in "${_pids[@]}"; do
    wait "$_pid"
done
echo "--> All CSV downloads complete." >&2

# Return the pre-downloaded path (files already on disk)
download() { echo "/tmp/${1}.csv"; }

# ---------- generations ----------
csv=$(download generations)
csv_regions=$(download regions)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_generations (
    id             INTEGER,
    main_region_id INTEGER,
    identifier     TEXT
);
CREATE TEMP TABLE tmp_regions (id INTEGER, identifier TEXT);
\COPY tmp_generations FROM '$csv' CSV HEADER;
\COPY tmp_regions FROM '$csv_regions' CSV HEADER;
INSERT INTO generations (id, main_region, identifier)
SELECT g.id, r.identifier, g.identifier
FROM tmp_generations g
LEFT JOIN tmp_regions r ON r.id = g.main_region_id
ON CONFLICT DO NOTHING;
SQL

# ---------- types ----------
csv=$(download types)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_types (
    id              INTEGER,
    identifier      TEXT,
    generation_id   INTEGER,
    damage_class_id INTEGER
);
\COPY tmp_types FROM '$csv' CSV HEADER;
INSERT INTO types (id, identifier, generation_id, damage_class)
SELECT
    id,
    identifier,
    NULLIF(generation_id::text,'')::int,
    CASE damage_class_id
        WHEN 1 THEN 'status'
        WHEN 2 THEN 'physical'
        WHEN 3 THEN 'special'
        ELSE NULL
    END
FROM tmp_types
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_species ----------
csv=$(download pokemon_species)
csv_colors=$(download pokemon_colors)
csv_shapes=$(download pokemon_shapes)
csv_habitats=$(download pokemon_habitats)
csv_growth_rates=$(download growth_rates)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon_species (
    id                       INTEGER,
    identifier               TEXT,
    generation_id            INTEGER,
    evolves_from_species_id  TEXT,
    evolution_chain_id       INTEGER,
    color_id                 INTEGER,
    shape_id                 INTEGER,
    habitat_id               TEXT,
    gender_rate              INTEGER,
    capture_rate             INTEGER,
    base_happiness           INTEGER,
    is_baby                  INTEGER,
    hatch_counter            INTEGER,
    has_gender_differences   INTEGER,
    growth_rate_id           INTEGER,
    forms_switchable         INTEGER,
    is_legendary             INTEGER,
    is_mythical              INTEGER,
    sort_order               INTEGER,
    conquest_order           TEXT
);
CREATE TEMP TABLE tmp_pokemon_colors    (id INTEGER, identifier TEXT);
CREATE TEMP TABLE tmp_pokemon_shapes    (id INTEGER, identifier TEXT);
CREATE TEMP TABLE tmp_pokemon_habitats  (id INTEGER, identifier TEXT);
CREATE TEMP TABLE tmp_growth_rates      (id INTEGER, identifier TEXT, formula TEXT);
\COPY tmp_pokemon_species   FROM '$csv'             CSV HEADER;
\COPY tmp_pokemon_colors    FROM '$csv_colors'      CSV HEADER;
\COPY tmp_pokemon_shapes    FROM '$csv_shapes'      CSV HEADER;
\COPY tmp_pokemon_habitats  FROM '$csv_habitats'    CSV HEADER;
\COPY tmp_growth_rates      FROM '$csv_growth_rates' CSV HEADER;
INSERT INTO pokemon_species (
    id, identifier, generation_id, evolves_from_species_id,
    evolution_chain_id, color, shape, habitat,
    gender_rate, capture_rate, base_happiness,
    is_baby, hatch_counter, has_gender_differences,
    growth_rate, forms_switchable,
    is_legendary, is_mythical,
    sort_order, conquest_order
)
SELECT
    s.id,
    s.identifier,
    NULLIF(s.generation_id::text,'')::int,
    NULLIF(s.evolves_from_species_id,'')::int,
    s.evolution_chain_id,
    c.identifier,
    sh.identifier,
    h.identifier,
    s.gender_rate,
    s.capture_rate,
    s.base_happiness,
    s.is_baby::boolean,
    s.hatch_counter,
    s.has_gender_differences::boolean,
    gr.identifier,
    s.forms_switchable::boolean,
    s.is_legendary::boolean,
    s.is_mythical::boolean,
    s.sort_order,
    NULLIF(s.conquest_order,'')::int
FROM tmp_pokemon_species s
LEFT JOIN tmp_pokemon_colors   c  ON c.id  = s.color_id
LEFT JOIN tmp_pokemon_shapes   sh ON sh.id = s.shape_id
LEFT JOIN tmp_pokemon_habitats h  ON h.id  = NULLIF(s.habitat_id,'')::int
LEFT JOIN tmp_growth_rates     gr ON gr.id = s.growth_rate_id
ON CONFLICT DO NOTHING;
SQL

# ---------- genus (English) ----------
csv=$(download pokemon_species_names)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_species_names (
    pokemon_species_id INTEGER,
    local_language_id  INTEGER,
    name               TEXT,
    genus              TEXT
);
\COPY tmp_species_names FROM '$csv' CSV HEADER;
UPDATE pokemon_species ps
SET genus = n.genus
FROM tmp_species_names n
WHERE n.pokemon_species_id = ps.id
  AND n.local_language_id = 9
  AND n.genus IS NOT NULL
  AND n.genus != '';
SQL

# ---------- pokemon ----------
csv=$(download pokemon)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon (
    id              INTEGER,
    identifier      TEXT,
    species_id      INTEGER,
    height          INTEGER,
    weight          INTEGER,
    base_experience TEXT,
    sort_order      INTEGER,
    is_default      INTEGER
);
\COPY tmp_pokemon FROM '$csv' CSV HEADER;
INSERT INTO pokemon (id, identifier, species_id, height, weight, base_experience, sort_order, is_default)
SELECT
    id,
    identifier,
    NULLIF(species_id::text,'')::int,
    height,
    weight,
    NULLIF(base_experience,'')::int,
    sort_order,
    is_default::boolean
FROM tmp_pokemon
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_stats ----------
csv=$(download pokemon_stats)
psql_as_ash <<SQL
\COPY pokemon_stats (pokemon_id, stat_id, base_stat, effort) FROM '$csv' CSV HEADER;
SQL

# ---------- pokemon_types ----------
csv=$(download pokemon_types)
psql_as_ash <<SQL
\COPY pokemon_types (pokemon_id, type_id, slot) FROM '$csv' CSV HEADER;
SQL

# ---------- abilities ----------
csv=$(download abilities)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_abilities (
    id             INTEGER,
    identifier     TEXT,
    generation_id  INTEGER,
    is_main_series INTEGER
);
\COPY tmp_abilities FROM '$csv' CSV HEADER;
INSERT INTO abilities (id, identifier, generation_id, is_main_series)
SELECT
    id,
    identifier,
    NULLIF(generation_id::text,'')::int,
    is_main_series::boolean
FROM tmp_abilities
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_abilities ----------
csv=$(download pokemon_abilities)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon_abilities (
    pokemon_id  INTEGER,
    ability_id  INTEGER,
    is_hidden   INTEGER,
    slot        INTEGER
);
\COPY tmp_pokemon_abilities FROM '$csv' CSV HEADER;
INSERT INTO pokemon_abilities (pokemon_id, slot, ability_id, is_hidden)
SELECT pokemon_id, slot, ability_id, is_hidden::boolean
FROM tmp_pokemon_abilities
ON CONFLICT DO NOTHING;
SQL

# ---------- moves ----------
csv=$(download moves)
csv_targets=$(download move_targets)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_moves (
    id                      INTEGER,
    identifier              TEXT,
    generation_id           INTEGER,
    type_id                 INTEGER,
    power                   TEXT,
    pp                      TEXT,
    accuracy                TEXT,
    priority                INTEGER,
    target_id               INTEGER,
    damage_class_id         INTEGER,
    effect_id               INTEGER,
    effect_chance           TEXT,
    contest_type_id         TEXT,
    contest_effect_id       TEXT,
    super_contest_effect_id TEXT
);
CREATE TEMP TABLE tmp_move_targets (id INTEGER, identifier TEXT);
\COPY tmp_moves        FROM '$csv'         CSV HEADER;
\COPY tmp_move_targets FROM '$csv_targets' CSV HEADER;
INSERT INTO moves (
    id, identifier, generation_id, type_id,
    power, pp, accuracy, priority,
    target, damage_class,
    effect_id, effect_chance,
    contest_type_id, contest_effect_id, super_contest_effect_id
)
SELECT
    m.id,
    m.identifier,
    NULLIF(m.generation_id::text,'')::int,
    NULLIF(m.type_id::text,'')::int,
    NULLIF(m.power,'')::int,
    NULLIF(m.pp,'')::int,
    NULLIF(m.accuracy,'')::int,
    m.priority,
    mt.identifier,
    CASE m.damage_class_id
        WHEN 1 THEN 'status'
        WHEN 2 THEN 'physical'
        WHEN 3 THEN 'special'
        ELSE NULL
    END,
    m.effect_id,
    NULLIF(m.effect_chance,'')::int,
    NULLIF(m.contest_type_id,'')::int,
    NULLIF(m.contest_effect_id,'')::int,
    NULLIF(m.super_contest_effect_id,'')::int
FROM tmp_moves m
LEFT JOIN tmp_move_targets mt ON mt.id = m.target_id
ON CONFLICT DO NOTHING;
SQL

# ---------- move names (English) ----------
csv=$(download move_names)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_move_names (
    move_id           INTEGER,
    local_language_id INTEGER,
    name              TEXT
);
\COPY tmp_move_names FROM '$csv' CSV HEADER;
UPDATE moves m
SET name = mn.name
FROM tmp_move_names mn
WHERE mn.move_id = m.id
  AND mn.local_language_id = 9;
SQL

# ---------- egg_groups ----------
csv=$(download egg_groups)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_egg_groups (id INTEGER, identifier TEXT);
\COPY tmp_egg_groups FROM '$csv' CSV HEADER;
INSERT INTO egg_groups (id, identifier)
SELECT id, identifier FROM tmp_egg_groups
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_egg_groups ----------
csv=$(download pokemon_egg_groups)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon_egg_groups (species_id INTEGER, egg_group_id INTEGER);
\COPY tmp_pokemon_egg_groups FROM '$csv' CSV HEADER;
INSERT INTO pokemon_egg_groups (species_id, egg_group_id)
SELECT species_id, egg_group_id FROM tmp_pokemon_egg_groups
WHERE species_id IN (SELECT id FROM pokemon_species)
ON CONFLICT DO NOTHING;
SQL

# ---------- type_efficacy ----------
csv=$(download type_efficacy)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_type_efficacy (
    damage_type_id INTEGER,
    target_type_id INTEGER,
    damage_factor  INTEGER
);
\COPY tmp_type_efficacy FROM '$csv' CSV HEADER;
INSERT INTO type_efficacy (damage_type_id, target_type_id, damage_factor)
SELECT damage_type_id, target_type_id, damage_factor
FROM tmp_type_efficacy
WHERE damage_type_id IN (SELECT id FROM types)
  AND target_type_id IN (SELECT id FROM types)
ON CONFLICT DO NOTHING;
SQL

# ---------- ability_prose (English) ----------
csv=$(download ability_prose)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_ability_prose (
    ability_id        INTEGER,
    local_language_id INTEGER,
    short_effect      TEXT,
    effect            TEXT
);
\COPY tmp_ability_prose FROM '$csv' CSV HEADER;
INSERT INTO ability_prose (ability_id, short_effect)
SELECT ability_id, short_effect
FROM tmp_ability_prose
WHERE local_language_id = 9
  AND ability_id IN (SELECT id FROM abilities)
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_flavor_text (English) ----------
csv=$(download pokemon_species_flavor_text)
# Re-encode through Python's csv module to fix any unterminated-quoted-field issues
csv_fixed="/tmp/pokemon_species_flavor_text_fixed.csv"
python3 - <<'PYEOF'
import csv
with open('/tmp/pokemon_species_flavor_text.csv', newline='', encoding='utf-8') as fin, \
     open('/tmp/pokemon_species_flavor_text_fixed.csv', 'w', newline='', encoding='utf-8') as fout:
    reader = csv.reader(fin)
    writer = csv.writer(fout, quoting=csv.QUOTE_ALL)
    for row in reader:
        writer.writerow(row)
PYEOF
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_flavor_text (
    species_id  INTEGER,
    version_id  INTEGER,
    language_id INTEGER,
    flavor_text TEXT
);
\COPY tmp_flavor_text FROM '$csv_fixed' CSV HEADER;
INSERT INTO pokemon_flavor_text (species_id, version_id, flavor_text)
SELECT
    species_id,
    version_id,
    regexp_replace(flavor_text, E'[\\x0c\\x0d\\x0a]+', ' ', 'g')
FROM tmp_flavor_text
WHERE language_id = 9
  AND species_id IN (SELECT id FROM pokemon_species)
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_evolution ----------
csv=$(download pokemon_evolution)
# Strip any extra columns added in newer PokeAPI CSV versions (keep first 20)
csv_fixed="/tmp/pokemon_evolution_fixed.csv"
python3 - <<'PYEOF'
import csv
with open('/tmp/pokemon_evolution.csv', newline='', encoding='utf-8') as fin, \
     open('/tmp/pokemon_evolution_fixed.csv', 'w', newline='', encoding='utf-8') as fout:
    reader = csv.reader(fin)
    writer = csv.writer(fout)
    for row in reader:
        writer.writerow(row[:20])
PYEOF
csv="$csv_fixed"
csv_triggers=$(download evolution_triggers)
csv_items=$(download items)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon_evolution (
    id                      INTEGER,
    evolved_species_id      INTEGER,
    evolution_trigger_id    INTEGER,
    trigger_item_id         TEXT,
    minimum_level           TEXT,
    gender_id               TEXT,
    location_id             TEXT,
    held_item_id            TEXT,
    time_of_day             TEXT,
    known_move_id           TEXT,
    known_move_type_id      TEXT,
    minimum_happiness       TEXT,
    minimum_beauty          TEXT,
    minimum_affection       TEXT,
    relative_physical_stats TEXT,
    party_species_id        TEXT,
    party_type_id           TEXT,
    trade_species_id        TEXT,
    needs_overworld_rain    INTEGER,
    turn_upside_down        INTEGER
);
CREATE TEMP TABLE tmp_evolution_triggers (id INTEGER, identifier TEXT);
CREATE TEMP TABLE tmp_items (
    id             INTEGER,
    identifier     TEXT,
    category_id    TEXT,
    cost           TEXT,
    fling_power    TEXT,
    fling_effect_id TEXT
);
\COPY tmp_pokemon_evolution  FROM '$csv'          CSV HEADER;
\COPY tmp_evolution_triggers FROM '$csv_triggers' CSV HEADER;
\COPY tmp_items              FROM '$csv_items'    CSV HEADER;
INSERT INTO pokemon_evolution (
    id, evolved_species_id, evolution_trigger,
    minimum_level, trigger_item, held_item,
    time_of_day, minimum_happiness, minimum_beauty, minimum_affection,
    known_move_id, trade_species_id,
    relative_physical_stats, needs_overworld_rain, turn_upside_down
)
SELECT
    e.id,
    e.evolved_species_id,
    et.identifier,
    NULLIF(e.minimum_level,'')::int,
    ti.identifier,
    hi.identifier,
    NULLIF(e.time_of_day,''),
    NULLIF(e.minimum_happiness,'')::int,
    NULLIF(e.minimum_beauty,'')::int,
    NULLIF(e.minimum_affection,'')::int,
    NULLIF(e.known_move_id,'')::int,
    NULLIF(e.trade_species_id,'')::int,
    NULLIF(e.relative_physical_stats,'')::int,
    e.needs_overworld_rain::boolean,
    e.turn_upside_down::boolean
FROM tmp_pokemon_evolution e
LEFT JOIN tmp_evolution_triggers et ON et.id = e.evolution_trigger_id
LEFT JOIN tmp_items ti ON ti.id = NULLIF(e.trigger_item_id,'')::int
LEFT JOIN tmp_items hi ON hi.id = NULLIF(e.held_item_id,'')::int
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_moves ----------
csv=$(download pokemon_moves)
csv_methods=$(download pokemon_move_methods)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_pokemon_moves (
    pokemon_id             INTEGER,
    version_group_id       INTEGER,
    move_id                INTEGER,
    pokemon_move_method_id INTEGER,
    level                  INTEGER,
    sort_order             TEXT,
    mastery                TEXT
);
CREATE TEMP TABLE tmp_move_methods (id INTEGER, identifier TEXT);
\COPY tmp_pokemon_moves FROM '$csv'         CSV HEADER;
\COPY tmp_move_methods  FROM '$csv_methods' CSV HEADER;
INSERT INTO pokemon_moves (pokemon_id, version_group_id, move_id, learn_method, level)
SELECT
    pm.pokemon_id,
    pm.version_group_id,
    pm.move_id,
    mm.identifier,
    COALESCE(pm.level, 0)
FROM tmp_pokemon_moves pm
JOIN tmp_move_methods mm ON mm.id = pm.pokemon_move_method_id
WHERE pm.pokemon_id IN (SELECT id FROM pokemon)
  AND pm.move_id    IN (SELECT id FROM moves)
ON CONFLICT DO NOTHING;
SQL

echo ""
echo "==> Done! Try: SELECT name, genus, generation, region FROM pokemon_overview LIMIT 10;"