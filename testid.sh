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
	export GENID_LAST_ID
	count=0
	# Spawn 20 instances of genid_spawner
	while [ "$count" -lt "$GENID_NUM_LOOPS" ]
	do
		# Run 1,000 instances of genid simultaneously in
		# the background, and append the output to a file
		# named genid_test_results
		seq "$GENID_NUM_PROCS"|xargs -P "$GENID_NUM_PROCS" bash -c 'for arg; do genid; done' _ >> "$GENID_TEST_RESULTS" &
		count=$((count + 1))
	done
}

function genid_spawner_watcher {
	# Declare variables locally
	local first_reading
	local second_reading
	local matching
	# Print a message to stdout so users know the test isn't
	# simply hanging
	echo "Waiting for all genid instances to finish running, this may take some time..."
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

function generate_expected_output {
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
	echo "$expected_output"
}

function detailed_genid_report {
	# Declare variables locally
	local expected_output
	local expected_line_count
	local actual_line_count
	local first_expected_entry
	local first_actual_entry
	local last_expected_entry
	local last_actual_entry
	local duplicated_ids
	local missing_ids
	local genid_test
	# The expected output should be the only parameter
	expected_output=$1
	# Compare the actual vs expected line counts
	expected_line_count=$(wc -l <<< "$expected_output")
	actual_line_count=$(wc -l "$GENID_TEST_RESULTS"|awk '{print $1}')
	# Compare the actual vs expected first entries
	first_expected_entry=$(head -1 <<< "$expected_output")
	first_actual_entry=$(head -1 "$GENID_TEST_RESULTS")
	# Compare the actual vs expected last entries
	last_expected_entry=$(tail -1 <<< "$expected_output")
	last_actual_entry=$(tail -1 "$GENID_TEST_RESULTS")
	# Find duplicated lines
	duplicated_ids=$(uniq -d "$GENID_TEST_RESULTS")
	# Find missing IDs
	missing_ids=$(seq "$(head -n1 "$GENID_TEST_RESULTS")" "$(tail -n1 "$GENID_TEST_RESULTS")" | grep -vwFf "$GENID_TEST_RESULTS" || true)
	echo "Detailed report:"
	echo "------------------------------"
	genid_test="Expected and actual line count should match"
	if [ "$expected_line_count" != "$actual_line_count" ]
	then
		echo "FAIL: $genid_test"
		echo "Expected line count: $expected_line_count"
		echo "Actual line count: $actual_line_count"
	else
		echo "PASS: $genid_test"
	fi
	genid_test="Expected and actual first entry should match"
	if [ "$first_expected_entry" != "$first_actual_entry" ]
	then
		echo "FAIL: $genid_test"
		echo "First expected entry: $first_expected_entry"
		echo "First actual entry: $first_actual_entry"
	else
		echo "PASS: $genid_test"
	fi
	genid_test="Expected and actual last entry should match"
	if [ "$last_expected_entry" != "$last_actual_entry" ]
	then
		echo "FAIL: $genid_test"
		echo "Last expected entry: $last_expected_entry"
		echo "Last actual entry: $last_actual_entry"
	else
		echo "PASS: $genid_test"
	fi
	genid_test="No duplicate IDs should be found"
	if [ "$duplicated_ids" != "" ]
	then
		echo "FAIL: $genid_test"
		echo "Duplicated IDs:"
		echo "$duplicated_ids"
	else
		echo "PASS: $genid_test"
	fi
	genid_test="No missing IDs should be found"
	if [ "$missing_ids" != "" ]
	then
		echo "FAIL: $genid_test"
		echo "Missing IDs:"
		echo "$missing_ids"
	else
		echo "PASS: $genid_test"
	fi
	echo "------------------------------"
}

function test_genid {
	# Declare variables locally
	local expected_output
	local actual_output
	# Get expected output from running genid_spawner
	expected_output=$(generate_expected_output)
	# Begin running the test using genid
	genid_spawner
	# Wait for the genid spawner processes to complete before continuing
	genid_spawner_watcher
	actual_output=$(cat "$GENID_TEST_RESULTS")
	if [ "$expected_output" == "$actual_output" ]
	then
		printf "\nSUCCESS: genid appears to be working correctly\n\n"
	else
		printf "\nFALIURE: genid is not working as expected\n\n"
	fi
	detailed_genid_report "$expected_output"

}

# GLOBAL VARIABLES

GENID_NUM_LOOPS=10
GENID_NUM_PROCS=50
GENID_TEST_RESULTS=.genid_test_results
GENID_LAST_ID=.genid_last_id

test_genid
