#!/bin/bash

psql -U postgres -d pg_96_cookbook -c "SELECT * FROM $1.$2;"
