#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

function genid {
	# Define variables locally
	local last_number
	local new_number
	# Create a file lock on descriptor 222
	# If another process already has a lock on 222,
	# wait for the file lock to be released before continuing
	(flock 222
	# Create the last_id file if it does not yet exist
	# and start the ID generation from 0
	if ! test -f .last_id
	then
		echo 0 > .last_id
	fi
	# Get the last used ID from the last_id file
	last_number=$(cat .last_id)
	# Increment the last_id by one
	new_number=$((last_number + 1))
	# Print the result to stdout and save it
	# to the last_id file
	echo "$new_number" | tee .last_id
	) 222>.genid_lockfile
}

genid
