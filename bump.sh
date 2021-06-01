#!/bin/bash

set -euo pipefail

printUsage() {
    echo "Script for bumping version of targets in xcode projects."
    echo "Script usage:"
    echo "sh <path_to_script> <options>"
    echo ""
    echo "Options: "
    echo "  -f <value>     fastlane lane for bumping version (see Fastfile for available values)"
    echo "  -g <value>     git repo to upload bumped version"
    echo ""
}

printInputValidationFailure() {
	echo "Invalid usage."
    echo "Required input missing - $1. Please pass scheme (-$2) argument"
    echo ""
}

FASTLANE_LANE=""
GIT_PATH=""

# Process options
while getopts f:g: flag
do
    case "${flag}" in
        f) FASTLANE_LANE=${OPTARG};;
        g) GIT_PATH=${OPTARG};; 
    esac
done

if [ -z ${FASTLANE_LANE} ]; then 
	printInputValidationFailure "fastlane lane" "f"
    printUsage 
    exit 2
fi

if [ -z ${GIT_PATH} ]; then 
	printInputValidationFailure "git repo" "g"
    printUsage 
    exit 2
fi

echo "[INFO] Git path: $GIT_PATH"

echo "[INFO] Reseting master branch"
git checkout master
git fetch origin
git reset --hard origin/master

fastlane ios $FASTLANE_LANE

echo "[INFO] Creating bumped commit"
git add -A
git commit -m "Bumped by CI"
git push $GIT_PATH master
