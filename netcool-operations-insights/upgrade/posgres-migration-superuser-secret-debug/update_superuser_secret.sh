#!/bin/bash

set -eu

# Set your secret name and namespace
# oc get secret -A | grep noi-postgres-cluster-superuser
SECRET_NAME="your-postgres-superuser-secret-name"
NAMESPACE="your-postgres-superuser-secret-namespace"

# Check if default values are still set and prompt for input
if [[ "$SECRET_NAME" == "your-postgres-superuser-secret-name" ]]; then
    echo "Finding PostgreSQL superuser secrets..."
    echo ""
    
    # Run the command and display results with headers
    if command -v oc &> /dev/null; then
        oc get secret -A | head -1
        oc get secret -A | grep noi-postgres-cluster-superuser || echo "No secrets found matching 'noi-postgres-cluster-superuser'"
    else
        kubectl get secret -A | head -1
        kubectl get secret -A | grep noi-postgres-cluster-superuser || echo "No secrets found matching 'noi-postgres-cluster-superuser'"
    fi
    
    echo ""
    read -p "Enter the PostgreSQL superuser secret name: " SECRET_NAME
    if [[ -z "$SECRET_NAME" ]]; then
        echo "Error: Secret name cannot be empty"
        exit 1
    fi
fi

if [[ "$NAMESPACE" == "your-postgres-superuser-secret-namespace" ]]; then
    read -p "Enter the namespace: " NAMESPACE
    if [[ -z "$NAMESPACE" ]]; then
        echo "Error: Namespace cannot be empty"
        exit 1
    fi
fi

echo "Using secret: $SECRET_NAME in namespace: $NAMESPACE"
echo ""

# Extract existing data from the secret
PASSWORD=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)
USER=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.user}' | base64 -d)
PGPASS=$(kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath='{.data.pgpass}' | base64 -d)

# Parse pgpass (format: host:port:dbname:user:password)
IFS=':' read -r HOST PORT DBNAME PGPASS_USER PGPASS_PASSWORD <<< "$PGPASS"

# Create URI
URI="postgresql://${USER}:${PASSWORD}@${HOST}.${NAMESPACE}:${PORT}/${DBNAME}"

# Create JDBC URI
JDBC_URI="jdbc:postgresql://${HOST}.${NAMESPACE}:${PORT}/${DBNAME}?password=${PASSWORD}&user=${USER}"

# Function to add field only if it doesn't exist
add_if_not_exists() {
    local field=$1
    local value=$2
    
    # Check if field exists
    if kubectl get secret $SECRET_NAME -n $NAMESPACE -o jsonpath="{.data.$field}" 2>/dev/null | grep -q .; then
        echo "  $field: already exists, skipping"
    else
        echo "  $field: adding"
        kubectl patch secret $SECRET_NAME -n $NAMESPACE --type='merge' -p="{\"stringData\":{\"$field\":\"$value\"}}"
    fi
}

echo "Updating secret $SECRET_NAME in namespace $NAMESPACE..."
echo ""

# Add each field only if it doesn't exist
add_if_not_exists "host" "$HOST"
add_if_not_exists "port" "$PORT"
add_if_not_exists "dbname" "$DBNAME"
add_if_not_exists "username" "$USER"
add_if_not_exists "uri" "$URI"
add_if_not_exists "jdbc-uri" "$JDBC_URI"

echo ""
echo "Secret update complete!"