#!/bin/bash

# Name of the PostgreSQL container defined in docker-compose.yml
CONTAINER_NAME="PostgreSQL_DB"
# Path to the other team's backup file
BACKUP_FILE="/Users/david/Downloads/backup2.sql"
# Name of the database to create for the other team
DB_NAME="other_group_db"

echo "Starting the restore process..."

# 1. Copy the backup file into the container
echo "Copying the backup file into the container ($CONTAINER_NAME)..."
docker cp "$BACKUP_FILE" $CONTAINER_NAME:/tmp/backup2.sql

# 2. Create the temporary database
echo "Creating database: $DB_NAME..."
# Ignore the error if the database already exists
docker exec -it $CONTAINER_NAME psql -U admin -d restaurant_db -c "CREATE DATABASE $DB_NAME;" || echo "The database may already exist."

# 3. Restore the backup
echo "Restoring data from the backup..."
docker exec -it $CONTAINER_NAME psql -U admin -d $DB_NAME -f /tmp/backup2.sql

echo "Restore completed successfully."
