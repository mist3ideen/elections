#!/bin/bash -ex

dropdb elections
createdb elections
psql elections -f elections.sql
psql elections -c 'TRUNCATE constituencies, candidate_categories CASCADE;'
