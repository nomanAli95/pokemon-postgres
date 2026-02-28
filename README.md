# pokemon-postgres

A PostgreSQL 16 Docker image pre-seeded with Pokémon data from [veekun/pokedex](https://github.com/veekun/pokedex).

---

## Quick start

```bash
docker compose up --build
```

The first run downloads CSVs from GitHub and loads them into PostgreSQL. This takes a minute or two.

> **Note:** The default credentials (`ash` / `pikachu`) are for local development only.
> For any other environment, override them with environment variables:
> ```bash
> POSTGRES_USER=myuser POSTGRES_PASSWORD=mysecretpassword docker compose up --build
> ```

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

---

## Schema

| Table              | Description                              |
|--------------------|------------------------------------------|
| `generations`      | Game generations (I–IX)                  |
| `types`            | Pokémon types (Fire, Water, etc.)        |
| `pokemon_species`  | Species-level data (legendary, color…)   |
| `pokemon`          | Individual Pokémon forms                 |
| `pokemon_stats`    | Base stats (HP, ATK, DEF, …)             |
| `pokemon_types`    | Type slot assignments per Pokémon        |
| `abilities`        | All abilities                            |
| `pokemon_abilities`| Ability assignments per Pokémon          |
| `moves`            | All moves with power/pp/accuracy         |

### View: `pokemon_overview`

Joins all tables into a single flat view:
`id, name, color, is_legendary, is_mythical, type1, type2, hp, attack, defense, sp_attack, sp_defense, speed, base_stat_total`

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
```

---

## GitHub Actions secrets

To publish the image to Docker Hub, add these secrets in
**GitHub → Settings → Secrets and variables → Actions**:

| Secret              | Value                                            |
|---------------------|--------------------------------------------------|
| `DOCKERHUB_USERNAME`| Your Docker Hub username                         |
| `DOCKERHUB_TOKEN`   | Personal access token from hub.docker.com → Security |

The workflow builds for `linux/amd64` and `linux/arm64` and pushes on every commit to `main` or a semver tag.

---

## Useful commands

```bash
# Rebuild from scratch (wipe data volume)
docker compose down -v && docker compose up --build

# Test the view
docker exec -it pokedex-db psql -U ash -d pokedex -c \
  "SELECT name, type1, type2, base_stat_total FROM pokemon_overview ORDER BY base_stat_total DESC LIMIT 10;"
```

---

## Data source

Pokémon data sourced from [veekun/pokedex](https://github.com/veekun/pokedex) — CSV files under the [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/) licence.
