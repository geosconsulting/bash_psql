#!/bin/bash

psql \
    -X \
    -U postgres \
    -h e1-dev-effisdb.ies.jrc.it \
    -d gwis \
    -c "\\copy emission_dispersion.sci_s_co_d_2017062203_z_1m to stdout" \
#    -c "\\copy (select first_name, last_name from users) to stdout" \
| \
psql \
    -X \
    -U postgres \
    -h localhost \
    -d test_egeos \
    -c "\\copy emission_dispersion.sci_s_co_d_2017062203_z_1m from stdin" 
