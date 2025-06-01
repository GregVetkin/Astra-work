#!/bin/bash
source "$(dirname "$0")/_common.sh"


TEST_FILE="$1"
TEST_FILE_PATH="$(dirname "$0")/tests/${TEST_FILE}.sh"
TEST_FUNCTION_NAME="$2"


if [[ ! -f "${TEST_FILE_PATH}" ]]; then
    echo "Скрипт ${TEST_FILE_PATH}.sh не найден в директории tests"
    exit 1
fi

shift; shift




while getopts ":t:" opt; do
    case $opt in
        t) DATASTORE_TYPE="${OPTARG}" ;;
    esac
done




source "${TEST_FILE_PATH}"


if $TEST_FUNCTION_NAME
then
    TEST_RESULT="${GREEN_PASSED}"
else 
    TEST_RESULT="${RED_FAILED}"
fi

print_test_result "${TEST_FUNCTION_NAME}" "${TEST_RESULT}"

