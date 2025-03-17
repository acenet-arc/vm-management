#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "$1" == apache2* ]]; then
  
  uid="$(id -u)"
  gid="$(id -g)"
  if [ "$uid" = '0' ]; then
    case "$1" in
      apache2*)
        user="${APACHE_RUN_USER:-www-data}"
        group="${APACHE_RUN_GROUP:-www-data}"

        # strip off any '#' symbol ('#1000' is valid syntax for Apache)
        pound='#'
        user="${user#$pound}"
        group="${group#$pound}"
        ;;
      *) # php-fpm
        user='www-data'
        group='www-data'
        ;;
    esac
  else
    user="$uid"
    group="$gid"
  fi
  
  if [ ! -f "index.php" ]; then
    unzip -n /usr/src/omeka-s.zip && mv ./omeka-s/* . && mv ./omeka-s/.* . && rmdir ./omeka-s/
    chown $user:$group ./files
  fi
  
  if [[ ! -v OMEKAS_DB_USER ]]; then
    
    echo >&2 "ERROR: Required environment variable OMEKAS_DB_USER not set!"
    exit 1
  else
    
    if [[ -z "${OMEKAS_DB_USER}" ]]; then
      
      echo >&2 "ERROR: Required environment variable OMEKAS_DB_USER is an empty string!"
      exit 1
    fi
  fi
  
  if [[ ! -v OMEKAS_DB_PASSWORD ]]; then
    
    echo >&2 "ERROR: Required environment variable OMEKAS_DB_PASSWORD not set or is an empty string!"
    exit 1
  else
    
    if [[ -z "${OMEKAS_DB_PASSWORD}" ]]; then
      
      echo >&2 "ERROR: Required environment variable OMEKAS_DB_PASSWORD is an empty string!"
      exit 1
    fi
  fi
  
  if [[ ! -v OMEKAS_DB_NAME ]]; then
    
    echo >&2 "ERROR: Required environment variable OMEKAS_DB_NAME not set or is an empty string!"
    exit 1
  else
    
    if [[ -z "${OMEKAS_DB_NAME}" ]]; then
      
      echo >&2 "ERROR: Required environment variable OMEKAS_DB_NAME is an empty string!"
      exit 1
    fi
  fi
  
  if [[ ! -v OMEKAS_DB_HOST ]]; then
    
    echo >&2 "ERROR: Required environment variable OMEKAS_DB_HOST not set or is an empty string!"
    exit 1
  else
    
    if [[ -z "${OMEKAS_DB_HOST}" ]]; then
      
      echo >&2 "ERROR: Required environment variable OMEKAS_DB_HOST is an empty string!"
      exit 1
    fi
  fi
  
  sed -i "s/user     = \".*\"/user     = \"${OMEKAS_DB_USER}\"/g" config/database.ini
  sed -i "s/password = \".*\"/password = \"${OMEKAS_DB_PASSWORD}\"/g" config/database.ini
  sed -i "s/dbname   = \".*\"/dbname   = \"${OMEKAS_DB_NAME}\"/g" config/database.ini
  sed -i "s/host     = \".*\"/host     = \"${OMEKAS_DB_HOST}\"/g" config/database.ini
  
fi

exec "$@"
