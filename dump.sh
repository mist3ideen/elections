#!/bin/bash

pg_dump -O -x -d elections -f elections.sql
