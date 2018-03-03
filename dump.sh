#!/bin/bash

DATABASE_NAME="elections"

pg_dump -O -x -d "$DATABASE_NAME" --inserts -f elections.sql
#pg_dump -O -x -d "$DATABASE_NAME" -N simulation --inserts -f elections.sql
