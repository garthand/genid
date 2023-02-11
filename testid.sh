#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

function genid {
	local last_number
	local new_number
	(flock 222
	last_number=$(cat .last_id)
	new_number=$((last_number + 1))
	echo "$new_number" > .last_id
	echo "$new_number"
	) 222>.genid_lockfile
}

genid
