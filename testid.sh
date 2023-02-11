#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

function genid {
	(flock 222
	last_count=$(cat countfile)
	count=$((last_count+1))
	echo "$count" > countfile
	echo "$count"
	) 222>.genid_lockfile
}

genid
