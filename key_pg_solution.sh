#!/user/bin/env bash

#da attivate usando sudo ./key_pg_solution.sh
chown postgres /etc/ssl/private/ssl-cert-snakeoil.key
chgrp postgres /etc/ssl/private/ssl-cert-snakeoil.key
chmod 0600 /etc/ssl/private/ssl-cert-snakeoil.key
