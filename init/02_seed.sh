#!/usr/bin/env bash
set -e

BASE_URL="https://raw.githubusercontent.com/veekun/pokedex/master/pokedex/data/csv"

download() {
    local name="$1"
    local dest="/tmp/${name}.csv"
    echo "--> Downloading ${name}.csv" >&2
    curl -fsSL "${BASE_URL}/${name}.csv" -o "$dest" >&2
    echo "$dest"
}

psql_as_ash() {
    psql -v ON_ERROR_STOP=1 -U "${POSTGRES_USER:-ash}" -d "${POSTGRES_DB:-pokedex}" "$@"
}

# ---------- generations ----------
csv=$(download generations)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_generations (
    id             INTEGER,
    main_region_id INTEGER,
    identifier     TEXT
);
\COPY tmp_generations FROM '$csv' CSV HEADER;
INSERT INTO generations (id, identifier)
SELECT id, identifier FROM tmp_generations ON CONFLICT DO NOTHING;
SQL

# ---------- types ----------
csv=$(download types)
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_types (
    id            INTEGER,
    identifier    TEXT,
    generation_id INTEGER,
    damage_class  TEXT
);
\COPY tmp_types FROM '$csv' CSV HEADER;
INSERT INTO types (id, identifier, generation_id)
SELECT id, identifier, NULLIF(generation_id::text,'')::int
FROM tmp_types
ON CONFLICT DO NOTHING;
SQL

# ---------- pokemon_species ----------
csv=$(download pokemon_species)
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
    order_col                INTEGER,
    conquest_order           TEXT
);
\COPY tmp_pokemon_species FROM '$csv' CSV HEADER;
INSERT INTO pokemon_species (id, identifier, generation_id, evolves_from_species_id, is_legendary, is_mythical)
SELECT
    id,
    identifier,
    NULLIF(generation_id::text,'')::int,
    NULLIF(evolves_from_species_id,'')::int,
    is_legendary::boolean,
    is_mythical::boolean
FROM tmp_pokemon_species
ON CONFLICT DO NOTHING;
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
    order_col       INTEGER,
    is_default      INTEGER
);
\COPY tmp_pokemon FROM '$csv' CSV HEADER;
INSERT INTO pokemon (id, identifier, species_id, height, weight, base_experience)
SELECT
    id,
    identifier,
    NULLIF(species_id::text,'')::int,
    height,
    weight,
    NULLIF(base_experience,'')::int
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
psql_as_ash <<SQL
CREATE TEMP TABLE tmp_moves (
    id                  INTEGER,
    identifier          TEXT,
    generation_id       INTEGER,
    type_id             INTEGER,
    power               TEXT,
    pp                  TEXT,
    accuracy            TEXT,
    priority            INTEGER,
    target_id           INTEGER,
    damage_class_id     INTEGER,
    effect_id           INTEGER,
    effect_chance       TEXT,
    contest_type_id     TEXT,
    contest_effect_id   TEXT,
    super_contest_effect_id TEXT
);
\COPY tmp_moves FROM '$csv' CSV HEADER;
INSERT INTO moves (id, identifier, generation_id, type_id, power, pp, accuracy, priority, damage_class)
SELECT
    id,
    identifier,
    NULLIF(generation_id::text,'')::int,
    NULLIF(type_id::text,'')::int,
    NULLIF(power,'')::int,
    NULLIF(pp,'')::int,
    NULLIF(accuracy,'')::int,
    priority,
    CASE damage_class_id
        WHEN 1 THEN 'status'
        WHEN 2 THEN 'physical'
        WHEN 3 THEN 'special'
        ELSE NULL
    END
FROM tmp_moves
ON CONFLICT DO NOTHING;
SQL

echo ""
echo "==> Done! Try: SELECT * FROM pokemon_overview LIMIT 10;"
