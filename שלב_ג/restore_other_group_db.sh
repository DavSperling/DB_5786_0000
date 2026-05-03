#!/bin/bash

# Nom du container PostgreSQL défini dans le docker-compose.yml
CONTAINER_NAME="PostgreSQL_DB"
# Chemin vers le fichier backup de l'autre groupe
BACKUP_FILE="/Users/david/Downloads/backup2.sql"
# Nom de la base de données à créer pour l'autre groupe
DB_NAME="other_group_db"

echo "🚀 Début du processus de restauration..."

# 1. Copier le fichier backup dans le container
echo "📦 Copie du fichier de backup dans le container ($CONTAINER_NAME)..."
docker cp "$BACKUP_FILE" $CONTAINER_NAME:/tmp/backup2.sql

# 2. Créer la base de données temporaire
echo "🛠️  Création de la base de données : $DB_NAME..."
# On ignore l'erreur si la base existe déjà
docker exec -it $CONTAINER_NAME psql -U admin -d restaurant_db -c "CREATE DATABASE $DB_NAME;" || echo "La base de données existe peut-être déjà."

# 3. Restaurer le backup
echo "🔄 Restauration des données depuis le backup..."
docker exec -it $CONTAINER_NAME psql -U admin -d $DB_NAME -f /tmp/backup2.sql

echo "✅ Restauration terminée avec succès !"
