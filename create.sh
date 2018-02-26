#!/bin/bash

createdb elections
psql elections -f elections.sql
