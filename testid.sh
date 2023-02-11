#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

function genid {
	(flock 222
	local last_number
	local new_number
	last_number=$(cat countfile)
	new_number=$((last_number + 1))
	echo "$new_number" > countfile
	echo "$new_number"
	) 222>.genid_lockfile
}

genid
