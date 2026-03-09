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

> **Note:** The first `docker build` seeds all 1025 Pokémon species (Gen 1–9, 1350 total forms) with data and sprites into the image — this takes several minutes. Subsequent starts are **instant** since the data is baked in.

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

| Table                  | Description                                                      |
|------------------------|------------------------------------------------------------------|
| `generations`          | Game generations (I–IX)                                          |
| `types`                | Pokémon types (Fire, Water, etc.)                                |
| `pokemon_species`      | Species-level data (legendary, color, genus…)                    |
| `pokemon`              | Individual Pokémon forms                                         |
| `pokemon_stats`        | Base stats and EV yields (HP, ATK, DEF, …)                       |
| `pokemon_types`        | Type slot assignments per Pokémon                                |
| `abilities`            | All abilities                                                    |
| `pokemon_abilities`    | Ability assignments per Pokémon                                  |
| `moves`                | All moves with power/pp/accuracy/damage class and English name   |
| `pokemon_sprites`      | Front/back/shiny sprites (BYTEA) + official artwork URL          |
| `egg_groups`           | Egg group definitions (15 groups)                                |
| `pokemon_egg_groups`   | Egg group assignments per species (1–2 per species)              |
| `type_efficacy`        | 18×18 type matchup matrix (damage factors: 0/50/100/200)         |
| `ability_prose`        | English short-effect description per ability                     |
| `pokemon_flavor_text`  | English Pokédex entry text per species per game version          |
| `pokemon_evolution`    | Evolution conditions (level, item, happiness, trade, etc.)       |
| `pokemon_moves`        | Moves each Pokémon can learn, per version group and learn method  |

### View: `pokemon_overview`

Joins all tables into a single flat view with every one-to-one field available for a Pokémon:

| Column | Source | Description |
|--------|--------|-------------|
| `id`, `name` | `pokemon` | Pokédex number and identifier |
| `height`, `weight`, `base_experience` | `pokemon` | Physical data and base XP |
| `color`, `shape`, `habitat`, `genus` | `pokemon_species` | Visual, ecological traits and genus (e.g. "Seed Pokémon") |
| `gender_rate`, `capture_rate`, `base_happiness` | `pokemon_species` | Game mechanics |
| `is_baby`, `hatch_counter`, `growth_rate` | `pokemon_species` | Breeding data |
| `is_legendary`, `is_mythical` | `pokemon_species` | Rarity flags |
| `evolves_from_species_id`, `evolution_chain_id` | `pokemon_species` | Evolution references |
| `generation`, `region` | `generations` | Generation name and main region |
| `type1`, `type2` | `types` | Primary and secondary type |
| `hp`, `attack`, `defense`, `sp_attack`, `sp_defense`, `speed`, `base_stat_total` | `pokemon_stats` | Base stats |
| `ev_hp`, `ev_attack`, `ev_defense`, `ev_sp_attack`, `ev_sp_defense`, `ev_speed` | `pokemon_stats` | EV yields |
| `front_default`, `official_artwork_url` | `pokemon_sprites` | Sprite blob and artwork URL |

> **One-to-many data** (abilities, moves, egg groups, flavor text, evolution chain, type efficacy) is not in the view — query the dedicated tables directly.

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

-- Full card data for a single Pokémon
SELECT name, genus, generation, region, type1, type2,
       height, weight, habitat, capture_rate,
       hp, attack, defense, sp_attack, sp_defense, speed
FROM pokemon_overview
WHERE name = 'bulbasaur';

-- Moves learnable in a specific game (version_group_id = 25 is Scarlet/Violet, 1 is Red/Blue)
SELECT m.name, m.damage_class, m.power, m.pp, pm.learn_method, pm.level
FROM pokemon_moves pm
JOIN moves m ON m.id = pm.move_id
WHERE pm.pokemon_id = 1 AND pm.version_group_id = 25
ORDER BY pm.learn_method, pm.level;
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

- Pokémon data: [PokeAPI/pokeapi](https://github.com/PokeAPI/pokeapi) — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
- Sprites: [PokeAPI/sprites](https://github.com/PokeAPI/sprites) — [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)
