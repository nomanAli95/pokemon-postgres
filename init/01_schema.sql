-- 1. generations
CREATE TABLE generations (
    id          INTEGER PRIMARY KEY,
    main_region TEXT,
    identifier  TEXT NOT NULL
);

-- 2. types
CREATE TABLE types (
    id            INTEGER PRIMARY KEY,
    identifier    TEXT NOT NULL,
    generation_id INTEGER REFERENCES generations(id),
    damage_class  TEXT
);

-- 3. pokemon_species
CREATE TABLE pokemon_species (
    id                       INTEGER PRIMARY KEY,
    identifier               TEXT NOT NULL,
    generation_id            INTEGER REFERENCES generations(id),
    evolves_from_species_id  INTEGER REFERENCES pokemon_species(id),
    evolution_chain_id       INTEGER,
    color                    TEXT,
    shape                    TEXT,
    habitat                  TEXT,
    gender_rate              INTEGER,
    capture_rate             INTEGER,
    base_happiness           INTEGER,
    is_baby                  BOOLEAN NOT NULL DEFAULT FALSE,
    hatch_counter            INTEGER,
    has_gender_differences   BOOLEAN NOT NULL DEFAULT FALSE,
    growth_rate              TEXT,
    forms_switchable         BOOLEAN NOT NULL DEFAULT FALSE,
    is_legendary             BOOLEAN NOT NULL DEFAULT FALSE,
    is_mythical              BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order               INTEGER,
    conquest_order           INTEGER
);

-- 4. pokemon
CREATE TABLE pokemon (
    id              INTEGER PRIMARY KEY,
    identifier      TEXT NOT NULL,
    species_id      INTEGER REFERENCES pokemon_species(id),
    height          INTEGER,
    weight          INTEGER,
    base_experience INTEGER,
    sort_order      INTEGER,
    is_default      BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. pokemon_stats
CREATE TABLE pokemon_stats (
    pokemon_id  INTEGER REFERENCES pokemon(id),
    stat_id     INTEGER CHECK (stat_id BETWEEN 1 AND 6),
    base_stat   INTEGER NOT NULL,
    effort      INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (pokemon_id, stat_id)
);

-- 6. pokemon_types
CREATE TABLE pokemon_types (
    pokemon_id  INTEGER REFERENCES pokemon(id),
    slot        INTEGER CHECK (slot IN (1, 2)),
    type_id     INTEGER REFERENCES types(id),
    PRIMARY KEY (pokemon_id, slot)
);

-- 7. abilities
CREATE TABLE abilities (
    id             INTEGER PRIMARY KEY,
    identifier     TEXT NOT NULL,
    generation_id  INTEGER REFERENCES generations(id),
    is_main_series BOOLEAN NOT NULL DEFAULT TRUE
);

-- 8. pokemon_abilities
CREATE TABLE pokemon_abilities (
    pokemon_id  INTEGER REFERENCES pokemon(id),
    slot        INTEGER NOT NULL,
    ability_id  INTEGER REFERENCES abilities(id),
    is_hidden   BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (pokemon_id, slot)
);

-- 9. moves
CREATE TABLE moves (
    id                      INTEGER PRIMARY KEY,
    identifier              TEXT NOT NULL,
    generation_id           INTEGER REFERENCES generations(id),
    type_id                 INTEGER REFERENCES types(id),
    power                   INTEGER,
    pp                      INTEGER,
    accuracy                INTEGER,
    priority                INTEGER NOT NULL DEFAULT 0,
    target                  TEXT,
    damage_class            TEXT,
    effect_id               INTEGER,
    effect_chance           INTEGER,
    contest_type_id         INTEGER,
    contest_effect_id       INTEGER,
    super_contest_effect_id INTEGER
);

-- View: pokemon_overview
CREATE VIEW pokemon_overview AS
SELECT
    p.id,
    p.identifier                                        AS name,
    ps.color,
    ps.is_legendary,
    ps.is_mythical,
    t1.identifier                                       AS type1,
    t2.identifier                                       AS type2,
    MAX(CASE WHEN pst.stat_id = 1 THEN pst.base_stat END) AS hp,
    MAX(CASE WHEN pst.stat_id = 2 THEN pst.base_stat END) AS attack,
    MAX(CASE WHEN pst.stat_id = 3 THEN pst.base_stat END) AS defense,
    MAX(CASE WHEN pst.stat_id = 4 THEN pst.base_stat END) AS sp_attack,
    MAX(CASE WHEN pst.stat_id = 5 THEN pst.base_stat END) AS sp_defense,
    MAX(CASE WHEN pst.stat_id = 6 THEN pst.base_stat END) AS speed,
    SUM(pst.base_stat)                                  AS base_stat_total
FROM pokemon p
JOIN pokemon_species ps       ON ps.id = p.species_id
LEFT JOIN pokemon_types pt1   ON pt1.pokemon_id = p.id AND pt1.slot = 1
LEFT JOIN types t1            ON t1.id = pt1.type_id
LEFT JOIN pokemon_types pt2   ON pt2.pokemon_id = p.id AND pt2.slot = 2
LEFT JOIN types t2            ON t2.id = pt2.type_id
LEFT JOIN pokemon_stats pst   ON pst.pokemon_id = p.id
GROUP BY p.id, p.identifier, ps.color, ps.is_legendary, ps.is_mythical,
         t1.identifier, t2.identifier;