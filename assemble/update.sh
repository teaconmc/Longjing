#!/bin/bash

GPG_OPTS='--homedir ./.gnupg --batch --pinentry-mode loopback --passphrase-fd 0 --quiet --armor'
S3_OPTS="--endpoint-url $S3_ENDPOINT"

# Setup GnuPG
mkdir -pm 700 ./.gnupg
cat > teacon.asc <<EOM
$PGP_KEY
EOM
gpg $GPG_OPTS --import teacon.asc <<EOM
$PGP_PWD
EOM

for e in `jq -c '.[]' extra.json`; do
  cat > tmp.json <<EOM
$e
EOM

  NAME=`jq -r .name tmp.json`
  echo Considering $NAME
  EXISTED=''
  SIGNED=''

  # Check status of target files.
  # If mirror=false, then we assume that the file is available.
  if [ `jq -r .mirror tmp.json` == 'false' ]; then
    EXISTED=true
  else
    # NOTE: The bucket name 2022 here is not real bucket name, the real bucket name
    # is part of the endpoint URL. The 2022 here is mere the 1st level directory name,
    # or more precisely speaking, the part of the object tag before first forward slash.
    # This means that, this bucket name need to change on each event.
    aws s3api head-object $S3_OPTS --bucket 2022 --key "ci/extra/$NAME" >/dev/null && EXISTED=true
  fi
  aws s3api head-object $S3_OPTS --bucket 2022 --key "ci/extra/$NAME.asc" >/dev/null && SIGNED=true

  # If the file in question exists on remote, skip the uploading part.
  if [ $EXISTED ]; then
    echo $NAME already existed on remote, skipping
    if [ $SIGNED ]; then
      echo $NAME already signed, skipping
      continue
    fi
  fi

  # Download the missing mod for later use.
  URI=`jq -r .file tmp.json`
  curl -s $URI -o $NAME

  # If the file itself doesn't exist, try verify the checksum and upload it.
  if [ ! $EXISTED ]; then
    echo `jq -r .sha256 tmp.json` " $NAME" > checksum
    shasum -a 256 -s -c checksum
    # If checksum mismatch, then we stop; otherwise upload it to remote.
    if [ ! $? ]; then
      echo Check sum failed for $NAME
      continue
    else
      aws s3 cp $S3_OPTS $NAME "s3://2022/ci/extra/$NAME"
    fi
  fi

  # If the signature doesn't exist, upload the signature.
  if [ ! $SIGNED ]; then
    gpg $GPG_OPTS --local-user TeaCon --detach-sign $NAME <<EOM
$PGP_PWD
EOM
    aws s3 cp $S3_OPTS "$NAME.asc" "s3://2022/ci/extra/$NAME.asc"
  fi

  rm -f tmp.json checksum
done

rm -rf teacon.asc .gnupg
