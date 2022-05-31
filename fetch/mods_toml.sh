#!/bin/bash

unzip -p $ARTIFACT_NAME META-INF/mods.toml | tee mods.toml
echo ::set-output name=base64::`base64 -w 0 mods.toml`
