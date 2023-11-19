#!/bin/bash

# MySql root user what used for create users and databases 
MYSQL_USER="root"
# MtSql root user password
MYSQL_PASSWORD=""
# Default password for created databases
MYSQL_PROJECT_DEFAULT_PASSWORD="1234567"
# Name of apache service - for example httpd2 for ALT linux and apache2 for Ununtu
APACHE_SERVICE="httpd2";
# Your projects root folder. All projects will be stored here
PROJECTS_ROOT="/home/rnr1721/Documents/PhpStormProjects";
# Apache sites-available folder in etc. In Ubuntu is /etc/apache2/sites-available
SITES_AVAILABLE="/etc/httpd2/conf/sites-available";
# What local sites you want? Default is site.local
ADDRESS_SUFFIX="local"

# Check if we run of root
if [[ $EUID -eq 0 ]]; then
   echo "This script cannot be launched by root."
   exit 1
fi

# Array of needed utilites
required_utilities=("git" "openssl" "sudo" "systemctl")

# Check for each utilite
for util in "${required_utilities[@]}"; do
    if ! command -v "$util" &> /dev/null; then
        echo "Error: '$util' utility not found. Please install it before running this script."
        exit 1
    fi
done

# Usage info
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 project_name action [git_repo]"
  echo "Example 1: $0 create myproject1"
  echo "Example 1: $0 delete myproject1"
  exit 1
fi

ACTION=$1
PROJECT_NAME=$2
GIT_REPO=$3

# Check if action if empty
if [ -z "$ACTION" ]; then
  echo "Action is empty. Please provide a valid argument."
  exit 1
fi

# Check if project name empty
if [ -z "$PROJECT_NAME" ]; then
  echo "Project name is empty. Please provide a valid argument."
  exit 1
fi

# Check for MySQL exists MySQL
if ! command -v mysql &> /dev/null; then
    echo "Error: MySQL not found. Please install MySQL before running this script."
    exit 1
fi

PROJECT_ROOT=$PROJECTS_ROOT/$PROJECT_NAME
PROJECT_WWW=$PROJECT_ROOT/www
PROJECT_LOGS=$PROJECT_ROOT/logs
PROJECT_BACKUPS=$PROJECT_ROOT/backups
PROJECT_DOCS=$PROJECT_ROOT/docs
PROJECT_SSL=$PROJECT_ROOT/ssl

case "$ACTION" in
    "create")

        # Check for DB user of DEV site exists MySQL
        user_exists=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$PROJECT_NAME')" -s)

        if [ "$user_exists" -eq 1 ]; then
            echo "User $PROJECT_NAME already exists in MySQL. Exiting."
            exit 1
        fi

        # Check if DB exists
        db_exists=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = '$PROJECT_NAME')" -s)

        if [ "$db_exists" -eq 1 ]; then
            echo "Database $PROJECT_NAME already exists in MySQL. Exiting."
            exit 1
        fi

        # Check if project dir exists
        if [ -d "$PROJECTS_ROOT/$PROJECT_NAME" ]; then
          echo "Directory '$PROJECTS_ROOT/$PROJECT_NAME' already exists. Exiting."
          exit 1
        fi

        # Check if VirtualHost exists
        if [ -e "$SITES_AVAILABLE/$PROJECT_NAME.conf" ]; then
          echo "Error: Configuration file '$SITES_AVAILABLE/$PROJECT_NAME.conf' already exists."
          exit 1
        fi

        mkdir -p "$PROJECT_LOGS"
        mkdir -p "$PROJECT_BACKUPS"
        mkdir -p "$PROJECT_DOCS"
        mkdir -p "$PROJECT_SSL"

        # Check hosts file, and add to it if project not present
        if ! grep -q "$PROJECT_NAME.$ADDRESS_SUFFIX" /etc/hosts; then
          echo "127.0.0.1 $PROJECT_NAME.$ADDRESS_SUFFIX" | sudo tee -a /etc/hosts > /dev/null
        fi

        if [ -n "$GIT_REPO" ]; then
            if git clone "$GIT_REPO" "$PROJECT_WWW"; then
                echo "GIT project clone sucessfully"
            else
                echo "Project GIT clone error"
            fi
        fi

        if [ ! -d "$PROJECT_WWW" ]; then
            mkdir -p "$PROJECT_WWW"
            echo "Directory created: $PROJECT_WWW"
        fi

        if [ ! -f "$PROJECT_SSL/$PROJECT_NAME.$ADDRESS_SUFFIX.key" ]; then
          openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$PROJECT_SSL/$PROJECT_NAME.$ADDRESS_SUFFIX.key" -out "$PROJECT_SSL/$PROJECT_NAME.$ADDRESS_SUFFIX.crt" -subj "/CN=$PROJECT_NAME.$ADDRESS_SUFFIX"
        fi

        # Ask user about project public folder
        read -p "Enter the public directory (press Enter to use the default directory $PROJECT_WWW): " PUBLIC_DIR

        # Set PROJECT_PUBLIC for project public folder for web server
        if [ -z "$PUBLIC_DIR" ]; then
          PROJECT_PUBLIC="$PROJECT_WWW"
        else
          PROJECT_PUBLIC="$PROJECT_WWW/$PUBLIC_DIR"
          mkdir -p "$PROJECT_PUBLIC"
        fi

        # Create new VirtualHost
        sudo tee "$SITES_AVAILABLE/$PROJECT_NAME.$ADDRESS_SUFFIX.conf" > /dev/null << EOF
        <VirtualHost *:80>
            ServerAdmin webmaster@$PROJECT_NAME.$ADDRESS_SUFFIX
            DocumentRoot $PROJECT_PUBLIC
            ServerName $PROJECT_NAME.$ADDRESS_SUFFIX
            ServerAlias www.$PROJECT_NAME.$ADDRESS_SUFFIX

            ErrorLog $PROJECT_LOGS/error.log
            CustomLog $PROJECT_LOGS/access.log combined

            DirectoryIndex index.php

            Include /etc/httpd2/conf/include/php7-fpm.conf

            <Directory "$PROJECT_PUBLIC">
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Require all granted
            </Directory>

            LogLevel debug

        </VirtualHost>

        <VirtualHost *:443>
            ServerAdmin webmaster@$PROJECT_NAME.$ADDRESS_SUFFIX
            DocumentRoot $PROJECT_PUBLIC
            ServerName $PROJECT_NAME.$ADDRESS_SUFFIX
            ServerAlias www.$PROJECT_NAME.$ADDRESS_SUFFIX

            ErrorLog $PROJECT_LOGS/error.log
            CustomLog $PROJECT_LOGS/access.log combined

            DirectoryIndex index.php

            Include /etc/httpd2/conf/include/php7-fpm.conf

            <Directory "$PROJECT_PUBLIC">
                Options Indexes FollowSymLinks MultiViews
                AllowOverride All
                Require all granted
            </Directory>

            LogLevel debug

            SSLEngine on
            SSLCertificateFile $PROJECT_SSL/$PROJECT_NAME.$ADDRESS_SUFFIX.crt
            SSLCertificateKeyFile $PROJECT_SSL/$PROJECT_NAME.$ADDRESS_SUFFIX.key
        </VirtualHost>
EOF

        sudo a2ensite ${PROJECT_NAME}.$ADDRESS_SUFFIX

        sudo systemctl restart ${APACHE_SERVICE}

        mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "CREATE USER '$PROJECT_NAME'@'localhost' IDENTIFIED BY '$MYSQL_PROJECT_DEFAULT_PASSWORD'"
        mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "CREATE DATABASE $PROJECT_NAME"
        mysql -u${MYSQL_USER} -p${MYSQL_PASSWORD} -e "GRANT ALL PRIVILEGES ON $PROJECT_NAME.* TO '$PROJECT_NAME'@'localhost'"
        
        echo "Project created"
        echo "Your project path: $PROJECT_ROOT"
        echo "Web server public path: $PROJECT_PUBLIC"
        echo "Your new DEV domain: http://$PROJECT_NAME.$ADDRESS_SUFFIX or https://$PROJECT_NAME.$ADDRESS_SUFFIX"
        echo "Your database: user: $PROJECT_NAME db: $PROJECT_NAME password: $MYSQL_PROJECT_DEFAULT_PASSWORD"
        ;;
    "delete")

        # delete project folder if exists
        if [ -d "$PROJECT_ROOT" ]; then
            sudo rm -rf "$PROJECT_ROOT"
            echo "Directory '$PROJECT_ROOT' has been deleted."
        else
            echo "Directory '$PROJECT_ROOT' does not exist. Nothing to delete."
        fi

        sudo systemctl stop $APACHE_SERVICE

        if [ -f "$SITES_AVAILABLE/$PROJECT_NAME.$ADDRESS_SUFFIX.conf" ]; then
            sudo a2dissite ${PROJECT_NAME}.$ADDRESS_SUFFIX
            sudo rm "$SITES_AVAILABLE/$PROJECT_NAME.$ADDRESS_SUFFIX.conf"
        else
            echo "VirtualHost '${SITES_AVAILABLE}/${PROJECT_NAME}.$ADDRESS_SUFFIX' does not exist."
        fi

        # Delete from hosts file project record if exists
        if grep -q "$PROJECT_NAME.$ADDRESS_SUFFIX" /etc/hosts; then
            sudo sed -i "/$PROJECT_NAME.$ADDRESS_SUFFIX/d" /etc/hosts
            echo "Host entry for '$PROJECT_NAME.$ADDRESS_SUFFIX' has been removed from /etc/hosts."
        else
            echo "Host entry for '$PROJECT_NAME.$ADDRESS_SUFFIX' does not exist in /etc/hosts."
        fi

        # Check if database exists
        db_exists=$(mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = '$PROJECT_NAME')" -s)

        if [ "$db_exists" -eq 1 ]; then
            mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "DROP DATABASE $PROJECT_NAME"
            mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "DROP USER '$PROJECT_NAME'@'localhost'"
            echo "Database '$PROJECT_NAME' and user '$PROJECT_NAME'@'localhost' have been deleted."
        else
            echo "Database '$PROJECT_NAME' does not exist. Nothing to delete."
        fi

        sudo service $APACHE_SERVICE start;

        echo "Project '$PROJECT_NAME' has been deleted."
        ;;
    *)
        echo "Invalid action. Please use 'create' or 'delete'."
        exit 1
        ;;
esac
