#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
	CREATE USER matchmaker_service WITH ENCRYPTED PASSWORD '$MATCHMAKER_DB_PASSWORD';
EOSQL
