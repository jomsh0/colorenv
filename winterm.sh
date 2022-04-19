#!/usr/bin/env sh

# Usage: ./winterm.sh Campbell < winterm.json | ./colorenv.sh apply

exec jq -r '.[] | select(.name == ($ARGS.positional[0] // .name)) | to_entries | map(.key + "=" + .value)[]' \
    --args "$@"
