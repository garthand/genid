#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

function genid {
	(flock 222
	echo "Test test"
	) 222>.genid_lockfile
}

genid
