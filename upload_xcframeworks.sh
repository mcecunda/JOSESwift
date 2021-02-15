printUsage() {
    echo "Script for uploading compressed xcframeworks with checksums to nexus repository manager."
    echo "Script usage:"
    echo "sh <path_to_script> <options>"
    echo ""
    echo "Options: "
    echo "  -r <value>     target repository"
    echo "  -g <value>     uploaded group (inspired by maven)"
    echo "  -a <value>     uploaded artifact (without .xcframework extension)"
    echo "  -v <value>     uploaded version"
    echo "  -p <value>     path to directory with xcframework (defaults to current directory)"
    echo ""
}

printInputValidationFailure() {
	echo "Invalid usage."
    echo "Required input missing - $1. Please pass scheme (-$2) argument"
    echo ""
}

set -eo pipefail

NEXUS_REPO=""
NEXUS_GROUP=""
NEXUS_ARTIFACT=""
VERSION=""
PATH_TO_XCFRAMEWORK="./"
OUTPUT_DIVIDER="\n --------------- \n"

echo "Processing input options"
while getopts r:g:a:v:p: flag
do
    case "${flag}" in
        r) NEXUS_REPO=${OPTARG};;
		g) NEXUS_GROUP=${OPTARG};;
		a) NEXUS_ARTIFACT=${OPTARG};;
        v) VERSION=${OPTARG};; 
        p) PATH_TO_XCFRAMEWORK=${OPTARG};;
    esac
done

if [ -z ${NEXUS_REPO} ]; then 
	printInputValidationFailure "repository" "r"
    printUsage 
    exit 2
fi

if [ -z ${NEXUS_GROUP} ]; then 
	printInputValidationFailure "group" "g"
    printUsage 
    exit 2
fi

if [ -z ${NEXUS_ARTIFACT} ]; then 
	printInputValidationFailure "artifact" "a"
    printUsage 
    exit 2
fi

if [ -z ${VERSION} ];  then 
	printInputValidationFailure "version" "v"
    printUsage
    exit 2
fi
echo "$OUTPUT_DIVIDER"

REPOSITORY_MANAGER_URL="https://nexus3-public.monetplus.cz/repository"
UPLOAD_PATH="$REPOSITORY_MANAGER_URL/$NEXUS_REPO/$NEXUS_GROUP/$NEXUS_ARTIFACT/$VERSION/"
XCFRAMEWORK=$NEXUS_ARTIFACT.xcframework
XCFRAMEWORK_ZIP=$XCFRAMEWORK.zip
XCFRAMEWORK_CHECKSUM=$XCFRAMEWORK.zip.checksum

echo "Initiated upload of $XCFRAMEWORK (zip & checksum) to $UPLOAD_PATH"
echo "$OUTPUT_DIVIDER"

echo "cd to: $PATH_TO_XCFRAMEWORK"
cd $PATH_TO_XCFRAMEWORK
echo "$OUTPUT_DIVIDER"

echo "Removing old files: $XCFRAMEWORK_ZIP, $XCFRAMEWORK_CHECKSUM"
rm -f $XCFRAMEWORK_ZIP
rm -f $XCFRAMEWORK_CHECKSUM
echo "$OUTPUT_DIVIDER"

echo "Compressing $XCFRAMEWORK to $XCFRAMEWORK_ZIP"
zip -db -dc "$XCFRAMEWORK_ZIP" -r $XCFRAMEWORK
echo "$OUTPUT_DIVIDER"

echo "Calculating checksum for $XCFRAMEWORK_ZIP"
swift package compute-checksum ./$XCFRAMEWORK_ZIP >> $XCFRAMEWORK_CHECKSUM
echo "Resulting $XCFRAMEWORK_ZIP checksum: "
cat $XCFRAMEWORK_CHECKSUM
echo "$OUTPUT_DIVIDER"

echo "Uploading $XCFRAMEWORK files to Nexus"
echo "Uploading $XCFRAMEWORK_ZIP to $UPLOAD_PATH"
curl --user "$NEXUS_NAME:$NEXUS_PWD" --upload-file "$XCFRAMEWORK_ZIP" "$UPLOAD_PATH" --fail #-v
echo "Uploading $XCFRAMEWORK_CHECKSUM to $UPLOAD_PATH"
curl --user "$NEXUS_NAME:$NEXUS_PWD" --upload-file "$XCFRAMEWORK_CHECKSUM" "$UPLOAD_PATH" --fail #-v 
echo "$OUTPUT_DIVIDER"

echo "cd to: -"
cd -