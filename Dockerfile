FROM postgres:18-alpine

ENV POSTGRES_USER=ash
ENV POSTGRES_PASSWORD=pikachu
ENV POSTGRES_DB=pokedex

RUN apk add --no-cache curl bash

COPY init/ /docker-entrypoint-initdb.d/
