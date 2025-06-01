#!/bin/bash

COLOR_RED="\033[1;31m"
COLOR_GREEN="\033[1;32m"
COLOR_RESET="\033[0m"

RED_FAILED="${COLOR_RED}FAILED${COLOR_RESET}"
GREEN_PASSED="${COLOR_GREEN}PASSED${COLOR_RESET}"


RUN_AS_BRESTADM="sudo"
BREST_ADMIN="brestadm"

ATTRIBUTES=(
    "SAFE_DIRS" 
    "RESTRICTED_DIRS" 
    "LIMIT_MB" 
    "LIMIT_TRANSFER_BW" 
    "NO_DECOMPRESS" 
    "DATASTORE_CAPACITY_CHECK" 
    "STAGING_DIR" 
    "COMPATIBLE_SYS_DS" 
    "BRIDGE_LIST"
)






function print_test_result() {
    local TEST_NAME=$1
    local TEST_RESULT=$2

    local SEPARATOR="_"
    local TERMINAL_WIDTH=$(tput cols)

    local LENGHT_TEST_NAME=${#TEST_NAME}
    local LENGHT_TEST_RESULT="6"

    local TEXT_LENGHT=$((LENGHT_TEST_NAME + LENGHT_TEST_RESULT))
    
    if (( TEXT_LENGHT >= TERMINAL_WIDTH )); then
        echo -e "${TEST_NAME}_${TEST_RESULT}"
        return
    fi

    local SEPARATOR_LENGHT=$(( TERMINAL_WIDTH - TEXT_LENGHT ))
    local FILLER=$(printf '%*s' "${SEPARATOR_LENGHT}" '' | tr ' ' "${SEPARATOR}")

    echo -e "${TEST_NAME}${FILLER}${TEST_RESULT}"
}




function check_only_image_and_file_type() {
    local DATASTORE_TYPE=$1

    if [ "${DATASTORE_TYPE}" != "IMAGE" ] && [ "${DATASTORE_TYPE}" != "FILE" ]; then
        echo "Тест недоступен для хранилищ типа $DATASTORE_TYPE"
        exit 1
    fi
}



function check_storage_attributes_before_test() {
    local DATASTORE=$1
    shift
    local ATTRIBUTES=("$@")

    set -o pipefail
    for ATTRIBUTE in "${ATTRIBUTES[@]}"; do
        if ! onedatastore show "${DATASTORE}" | grep "${ATTRIBUTE}" > /dev/null; then
            echo "Атрибут хранилища ${DATASTORE} не установлен: ${ATTRIBUTE}"
            echo "Отмена выполнения теста"
            exit 1
        fi
    done
}



function host_state_code() {
    local HOST="$1"

    onehost show "$HOST" -x | xmlstarlet sel -t -v "/HOST/STATE"
}



function get_datastore_name_by_type() {
    local DATASTORE_TYPE=$1
    local DATASTORE_NAME_PREFIX=""
    local DATASTORE_NAME=""

    case "${DATASTORE_TYPE}" in
        "IMAGE")
            DATASTORE_NAME_PREFIX="image_"
            ;;
        "FILE")
            DATASTORE_NAME_PREFIX="file_"
            ;;
        "SYSTEM")
            DATASTORE_NAME_PREFIX="system_"
            ;;
        *)
            echo "Bad datastore type"
            exit 1
            ;;
    esac

    DATASTORE_NAME=$($RUN_AS_BRESTADM onedatastore list | grep "$DATASTORE_NAME_PREFIX" | awk '{print $2}')

    if [[ -z "${DATASTORE_NAME}" ]]; then
        echo "Хранилища для теста не найдено"
        exit 1
    else
        echo "${DATASTORE_NAME}"
    fi
}


