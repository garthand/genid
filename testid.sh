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
	# Create the genid_last_id file if it does not yet exist
	# and start the ID generation from 00000
	if ! test -f .genid_last_id
	then
		echo 00000 > .genid_last_id
	fi
	# Get the last used ID from the genid_last_id file
	last_number=$(cat .genid_last_id)
	# Increment the genid_last_id by one and format it
	# with leading zeros if necessary
	new_number=$(printf "%05d" "$(echo "$last_number + 1"|bc -l)")
	# Print the result to stdout and save it
	# to the genid_last_id file
	echo "$new_number" | tee .genid_last_id
	# Write the (empty) contents of file descriptor 222
	# to the file to release the lock
	) 222>.genid_lockfile
}

function genid_spawner {
	# Declare variables locally
	local count
	# Remove genid_test_results file if it exists from previous runs
	if test -f .genid_test_results
	then
		rm -f .genid_test_results
	fi
	# Export genid function for use within xargs subshells
	export -f genid
	count=0
	# Spawn 50 instances of genid_spawner
	while [ "$count" -lt 50 ]
	do
		# Run 1,000 instances of genid simultaneously in
		# the background, and append the output to a file
		# named genid_test_results
		seq 1000|xargs -P 1000 bash -c 'for arg; do genid; done' _ >> .genid_test_results &
		count=$((count + 1))
	done
}

function test_genid {
	# Declare variables locally
	local first_id
	local expected_output
	local actual_output
	# Find the expected first ID
	first_id=$(printf "%05d" "$(echo "$(cat .genid_last_id)" + 1|bc -l)")
	# Find the expected last ID
	last_id=$(printf "%05d" "$(echo "$first_id" + 50000|bc -l)")
	expected_output=$(printf "%05d\n" $(seq "$first_id" "$last_id"))
	genid_spawner
	actual_output=$(cat .genid_test_results)
	if [ "$expected_output" == "$actual_output" ]
	then
		echo "genid appears to be working correctly"
	else
		echo "genid is not working as expected"
	fi

}
