#!/bin/bash

DATABASE_NAME="elections"
SCHEMA_NAME="$1"
# SCHEMA_NAME="sim_3_nbsfsrnthm"

pg_dump -O -x -d "$DATABASE_NAME" --inserts -n "$SCHEMA_NAME" -f "elections_schema_${SCHEMA_NAME}.sql"
