printUsage() {
    echo "Script for archiving frameworks and assembling xcframeworks."
    echo "Script usage:"
    echo "sh <path_to_script> <options>"
    echo ""
    echo "Options: "
    echo "  -m             optional switch for building catalyst"
    echo "  -p <value>     path to output directory (defaults to './')"
    echo "  -d <value>     (optional) path to output directory for dSYM file."
    echo "                 Will be evaluated as subpath of value in '-p' option."
    echo "                 If not set, dSYM files won't be extracted."
    echo "  -f <value>     framework to build & assemble. Pass value of scheme that should be built."
    echo "  -r <value>     (optional) framework product name. Use this option,"
    echo "                 if target's product name is different than scheme name passed to -f option"
    echo "  -n             remove nested 'Frameworks' directories from all xcframeworks in directory pointed by -p"
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
    XCARCHIVE_TO_ASSEMBLE=$2

    if [ -z $SCHEME_TO_ASSEMBLE ]; then 
        echo "Illegal arguments for 'assemble_xcframework'"
        return 2
    fi

    if [ -z $XCARCHIVE_TO_ASSEMBLE ]; then 
        echo "Illegal arguments for 'assemble_xcframework'"
        return 2
    fi

    echo "Assembling ${SCHEME_TO_ASSEMBLE} to $ARCHIVE_PATH"

    if [ $BUILD_CATALYST = true ]; then
        xcodebuild -create-xcframework \
            -framework $ARCHIVE_PATH/${XCARCHIVE_TO_ASSEMBLE}-iphonesimulator.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${XCARCHIVE_TO_ASSEMBLE}-iphoneos.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${XCARCHIVE_TO_ASSEMBLE}-catalyst.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -output $ARCHIVE_PATH/$SCHEME_TO_ASSEMBLE.xcframework
    else
        xcodebuild -create-xcframework \
            -framework $ARCHIVE_PATH/${XCARCHIVE_TO_ASSEMBLE}-iphonesimulator.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -framework $ARCHIVE_PATH/${XCARCHIVE_TO_ASSEMBLE}-iphoneos.xcarchive/Products/Library/Frameworks/${SCHEME_TO_ASSEMBLE}.framework \
            -output $ARCHIVE_PATH/${SCHEME_TO_ASSEMBLE}.xcframework
    fi
}

remove_old_dsym_files()
{
    SCHEME_TO_DELETE=$1
    DELETE_FROM_DIR=$2

    if [ -z ${SCHEME_TO_DELETE} ]; then
        echo "Illegal arguments for 'remove_old_dsym_files' - SCHEME_TO_DELETE"
        return 2
    fi

    if [ -z ${DELETE_FROM_DIR} ]; then
        echo "Illegal arguments for 'remove_old_dsym_files' - DELETE_FROM_DIR"
        return 2
    fi

    echo "Removing old dSYM file zips: "
    DSYM_DIR="$ARCHIVE_PATH/$DELETE_FROM_DIR"

    rm -f "$DSYM_DIR/${SCHEME_TO_DELETE}-iphonesimulator.framework.dSYM.zip"
    rm -f "$DSYM_DIR/${SCHEME_TO_DELETE}-iphoneos.framework.dSYM.zip"
    rm -f "$DSYM_DIR/${SCHEME_TO_DELETE}-catalyst.framework.dSYM.zip"
}

extract_dsym_files() 
{
    PRODUCT_NAME_TO_EXTRACT=$1
    XCARCHIVE_TO_EXTRACT=$2
    EXTRACT_TO_DIR=$3

    if [ -z ${XCARCHIVE_TO_EXTRACT} ]; then 
        echo "Illegal arguments for 'extract_dsym_files' - XCARCHIVE_TO_EXTRACT"
        return 2
    fi


    if [ -z ${PRODUCT_NAME_TO_EXTRACT} ]; then
        echo "Illegal arguments for 'extract_dsym_files' - PRODUCT_NAME_TO_EXTRACT"
        return 2
    fi

    if [ -z ${EXTRACT_TO_DIR} ]; then
        echo "Illegal arguments for 'extract_dsym_files' - EXTRACT_TO_DIR"
        return 2
    fi

    echo "Extracting dSYM files"

    SOURCE_DSYM_FILE="${PRODUCT_NAME_TO_EXTRACT}.framework.dSYM"
    DSYM_DIR="$ARCHIVE_PATH/$EXTRACT_TO_DIR"
#    BCSYM_DIR="$ARCHIVE_PATH/_BCSymbolMaps"

    DESTINATION_SIMULATOR_DSYM_FILE="${PRODUCT_NAME_TO_EXTRACT}-iphonesimulator.framework.dSYM.zip"
    DESTINATION_IPHONE_DSYM_FILE="${PRODUCT_NAME_TO_EXTRACT}-iphoneos.framework.dSYM.zip"
    DESTINATION_MACOS_DSYM_FILE="${PRODUCT_NAME_TO_EXTRACT}-catalyst.framework.dSYM.zip"

    if [ ! -d "$DSYM_DIR" ]; then
        mkdir "$DSYM_DIR"
    fi

    echo "Moving ${SOURCE_DSYM_FILE} zips to $DSYM_DIR"

    echo "Compressing $SOURCE_DSYM_FILE to $DESTINATION_SIMULATOR_DSYM_FILE"
    pushd "$ARCHIVE_PATH/${XCARCHIVE_TO_EXTRACT}-iphonesimulator.xcarchive/dSYMs"
    zip -db -dc "$OLDPWD/$DSYM_DIR/$DESTINATION_SIMULATOR_DSYM_FILE" -r "${SOURCE_DSYM_FILE}"
    popd

    echo "Compressing $SOURCE_DSYM_FILE to $DESTINATION_IPHONE_DSYM_FILE"
    pushd "$ARCHIVE_PATH/${XCARCHIVE_TO_EXTRACT}-iphoneos.xcarchive/dSYMs"
    zip -db -dc "$OLDPWD/$DSYM_DIR/$DESTINATION_IPHONE_DSYM_FILE" -r "${SOURCE_DSYM_FILE}"
    popd

    if [ $BUILD_CATALYST = true ]; then
        echo "Compressing $SOURCE_DSYM_FILE to $DESTINATION_MACOS_DSYM_FILE"
        pushd "$ARCHIVE_PATH/${XCARCHIVE_TO_EXTRACT}-catalyst.xcarchive/dSYMs"
        zip -db -dc "$OLDPWD/$DSYM_DIR/$DESTINATION_MACOS_DSYM_FILE" -r "${SOURCE_DSYM_FILE}"
        popd
    fi
}

remove_nested_frameworks()
{
    echo "Removing nested frameworks"

    # globbing is feature of shell that is doing wildcard expansion
    shopt -s nullglob
    NESTED_FRAMEWORK_DIRS=(${ARCHIVE_PATH}/*.xcframework/{ios,macos,tvos,watchos}-*/*.framework/Frameworks)
    shopt -u nullglob

    if ! [[ -z "${NESTED_FRAMEWORK_DIRS+x}" ]]; then 
        for FILE in "${NESTED_FRAMEWORK_DIRS[@]}"
        do 
            echo "$FILE containing:"
            ls "$FILE"
            rm -rf "$FILE"
        done    
    fi
}

gather_processed_frameworks()
{
    SCHEME_TO_CHECK_FOR_DEPENENCIES=$1

    if [ -z ${SCHEME_TO_CHECK_FOR_DEPENENCIES} ]; then
        echo "Illegal arguments for 'gather_processed_frameworks'"
        return 2
    fi

    for dependency in $(ls $ARCHIVE_PATH/${SCHEME_TO_CHECK_FOR_DEPENENCIES}-iphonesimulator.xcarchive/Products/Library/Frameworks/)
    do
      DEPENDENCY_WITHOUT_SUFFIX=$(echo "$dependency" | cut -f 1 -d ".")
      ALL_FRAMEWORKS="${ALL_FRAMEWORKS} ${DEPENDENCY_WITHOUT_SUFFIX}"
    done
}

set -euo pipefail

ARCHIVE_PATH="./"
BUILD_CATALYST=false
ITEM=""
ITEM_PRODUCT_NAME=""
REMOVE_NESTED_FRAMEWORKS=false
DEBUG_SYMBOLS_PATH=""

while getopts mp:f:nd:r: flag
do
    case "${flag}" in
        m) BUILD_CATALYST=true;;
        p) ARCHIVE_PATH=${OPTARG};;
        f) ITEM=${OPTARG};;
        n) REMOVE_NESTED_FRAMEWORKS=true;;
        d) DEBUG_SYMBOLS_PATH=${OPTARG};;
        r) ITEM_PRODUCT_NAME=${OPTARG};;
    esac
done

if [ -z ${ITEM} ]; then 
    printInputValidationFailure "framework" "f"
    printUsage 
    exit 2
fi

if [ -z ${ITEM_PRODUCT_NAME} ]; then 
    ITEM_PRODUCT_NAME=$ITEM
fi

echo "\n"
echo "Build Catalyst: $BUILD_CATALYST";

remove_old_archives $ITEM
build_scheme $ITEM

FRAMEWORK=$ITEM

# SAVED FOR POTENTIAL LATER USAGE

# This block of command would gather all dependencies and cycle trough them,
# but xcodebuild command is not building dependencies properly so we can't use it for now

#ALL_FRAMEWORKS=""
#gather_processed_frameworks $ITEM
#echo "Archiving frameworks:\n${ALL_FRAMEWORKS}"
#for FRAMEWORK in $ALL_FRAMEWORKS
#do
    remove_old_xcframework $ITEM_PRODUCT_NAME
    assemble_xcframework $ITEM_PRODUCT_NAME $FRAMEWORK

    if ! [ -z ${DEBUG_SYMBOLS_PATH} ]; then
      remove_old_dsym_files $FRAMEWORK $DEBUG_SYMBOLS_PATH
      extract_dsym_files $ITEM_PRODUCT_NAME $FRAMEWORK $DEBUG_SYMBOLS_PATH
    fi
#done

# SAVED FOR POTENTIAL LATER USAGE

remove_old_archives $ITEM

if [ $REMOVE_NESTED_FRAMEWORKS = true ]; then
    remove_nested_frameworks
fi
