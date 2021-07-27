#!/bin/bash

# Common options shared by GnuPG calls in this script:
#   --homedir                  Sets our GnuPG home directory
#   --batch                    Disables all interactive commands
#   --pinentry-mode loopback   Sets Pinentry mode to loopback, used for supplying passphrase
#   --passphrase-fd 0          Tells GnuPG to read passphrase from standard input
#   --quiet                    Disables most of CLI outputs
#   --armor                    Use base64 on all binary outputs
COMMON_OPTS='--homedir ./.gnupg --batch --pinentry-mode loopback --passphrase-fd 0 --quiet --armor'

# Step 1: Create temp GnuPG directory
mkdir -pm 700 ./.gnupg

# Step 2: import signing key
cat > teacon.asc <<EOM
$PGP_KEY
EOM
gpg $COMMON_OPTS --import teacon.asc <<EOM
$PGP_PWD
EOM

# Step 3: copy file to currect directory
cp $ARTIFACT_PATH ./

# Step 4: sign the file
gpg $COMMON_OPTS --local-user TeaCon --detach-sign $ARTIFACT_NAME <<EOM
$PGP_PWD
EOM

# Step 5: destroy GnuPG directory
rm -rf ./.gnupg ./teacon.asc
