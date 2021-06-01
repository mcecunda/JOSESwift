printUsage() {
    echo "Script for archiving frameworks and assembling xcframeworks."
    echo "Script usage:"
    echo "sh <path_to_script> <options>"
    echo ""
    echo "Options: "
    echo "  -m <value>     optional switch for building catalyst"
    echo "  -p <value>     path to output directory (defaults to './')"
    echo "  -f <value>     framework to build & assemble"
    echo ""
}

printInputValidationFailure() {
    echo "Invalid usage."
    echo "Required input missing - $1. Please pass scheme (-$2) argument"
    echo ""
}

remove_old_archives() 
{
    SCHEME_TO_REMOVE=$1

    if [ -z ${SCHEME_TO_REMOVE} ]; then 
        echo "Illegal arguments for 'remove_old_archives'"
        return 2
    fi

    echo "Removing old archives: ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}"

    rm -rf ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}-iphoneos.xcarchive
    rm -rf ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}-iphonesimulator.xcarchive
    rm -rf ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}-catalyst.xcarchive
}

remove_old_xcframework() {
    SCHEME_TO_REMOVE=$1

    if [ -z ${SCHEME_TO_REMOVE} ]; then 
        echo "Illegal arguments for 'remove_old_xcframework'"
        return 2
    fi

    echo "Removing old xcframework: ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}"

    rm -rf ${ARCHIVE_PATH}/${SCHEME_TO_REMOVE}.xcframework
}

build_scheme() 
{
    SCHEME_TO_BUILD=$1
    VERBOSE_OUTPUT_LOGS=false

    if [ -z ${SCHEME_TO_BUILD} ]; then 
        echo "Illegal arguments for 'build_scheme'"
        return 2
    fi

    echo "Building ${SCHEME_TO_BUILD} to $ARCHIVE_PATH"

    if [ "$VERBOSE_OUTPUT_LOGS" = true ]; then
        GREP_FILTER=''
    else
        GREP_FILTER='^(/.+:[0-9+:[0-9]+:.(error|warning):|fatal|===|\*\*.*\*\*)'
    fi

    echo " -> filter: $GREP_FILTER"

    COMMON_SETUP=" -scheme ${SCHEME_TO_BUILD} SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES "

    echo " -> Building iOS (${SCHEME_TO_BUILD})"
    xcodebuild archive \
        $COMMON_SETUP \
        -archivePath $ARCHIVE_PATH/${SCHEME_TO_BUILD}-iphoneos.xcarchive \
        -destination "generic/platform=iOS" \
        2>&1 | egrep "$GREP_FILTER"

    echo " -> Building Simulator (${SCHEME_TO_BUILD})"
    xcodebuild archive \
        $COMMON_SETUP \
        -archivePath $ARCHIVE_PATH/${SCHEME_TO_BUILD}-iphonesimulator.xcarchive \
        -destination "generic/platform=iOS Simulator" \
        2>&1 | egrep "$GREP_FILTER"
    
    if [ $BUILD_CATALYST = true ]; then
        echo " -> Building catalyst (${SCHEME_TO_BUILD})"
        xcodebuild archive \
            $COMMON_SETUP \
            -archivePath $ARCHIVE_PATH/${SCHEME_TO_BUILD}-catalyst.xcarchive \
            -destination 'platform=macOS,arch=x86_64,variant=Mac Catalyst' \
            -sdk iphoneos \
            2>&1 | egrep "$GREP_FILTER"
    fi
}

assemble_xcframework() 
{
    SCHEME_TO_ASSEMBLE=$1
    SCHEME_TO_READ_FRAMEWORKS=$2

    if [ -z $SCHEME_TO_ASSEMBLE ]; then 
        echo "Illegal arguments for 'assemble_xcframework'"
        return 2
    fi

    if [ -z $SCHEME_TO_READ_FRAMEWORKS ]; then 
        echo "Illegal arguments for 'assemble_xcframework'"
        return 2
    fi

    echo "Assembling ${SCHEME_TO_ASSEMBLE} to $ARCHIVE_PATH"

    if [ $BUILD_CATALYST = true ]; then
        xcodebuild -create-xcframework \
            -framework $ARCHIVE_PATH/${SCHEME_TO_READ_FRAMEWORKS}-iphonesimulator.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${SCHEME_TO_READ_FRAMEWORKS}-iphoneos.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${SCHEME_TO_READ_FRAMEWORKS}-catalyst.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -output $ARCHIVE_PATH/$SCHEME_TO_ASSEMBLE.xcframework
    else
        xcodebuild -create-xcframework \
            -framework $ARCHIVE_PATH/${SCHEME_TO_READ_FRAMEWORKS}-iphonesimulator.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${SCHEME_TO_READ_FRAMEWORKS}-iphoneos.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -output $ARCHIVE_PATH/${SCHEME_TO_ASSEMBLE}.xcframework
    fi
}

set -euo pipefail

ARCHIVE_PATH="./"
BUILD_CATALYST=false
ITEM=""

while getopts mp:f: flag
do
    case "${flag}" in
        m) BUILD_CATALYST=true;;
        p) ARCHIVE_PATH=${OPTARG};;
        f) ITEM=${OPTARG};;
    esac
done

if [ -z ${ITEM} ]; then 
    printInputValidationFailure "framework" "f"
    printUsage 
    exit 2
fi

echo "\n"
echo "Build Catalyst: $BUILD_CATALYST";

remove_old_archives $ITEM
build_scheme $ITEM

ALL_FRAMEWORKS=""
for dependency in $(ls $ARCHIVE_PATH/${ITEM}-iphonesimulator.xcarchive/Products/Library/Frameworks/)
do
    DEPENDENCY_WITHOUT_SUFFIX=$(echo "$dependency" | cut -f 1 -d ".")
    ALL_FRAMEWORKS="${ALL_FRAMEWORKS} ${DEPENDENCY_WITHOUT_SUFFIX}"
done

echo "Archiving framworks:\n${ALL_FRAMEWORKS}"
for FRAMEWORK in $ALL_FRAMEWORKS
do
    remove_old_xcframework $ITEM
    assemble_xcframework $FRAMEWORK $ITEM
done

remove_old_archives $ITEM
