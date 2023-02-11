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
	if ! test -f "$GENID_LAST_ID"
	then
		echo 00000 > "$GENID_LAST_ID"
	fi
	# Get the last used ID from the genid_last_id file
	last_number=$(cat "$GENID_LAST_ID")
	# Increment the genid_last_id by one and format it
	# with leading zeros if necessary
	new_number=$(printf "%05d" "$(echo "$last_number + 1"|bc -l)")
	# Print the result to stdout and save it
	# to the genid_last_id file
	echo "$new_number" | tee "$GENID_LAST_ID"
	# Write the (empty) contents of file descriptor 222
	# to the file to release the lock
	) 222>.genid_lockfile
}

function genid_spawner {
	# Declare variables locally
	local count
	# Remove genid_test_results file if it exists from previous runs
	if test -f "$GENID_TEST_RESULTS"
	then
		rm -f "$GENID_TEST_RESULTS"
	fi
	# Export genid function for use within xargs subshells
	export -f genid
	count=0
	# Spawn 20 instances of genid_spawner
	while [ "$count" -lt "$GENID_NUM_LOOPS" ]
	do
		# Run 1,000 instances of genid simultaneously in
		# the background, and append the output to a file
		# named genid_test_results
		seq 500|xargs -P "$GENID_NUM_PROCS" bash -c 'for arg; do genid; done' _ >> "$GENID_TEST_RESULTS" &
		count=$((count + 1))
	done
}

function genid_spawner_watcher {
	# Declare variables locally
	local first_reading
	local second_reading
	local matching
	matching="no"
	while [ "$matching" == "no" ]
	do
		# Read the genid_test_results file
		first_reading=$(cat "$GENID_TEST_RESULTS")
		# Wait a few seconds
		sleep 3
		# Read the genid_test results file again
		second_reading=$(cat "$GENID_TEST_RESULTS")
		# See if the readings are identical. If so,
		# genid_spawner has stopped updating the results
		# file and we can stop waiting
		if [ "$first_reading" == "$second_reading" ]
		then
			matching="yes"
		fi
	done
}

function test_genid {
	# Declare variables locally
	local first_id
	local lastid_difference
	local expected_output
	local actual_output
	# Find the expected first ID
	first_id=$(printf "%05d" "$(echo "$(cat "$GENID_LAST_ID")" + 1|bc -l)")
	# Find the difference between the first and last ID
	lastid_difference=$(echo "($GENID_NUM_LOOPS * $GENID_NUM_PROCS) - 1"|bc -l)
	# Find the expected last ID
	last_id=$(printf "%05d" "$(echo "$first_id" + "$lastid_difference"|bc -l)")
	# Generate the expected output for the given test range
	expected_output=$(printf "%05d\n" $(seq "$first_id" "$last_id"))
	# Begin running the test using genid
	genid_spawner
	# Wait for the genid spawner processes to complete before continuing
	genid_spawner_watcher
	actual_output=$(cat "$GENID_TEST_RESULTS")
	echo "$expected_output" > .genid_expected_results
	if [ "$expected_output" == "$actual_output" ]
	then
		echo "genid appears to be working correctly"
	else
		echo "genid is not working as expected"
	fi

}

# GLOBAL VARIABLES

GENID_NUM_LOOPS=20
GENID_NUM_PROCS=500
GENID_TEST_RESULTS=.genid_test_results
GENID_LAST_ID=.genid_last_id

test_genid
