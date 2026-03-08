# pokemon-postgres

A PostgreSQL 16 Docker image pre-seeded with a complete Pokédex: data from [veekun/pokedex](https://github.com/veekun/pokedex) and sprites from [PokeAPI/sprites](https://github.com/PokeAPI/sprites).

| Bulbasaur | Charmander | Squirtle |
|:---------:|:----------:|:--------:|
| ![Bulbasaur](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/1.png) | ![Charmander](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/4.png) | ![Squirtle](https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/7.png) |

---

## Quick start

```bash
docker compose up --build
```

> **Note:** The first `docker build` seeds all Pokémon data and sprites into the image — this takes several minutes. Subsequent starts are **instant** since the data is baked in.

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

Joins all tables into a single flat view:
`id, name, color, is_legendary, is_mythical, type1, type2, hp, attack, defense, sp_attack, sp_defense, speed, base_stat_total, front_default, official_artwork_url`

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
  "SELECT name, type1, type2, base_stat_total FROM pokemon_overview ORDER BY base_stat_total DESC LIMIT 10;"

# Check sprite coverage
docker exec -it pokedex-db psql -U ash -d pokedex -c \
  "SELECT COUNT(*) FROM pokemon_sprites WHERE front_default IS NOT NULL;"
```

---

## Data sources

- Pokémon data: [veekun/pokedex](https://github.com/veekun/pokedex) — [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites) — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
