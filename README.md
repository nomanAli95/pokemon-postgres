# pokemon-postgres

A PostgreSQL 16 Docker image pre-seeded with a complete Pokédex: data from [PokeAPI/pokeapi](https://github.com/PokeAPI/pokeapi) and sprites from [PokeAPI/sprites](https://github.com/PokeAPI/sprites).

| Bulbasaur | Charmander | Squirtle |
|:---------:|:----------:|:--------:|
| ![Bulbasaur](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png) | ![Charmander](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/4.png) | ![Squirtle](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/7.png) |

---

## Quick start

```bash
docker compose up --build
```

> **Note:** The first `docker build` seeds all 923 Pokémon (Gen 1–9) with data and sprites into the image — this takes several minutes. Subsequent starts are **instant** since the data is baked in.

The default credentials (`ash` / `pikachu`) are for local development only.

---

## Connection details

| Field    | Value     |
|----------|-----------|
| Host     | localhost |
| Port     | 5432      |
| Database | pokedex   |
| User     | ash       |
| Password | pikachu   |

```bash
docker exec -it pokedex-db psql -U ash -d pokedex
```

> To upgrade to a new image version, wipe the volume first so the new data is used:
> ```bash
> docker compose down -v && docker compose up --build
> ```

---

## Schema

| Table               | Description                              |
|---------------------|------------------------------------------|
| `generations`       | Game generations (I–IX)                  |
| `types`             | Pokémon types (Fire, Water, etc.)        |
| `pokemon_species`   | Species-level data (legendary, color…)   |
| `pokemon`           | Individual Pokémon forms                 |
| `pokemon_stats`     | Base stats (HP, ATK, DEF, …)             |
| `pokemon_types`     | Type slot assignments per Pokémon        |
| `abilities`         | All abilities                            |
| `pokemon_abilities` | Ability assignments per Pokémon          |
| `moves`             | All moves with power/pp/accuracy         |
| `pokemon_sprites`   | Front/back/shiny sprites (BYTEA) + official artwork URL |

### View: `pokemon_overview`

Joins all tables into a single flat view with every one-to-one field available for a Pokémon:

| Column | Source | Description |
|--------|--------|-------------|
| `id`, `name` | `pokemon` | Pokédex number and identifier |
| `height`, `weight`, `base_experience` | `pokemon` | Physical data and base XP |
| `color`, `shape`, `habitat` | `pokemon_species` | Visual and ecological traits |
| `gender_rate`, `capture_rate`, `base_happiness` | `pokemon_species` | Game mechanics |
| `is_baby`, `hatch_counter`, `growth_rate` | `pokemon_species` | Breeding data |
| `is_legendary`, `is_mythical` | `pokemon_species` | Rarity flags |
| `evolves_from_species_id`, `evolution_chain_id` | `pokemon_species` | Evolution references |
| `generation`, `region` | `generations` | Generation name and main region |
| `type1`, `type2` | `types` | Primary and secondary type |
| `hp`, `attack`, `defense`, `sp_attack`, `sp_defense`, `speed`, `base_stat_total` | `pokemon_stats` | Base stats |
| `ev_hp`, `ev_attack`, `ev_defense`, `ev_sp_attack`, `ev_sp_defense`, `ev_speed` | `pokemon_stats` | EV yields |
| `front_default`, `official_artwork_url` | `pokemon_sprites` | Sprite blob and artwork URL |

> **One-to-many data** (abilities, full evolution chain) is not in the view — query `pokemon_abilities`, `abilities`, and `pokemon_species` directly using `evolution_chain_id`.

---

## Sprites

Sprites are stored in the `pokemon_sprites` table:

| Column                | Type    | Description                                      |
|-----------------------|---------|--------------------------------------------------|
| `pokemon_id`          | INTEGER | FK to `pokemon`                                  |
| `front_default`       | BYTEA   | Front-facing sprite (~1–8 KB PNG)                |
| `front_shiny`         | BYTEA   | Shiny front-facing sprite                        |
| `back_default`        | BYTEA   | Back-facing sprite                               |
| `official_artwork_url`| TEXT    | URL to high-res official artwork (~126 KB each)  |

Regular sprites are stored as binary directly in the database (~6 MB total). Official artwork is stored as a URL.

---

## Example queries

```sql
-- Top 10 Pokémon by base stat total
SELECT name, type1, type2, base_stat_total
FROM pokemon_overview
ORDER BY base_stat_total DESC
LIMIT 10;

-- All legendary Fire-types
SELECT name, type1, type2, hp, attack, speed
FROM pokemon_overview
WHERE is_legendary = TRUE
  AND (type1 = 'fire' OR type2 = 'fire')
ORDER BY base_stat_total DESC;

-- Average stats by primary type
SELECT type1,
       ROUND(AVG(base_stat_total)) AS avg_bst,
       COUNT(*) AS count
FROM pokemon_overview
WHERE type1 IS NOT NULL
GROUP BY type1
ORDER BY avg_bst DESC;

-- Full card data for a single Pokémon (all flat fields)
SELECT name, generation, region, type1, type2,
       height, weight, base_experience,
       habitat, color, shape, growth_rate,
       capture_rate, base_happiness, gender_rate,
       is_baby, is_legendary, is_mythical,
       hp, attack, defense, sp_attack, sp_defense, speed, base_stat_total,
       ev_hp, ev_attack, ev_defense, ev_sp_attack, ev_sp_defense, ev_speed,
       evolves_from_species_id, evolution_chain_id,
       official_artwork_url
FROM pokemon_overview
WHERE name = 'bulbasaur';

-- Full evolution chain (use evolution_chain_id from pokemon_overview)
SELECT ps.id, ps.identifier, ps.evolves_from_species_id
FROM pokemon_species ps
WHERE ps.evolution_chain_id = 1
ORDER BY ps.sort_order;

-- Abilities for a Pokémon (one-to-many, not in the view)
SELECT a.identifier AS ability, pa.is_hidden
FROM pokemon_abilities pa
JOIN abilities a ON a.id = pa.ability_id
WHERE pa.pokemon_id = 1
ORDER BY pa.slot;

-- Retrieve a sprite as base64 (e.g. for embedding in HTML/apps)
SELECT pokemon_id, encode(front_default, 'base64') AS front_sprite
FROM pokemon_sprites
WHERE pokemon_id = 25;

-- Get Pikachu's official artwork URL
SELECT name, official_artwork_url
FROM pokemon_overview
WHERE name = 'pikachu';
```

---

## Useful commands

```bash
# Rebuild from scratch (wipe data volume)
docker compose down -v && docker compose up --build

# Test the view
docker exec -it pokedex-db psql -U ash -d pokedex -c \
  "SELECT name, generation, region, type1, type2, base_stat_total FROM pokemon_overview ORDER BY base_stat_total DESC LIMIT 10;"

# Check sprite coverage
docker exec -it pokedex-db psql -U ash -d pokedex -c \
  "SELECT COUNT(*) FROM pokemon_sprites WHERE front_default IS NOT NULL;"
```

---

## Data sources

- Pokémon data: [PokeAPI/pokeapi](https://github.com/PokeAPI/pokeapi) — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
- Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites) — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
