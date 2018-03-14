read id firedate area_ha <<< $(psql \
        -X \
        -U postgres \
        -h localhost \
        -d test_egeos \
        --single-transaction \
        --set ON_ERROR_STOP=on \
        --no-align \
        -t \
        --field-separator ' ' \
        --quiet \
        -c "select id, firedate, area_ha from current_ba where id = 400")

echo "id: $id, firedate: $firedate, area_hectares: $area_ha"
