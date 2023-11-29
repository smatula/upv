#!/bin/bash
set -o pipefail

# Function to display usage/help
usage () {
    echo "Usage: upv.sh [options] -o ver -n ver [-f file | jobnames]

Update lp interop scenarios in openshift-ci to run on new platform version.

NOTE: Must be executed from openshift-ci's top level directory 'release'.

Example: upv.sh -o 4.15 -n 4.16 periodic-ci-skupperproject-skupper-openshift-smoke-test-image-main-service-interconnect-ocp4.15-lp-interop-rhsi-interop-aws

Options:
    Required:
        -o|--old_ver ver     - Old platform version.
        -n|--new_ver ver     - New platform version.
    Optional:
        -p|--platform str    - Platform, str is ocp or hypershift. Default is ocp.
        -t|--lp_tag str      - Overide default tag, -lp-interop for ocp and -lp-rosa-hypershift for hypershift
                               str is new tag. Searches for tag in config file name or its contents.
        -i|--text            - Flag input file format is text. Single job name per line.
        -z|--z_stream        - [Not implemented] Flag indicating to update old version config file to be z-stream, stream: stable
        -f|--input_file file - Input file containing list of jobs to update. JSON format.
                               See vault trigger file.
    jobnames                 - Scenario's job name/s seperated by space.
    "
}

# Initialize
DAY=$( date +%-d )
MONTH=$( date +%-m )
JOBS_ARRAY=()
JOBS=""

# Default PLATFORM
PLATFORM="ocp"

# Default LP_TAG
LP_TAG="\-lp\-interop"

# default Z_STREAM
Z_STREAM="false"

# Default FILE_FMT
FILE_FMT="json"

POSITIONAL_ARGS=()

# Process command line
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--platform)
      PLATFORM="$2"
      shift # past argument
      shift # past value
      ;;
    -t|--lp_tag)
      LP_TAG="$2"
      shift # past argument
      shift # past value
      ;;
    -o|--old_ver)
      OLD_VER="$2"
      shift # past argument
      shift # past value
      ;;
    -n|--new_ver)
      NEW_VER="$2"
      shift # past argument
      shift # past value
      ;;
    -f|--input_file)
      INPUT_FILE="$2"
      shift # past argument
      shift # past value
      ;;
    -i|--text)
      FILE_FMT="txt"
      shift # past argument
      ;;
    -z|--z_stream)
      Z_STREAM="false"
      shift # past argument
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*|--*)
      echo "Unknown option $1"
      usage
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      JOBS=`echo $JOBS;printf %"s\n" ${1}`
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [[ $PLATFORM == "hypershift" ]]
then
     LP_TAG="\-lp\-rosa\-hypershift"
fi

# INPUT VALUES
echo "MONTH        = ${MONTH}"
echo "DAY          = ${DAY}"
echo "OLD VERSION  = ${OLD_VER}"
echo "NEW VERSION  = ${NEW_VER}"
echo "INPUT FILE   = ${INPUT_FILE}"
echo "JOB NAME     = ${1}"
echo "PLATFORM     = ${PLATFORM}"
echo "LP_TAG       = ${LP_TAG}"
echo "PWD          = " `pwd`

# Check that OLD_VER and NEW_VER platform versions supplied.
if [ -z "$OLD_VER" ] || [ -z "$NEW_VER" ]
then
    echo ""
    echo "ERROR: OLD and NEW Platform versions must be supplied"
    echo ""
    usage
    exit 1
fi

# Check PLATFORM set to ocp or hypershift
if [[ $PLATFORM != "ocp" && $PLATFORM != "hypershift" ]]
then
    echo ""
    echo "ERROR: PLATFORM must be set to either 'ocp' or 'hypershift'"
    echo ""
    usage
    exit 1
fi

# Check current directory is correct - Should be in release directory
DIR=${PWD/*\//}
if [[ $DIR != "release" ]]
then
    echo ""
    echo "ERROR: Must run from openshift-ci's top level directory: release"
    echo ""
    usage
    exit 1
fi

# Set JOBS if input file supplied - Expected to be in format of vault trigger file
if [ ! -z "$INPUT_FILE" ]
then
    # Check file exists
    if ! test -f $INPUT_FILE
    then
        echo ""
        echo "ERROR: Input file ${INPUT_FILE} dost not exist"
        echo ""
        useage
        exit 1
    fi

    if [[ $FILE_FMT != "json" ]]
    then
        # Get list of jobs from text file, remove blank lines
        JOBS=`grep '[^[:blank:]]' < "$INPUT_FILE"`
    else
        # Get list of jobs from json file, Should be in format of vault trigger file

        # Check Valid json
        if JOBS=`jq -re '.[] | select(.active == true) | .job_name' "$INPUT_FILE"`
        then
            echo "Parsed JSON file successfully."
        else
            echo "ERROR: Failed to parse JSON file, or got false/null"
            echo ""
            usage
            exit 1
        fi
    fi
fi

# Check we have JOBS to process
if [ -z "$JOBS" ]
then
    echo ""
    echo "ERROR: No job name or input file given"
    echo ""
    usage
    exit 1
fi

# For each ENTRY (JOB) perform the following
while IFS= read -r ENTRY; do
    E_OLD_VER=""

    # ENTRY single job name
    echo ""
    echo "ENTRY        = ${ENTRY}"

    # JOB Location and file of ENTRY (job)
    JOB=`grep -Rl --exclude='.*' $ENTRY ./ci-operator/jobs`
    if [ -z "$JOB" ]
    then
        echo "WARNING: JOB: ${ENTRY} does not exist"
        continue
    fi
    echo "JOB          = ${JOB}"

    # Set JOB_PATH and CONFIG_PATH
    # JOB_PATH path of JOB's file
    # CONFIG_PATH path of JOB's config file
    JOB_PATH="$(dirname "${JOB}")"
    CONFIG_PATH=${JOB_PATH/jobs/config}

    echo "JOB PATH     = ${JOB_PATH}"

    # Set NEW_JOB name using FMT1 (4.12) - ENTRY name with new version
    NEW_JOB=${ENTRY//${OLD_VER}/${NEW_VER}}
    echo "NEW JOB      = ${NEW_JOB}"

    # If same (Name not changed) set NEW_JOB using FMT2 (4-12)
    if test "$ENTRY" = "$NEW_JOB"
    then
        E_OLD_VER=${OLD_VER/./-}
        E_NEW_VER=${NEW_VER/./-}

        echo "FMT2 OLD VER  = ${E_OLD_VER}"
        echo "FMT2 NEW VER  = ${E_NEW_VER}"
        NEW_JOB=${ENTRY//${E_OLD_VER}/${E_NEW_VER}}
    fi

    # If same (Name not changed) set NEW_JOB using FMT3 (412)
    if test "$ENTRY" = "$NEW_JOB"
    then
        E_OLD_VER=${OLD_VER/./""}
        E_NEW_VER=${NEW_VER/./""}

        echo "FMT3 OLD VER  = ${E_OLD_VER}"
        echo "FMT3 NEW VER  = ${E_NEW_VER}"
        NEW_JOB=${ENTRY//${E_OLD_VER}/${E_NEW_VER}}
    fi

    echo "CONFIG PATH  = ${CONFIG_PATH}"

    # Find CONFIG_FILE in CONFIG_PATH Searching for files with LP_TAG, PLATFORM and OLD_VER
    CONFIG_FILE=`ls $CONFIG_PATH | grep -i $LP_TAG | grep -i $PLATFORM | grep -i $OLD_VER || :`

    # If more than 1 config found get PROD from scenario label
    # If ENTRY contains PROD then we have our config 
    NUM_CONFIGS=`wc -w <<< "$CONFIG_FILE"`
    if [[ $NUM_CONFIGS -gt 1 ]]
    then
       echo "More than one"
       CONFIGS=($CONFIG_FILE)
       CONFIG_FILE=""
       for i in "${CONFIGS[@]}"
       do
           PROD=`sed -n -e 's/^.*scenario //p' $CONFIG_PATH/$i`
           if [ -z "$PROD" ]
           then
               PROD=`sed "s/__/&\n/;s/.*\n//;s/-$PLATFORM/\n&/;s/\n.*//" <<< "$i"`
           fi

           echo "PROD         = ${PROD}"
           if [[ $ENTRY == *"$PROD"* ]]
           then
               CONFIG_FILE=$i
               break
           fi
           # do whatever on $i
       done
    fi 

    # No CONFIG_FILE found Get all configs with OLD_VER FMT 4*12
    # Select only ones that contain LP_TAG
    if test "$CONFIG_FILE" = ""
    then
        E_OLD_VER=${OLD_VER/./*}
        CONFIG_FILE=`grep -l $LP_TAG $(find $CONFIG_PATH -name *$E_OLD_VER* )`
        CONFIG_FILE="$(basename "${CONFIG_FILE}")"
    fi

    # Set NEW_CONFIG_FILE FMT1 (4.12)
    NEW_CONFIG_FILE=${CONFIG_FILE//${OLD_VER}/${NEW_VER}}

    # Same then use FMT2 (4-12)
    if test "$CONFIG_FILE" = "$NEW_CONFIG_FILE"
    then
        E_OLD_VER=${OLD_VER/./-}
        E_NEW_VER=${NEW_VER/./-}

        echo "FMT2 OLD VER  = ${E_OLD_VER}"
        echo "FMT2 NEW VER  = ${E_NEW_VER}"
        NEW_CONFIG_FILE=${CONFIG_FILE//${E_OLD_VER}/${E_NEW_VER}}
    fi

    # Same then use FMT3 (412)
    if test "$CONFIG_FILE" = "$NEW_CONFIG_FILE"
    then
        E_OLD_VER=${OLD_VER/./""}
        E_NEW_VER=${NEW_VER/./""}

        echo "FMT3 OLD VER  = ${E_OLD_VER}"
        echo "FMT3 NEW VER  = ${E_NEW_VER}"
        NEW_CONFIG_FILE=${CONFIG_FILE//${E_OLD_VER}/${E_NEW_VER}}
    fi

    # Print old and new CONFIG_FILE
    echo "CONFIG FILE  = ${CONFIG_FILE}"
    echo "NEW CONFIG FILE = ${NEW_CONFIG_FILE}"

    # Check if new config file exists and give warning 
    if test -f $CONFIG_PATH/$NEW_CONFIG_FILE
    then
        echo "WARNING: ${CONFIG_PATH}/${NEW_CONFIG_FILE}. File exists. Will be overwritten and updated"
    fi

    # Copy config from old to new
    cp $CONFIG_PATH/$CONFIG_FILE $CONFIG_PATH/$NEW_CONFIG_FILE

    # Set version to be sed correct
    SED_OLD_VER=${OLD_VER/./\\.}
    SED_NEW_VER=${NEW_VER/./\\.}

    # Update version in config file
    sed -i "s/$SED_OLD_VER/$SED_NEW_VER/g" $CONFIG_PATH/$NEW_CONFIG_FILE

    # If alternate format used also perform update with alternate fmt also
    if [[ ! -z "$E_OLD_VER" ]]
    then
        # Set version to be sed correct
        SED_E_OLD_VER=${E_OLD_VER/./\\.}
        SED_E_NEW_VER=${E_NEW_VER/./\\.}
        sed -i "s/$SED_E_OLD_VER/$SED_E_NEW_VER/g" $CONFIG_PATH/$NEW_CONFIG_FILE
    fi

    # Handle any special processing for scnearios here....
    # Scenarios With Special processing
    if [[ $CONFIG_PATH == *"service-binding-operator"* ]]; then
       NEW_TAG=--tags=~@disable-openshift-$NEW_VER+
       ADD_TAG=--tags=~@disable-openshift-$OLD_VER+
       GREP_TAG="\\"
       GREP_TAG+=$NEW_TAG
       TAG_COUNT=`grep -o $GREP_TAG $CONFIG_PATH/$NEW_CONFIG_FILE | wc -l`
       if  [[ $TAG_COUNT -gt 1 ]]
       then
           sed -i "s/$NEW_TAG/$ADD_TAG/" $CONFIG_PATH/$NEW_CONFIG_FILE
       else
           sed -i "s/$NEW_TAG/$ADD_TAG $NEW_TAG/" $CONFIG_PATH/$NEW_CONFIG_FILE
       fi
    fi

    # Find cron and update
    CRON=`grep -i cron: $CONFIG_PATH/$NEW_CONFIG_FILE`
    CRON="${CRON//\*}"
    while IFS= read -r i; do
        NEW_CRON="${i%:*}: 0 6 $((DAY-2)) $MONTH "
        echo "CRON         = ${i}"
        echo "NEW CRON     = ${NEW_CRON}"

        sed -i "s/$i/$NEW_CRON/g" $CONFIG_PATH/$NEW_CONFIG_FILE
    done < <(echo "$CRON")

    # Update old version to be z-stream stream: stable
    if [[ $Z_STREAM  == "true" ]]
    then
       sed -i "s/stream: nightly/stream: stable/g" $CONFIG_PATH/$CONFIG_FILE
       git add $CONFIG_PATH/$CONFIG_FILE
    fi

    # Git add new config file
    git add $CONFIG_PATH/$NEW_CONFIG_FILE

    JOBS_ARRAY+=("${ENTRY}")
    JOBS_ARRAY+=("${JOB}")
    JOBS_ARRAY+=("${NEW_JOB}")
    echo ""
    echo "--------------------------------------------------------------------------------"

done < <(echo "$JOBS")

# Completed updating all config files perform a make update
make update

# Update all JOB files new entry with NOTIFICATION
for (( i=0; i<${#JOBS_ARRAY[@]} ; i+=3 )) ; do
    OLD_JOBNAME="${JOBS_ARRAY[i]}"
    NEW_JOBNAME="${JOBS_ARRAY[i+2]}"
    OLD_JOB="${JOBS_ARRAY[i+1]}"
    NEW_JOB=$OLD_JOB

    # FMT 1
    TEST_JOB=${OLD_JOB//${OLD_VER}/${NEW_VER}}
    if test -f $TEST_JOB
    then
        NEW_JOB=$TEST_JOB
        PRESUBMITS=${NEW_JOB/periodics/presubmits}
    else
        # FMT 2
        T_OLD_VER=${OLD_VER/./-}
        T_NEW_VER=${NEW_VER/./-}
        TEST_JOB=${OLD_JOB//${T_OLD_VER}/${T_NEW_VER}}
        if test -f $TEST_JOB
        then
            NEW_JOB=$TEST_JOB
            PRESUBMITS=${NEW_JOB/periodics/presubmits}
        else
            # FMT 3
            T_OLD_VER=${OLD_VER/./""}
            T_NEW_VER=${NEW_VER/./""}
            TEST_JOB=${OLD_JOB//${T_OLD_VER}/${T_NEW_VER}}
            if test -f $TEST_JOB
            then
                NEW_JOB=$TEST_JOB
                PRESUBMITS=${NEW_JOB/periodics/presubmits}
            fi
        fi
    fi

    # Get Notification setting from old job    
    NOTIFICATION=`sed -n "/${OLD_JOBNAME}/,/spec:/{/${OLD_JOBNANE}/b;/spec/b;p}" $OLD_JOB`
    echo "NEW JOB = ${NEW_JOB}"
    echo "NOTIFICATION = ${NOTIFICATION}"
    echo ""

    # Save notification to tmp file
    echo "$NOTIFICATION" > tmp_slack.txt

    # Get Notification setting from new job
    CHECK_NOTIFICATION=`sed -n "/${NEW_JOBNAME}/,/spec:/{/${NEW_JOBNAME}/b;/spec/b;p}" $NEW_JOB`

    # If no Notification then add to new job
    if [ -z "$CHECK_NOTIFICATION" ]
    then
        sed -i "/${NEW_JOBNAME}/r tmp_slack.txt" $NEW_JOB
    fi

    # Cleanup/delete tmp file
    rm tmp_slack.txt

    # git add new job
    git add $NEW_JOB

    # git add persubmits job file if exist
    if test -f $PRESUBMITS
    then
        git add $PRESUBMITS
    fi

    # Update old files to be z-stream if flag set
    if [[ $Z_STREAM == "true" ]]
    then
        git add $OLD_JOB

        OLD_PRESUBMITS=${OLD_JOB/periodics/presubmits}

        if test -f $OLD_PRESUBMITS
        then
            git add $OLD_PRESUBMITS
        fi
    fi
done


