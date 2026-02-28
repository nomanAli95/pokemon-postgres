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

echo ""
echo "==> Done! Try: SELECT * FROM pokemon_overview LIMIT 10;"