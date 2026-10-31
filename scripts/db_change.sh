#!/usr/bin/env bash

set -euo pipefail

#
# This script replaces all production settings in the given SQL file with dev environment settings.
# It is intended to be used on a SQL dump of the production database, before importing it into the dev environment.
# It changes
#   - the collation,
#   - the site and home URL and blog name,
#   - the WP Mail settings (to use mailpit)
#   - the mail settingy of the AcyMailing component (to use mailpit)
#
# Some things, specifically email addresses are NOT changed, as the development environment is expected to run with mailpit as
# SMTP server, which captures all outgoing emails and does not send them to the real recipients.

usage() {
    echo "Usage: $0 <sql-file> <hostname> [y]"
    exit 1
}


if [[ "$#" -lt 2 ]]; then
    usage
fi

fname="$1"
if [[ ! -f "$fname" ]]; then
    echo "File '$fname' not found!"
    usage
fi

DEV_HOST="$2"

yesno="n"
if [[ "$#" -eq 3 ]]; then
    yesno="$3"
    if [[  $yesno != [yY] ]]; then
        usage
    fi
fi

PROD_URL="https://schwarzweisskoeln.de"
DEV_URL="http://$DEV_HOST"
DEV_NAME="DEV SWK"
#DEV_ADMIN_MAIL="jrt@gmx.de"
#DEV_NL_MAIL="jrt@gmx.de"
#DEV_NL_NAME="DEV Newsletter"
#DEV_SMTP_HOST="mailpit"
#DEV_SMTP_PORT=1025
#DEV_SMTP_USR="usr"
#DEV_SMTP_PWD="pwd"


if [[ $yesno != [yY] ]]; then
    echo "I am about to process DB '$fname' and change all production settings to dev environment settings."
    echo "Specifically I will change '$PROD_URL' to '$DEV_URL'".

    read -r -p "Are you sure? [y/N] " response
    lower=$(printf '%s' "$response" | tr '[:upper:]' '[:lower:]')
    if ! [[ "$lower" =~ ^(yes|y)$ ]]; then
        echo "Ok, exiting..."
        exit
    fi
fi

echo "Replacing DB collation, wp_options and mail configuration..."

sed -i'.bak' \
    -e 's/utf8mb4_0900_ai_ci/utf8mb4_unicode_520_ci/g' \
    -e "s|(1,'siteurl','$PROD_URL','yes')|(1,'siteurl','$DEV_URL','yes')|g" \
    -e "s|(2,'home','$PROD_URL','yes')|(2,'home','$DEV_URL','yes')|g" \
    -e "s|(3,'blogname','Schwarz-Weiß Köln','yes')|(3,'blogname','$DEV_NAME','yes')|g" \
    -e 's|s:4:\\\"host\\\";s:18:\\\"smtp.azurecomm.net\\\";|s:4:\\\"host\\\";s:7:\\\"mailpit\\\";|g' \
    -e 's|s:4:\\\"port\\\";i:587;|s:4:\\\"port\\\";i:1025;|g' \
    -e 's|s:7:\\\"autotls\\\";b:1;|s:7:\\\"autotls\\\";b:0;|g' \
    -e 's|s:10:\\\"encryption\\\";s:3:\\\"tls\\\";|s:10:\\\"encryption\\\";s:4:\\\"none\\\";|g' \
    -e "s/('smtp_host','smtp.azurecomm.net')/('smtp_host','mailpit')/g" \
    -e "s/('smtp_port','587')/('smtp_port','1025')/g" \
    -e "s/('smtp_secured','tls')/('smtp_secured','')/g" \
     "$fname"

    # -e "s/(6,'admin_email','webmaster@schwarzweisskoeln.de','yes')/(6,'admin_email','$DEV_ADMIN_MAIL','yes')/g" \
