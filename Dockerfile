FROM postgres:18-alpine AS builder

ENV POSTGRES_USER=ash
ENV POSTGRES_PASSWORD=pikachu
ENV POSTGRES_DB=pokedex
ENV PGDATA=/var/lib/postgresql/data

RUN apk add --no-cache curl bash python3

COPY init/ /tmp/init/

RUN set -e \
    && echo "$POSTGRES_PASSWORD" > /tmp/pwfile \
    && su-exec postgres initdb --username="$POSTGRES_USER" --pwfile=/tmp/pwfile -D "$PGDATA" \
    && rm /tmp/pwfile \
    && echo "host all all all scram-sha-256" >> "$PGDATA/pg_hba.conf" \
    && su-exec postgres pg_ctl start -D "$PGDATA" -o "-c listen_addresses=''" -w \
    && su-exec postgres createdb -U "$POSTGRES_USER" "$POSTGRES_DB" \
    && su-exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /tmp/init/01_schema.sql \
    && su-exec postgres bash /tmp/init/02_seed.sh \
    && su-exec postgres bash /tmp/init/03_seed_sprites.sh \
    && su-exec postgres pg_ctl stop -D "$PGDATA" -m fast \
    && rm -rf /tmp/init

FROM postgres:18-alpine

ENV POSTGRES_USER=ash
ENV POSTGRES_PASSWORD=pikachu
ENV POSTGRES_DB=pokedex
ENV PGDATA=/var/lib/postgresql/data

COPY --from=builder --chown=postgres:postgres /var/lib/postgresql/data /var/lib/postgresql/data
