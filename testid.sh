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
	# and start the ID generation from 00000
	if ! test -f .last_id
	then
		echo 00000 > .last_id
	fi
	# Get the last used ID from the last_id file
	last_number=$(cat .last_id)
	# Increment the last_id by one and format it
	# with leading zeros if necessary
	new_number=$(printf "%05d" "$(echo "$last_number + 1"|bc -l)")
	# Print the result to stdout and save it
	# to the last_id file
	echo "$new_number" | tee .last_id
	# Write the (empty) contents of file descriptor 222
	# to the file to release the lock
	) 222>.genid_lockfile
}

function genid_spawner {
	# Run 1,000 instances of genid simultaneously
	export -f genid
	seq 1000|xargs -P 1000 bash -c 'for arg; do genid; done' _
}

genid_spawner > results &
genid_spawner > results &
genid_spawner > results &
