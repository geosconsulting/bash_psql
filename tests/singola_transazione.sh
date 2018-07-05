psql \
     -X \
     -U myuser \
     -h myhost \
     -f /path/to/sql/file.sql \
     --echo-all \
     --single-transaction \
     --set AUTOCOMMIT=off \
     --set ON_ERROR_STOP=on \
     mydatabase
