PSQL=psql
CURRENT_ID=$($PSQL -X -U postgres -h localhost -P t -P format=unaligned test_egeos -c "select max(id) from current_ba")
let NEXT_ID=CURRENT_ID+1
echo "next current_ba.id is $NEXT_ID"
