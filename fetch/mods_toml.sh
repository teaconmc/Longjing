#!/bin/bash

unzip -p $ARTIFACT_PATH META-INF/mods.toml | tee mods.toml

echo # some mods.toml file does not have a line break at the end
echo ::set-output name=base64::`base64 -w 0 mods.toml`
