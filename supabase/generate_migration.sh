#!/bin/bash

set -e  # fail on error of any command below

if ! [[ "$*" =~ ^[a-zA-Z0-9_]{4,60}$ ]]
  then
    echo "Invalid migration name '$*'"
    echo 'Please include name for migration, formatted with underscores, no dashes or numbers (migration number will be autogenerated) please.'
    exit 1
fi

BASE_DIR=$(realpath .)

# Load shared functions
source supabase/shared_functions.sh

MIGRATION_FILE_NAME="$(printf '%04g' $(ls -l migrations/ley | wc -l))_$1"
MIGRATION_UP_FILE="migrations/up/${MIGRATION_FILE_NAME}.sql"
MIGRATION_UP_FILE_OUT="migrations/up/${MIGRATION_FILE_NAME}.out"
MIGRATION_DOWN_FILE="migrations/down/${MIGRATION_FILE_NAME}.sql"
MIGRATION_DOWN_FILE_OUT="migrations/down/${MIGRATION_FILE_NAME}.out"
LEY_MIGRATION_FILENAME="migrations/ley/${MIGRATION_FILE_NAME}.js"

generate_migration(){
  echo "Linking migration files..."
  link_migration_files

  echo "Generating migration up to ${MIGRATION_UP_FILE}. Tail the .out file to see progress..."
  supabase db diff > $MIGRATION_UP_FILE_OUT  # tmp file, will be cleaned up below

  # Grab only the lines starting from "This script was generated by..."
  sed -n -e '/-- This script was generated by the Schema Diff utility in pgAdmin 4/,$p' $MIGRATION_UP_FILE_OUT > $MIGRATION_UP_FILE
  rm $MIGRATION_UP_FILE_OUT

  echo "De-linking supabase/migration files..."
  delink_migration_files  

  echo "Make any necessary changes to $MIGRATION_UP_FILE. Press enter to continue, Ctrl+C to exit."
  read

  echo "Creating ley migration file..." 
  cp ley.migration.template.js $LEY_MIGRATION_FILENAME

  echo "Re-applying migrations back to local..."
  supabase db reset
  SUPABASE_DB_URL=$TEST_DB_URL npm run db up

  echo "Updating remote's migrations tables (with the new migration history)..."
  pg_dump --clean --table public.migrations $TEST_DB_URL | psql $SUPABASE_DB_URL

  echo "Generating types from db"
  generate_types

  echo "Generating view definitions from local db"
  generate_view_defs_from_local
}

generate_migration_down(){
  #### Now, generating the down migration file ####
  # Reset the DB to original state before the changes we applied
  echo "Reseting to original state to generate migration down..."
  supabase db reset

  # Link the new migration file to the supabase/migrations folder so it can be diffed against original state 
  ln -s $BASE_DIR/migrations/up/$MIGRATION_FILE_NAME.sql $BASE_DIR/supabase/migrations/$MIGRATION_FILE_NAME.sql

  ls $BASE_DIR/supabase/migrations
  echo "Generating migration down to ${MIGRATION_DOWN_FILE}. Tail the .out file to see progress..."
  supabase db diff > $MIGRATION_DOWN_FILE_OUT  # tmp file, will be cleaned up below

  # Grab only the lines starting from "This script was generated by..."
  sed -n -e '/-- This script was generated by the Schema Diff utility in pgAdmin 4/,$p' $MIGRATION_DOWN_FILE_OUT > $MIGRATION_DOWN_FILE
  rm $MIGRATION_DOWN_FILE_OUT
}

clean_migrations_on_fail(){
  echo "Error generating migration $MIGRATION_FILE_NAME..."
  # Delete generated migration files
  if [ -f "$MIGRATION_UP_FILE" ]; then
    rm $MIGRATION_UP_FILE
  fi
  if [ -f "$MIGRATION_UP_FILE_OUT" ]; then
    rm $MIGRATION_UP_FILE_OUT
  fi
  if [ -f "$MIGRATION_DOWN_FILE" ]; then
    rm $MIGRATION_DOWN_FILE
  fi
  if [ -f "$MIGRATION_DOWN_FILE_OUT" ]; then
    rm $MIGRATION_DOWN_FILE_OUT
  fi
  if [ -f "$LEY_MIGRATION_FILENAME" ]; then
    rm $LEY_MIGRATION_FILENAME
  fi
}

echo "###### STEP 1: Pulling remote changes into local database ######"
pull_remote_into_local
echo "###### STEP 2: Computing diffs and generating up/down migrations ######"
generate_migration || clean_migrations_on_fail
echo "###### Done ######"
