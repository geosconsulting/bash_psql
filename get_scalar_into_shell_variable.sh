CURRENT_ID=$($PSQL -X -U $PROD_USER -h myhost -P t -P format=unaligned $PROD_DB -c "select max(id) from users")
let NEXT_ID=CURRENT_ID+1
echo "next user.id is $NEXT_ID"

echo "about to reset user id sequence on other database"
$PSQL -X -U $DEV_USER $DEV_DB -c "alter sequence user_ids restart with $NEXT_ID"
