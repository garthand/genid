#!/bin/bash

# Set bash unofficial "strict mode"
set -euo pipefail
IFS=$'\n\t'

# Test linter with bad code

if [ 5 -gt 6 ]
then
	echo fail

