#!/bin/bash
#  Тест на работу атрибута при списке директорий через пробел
#  Необходимые атрибуты SAFE_DIRS="/some /tmp/testdir /not/existed"

DATASTORE_TYPE=$1


case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        ;;
    FILE)
        IMAGE_TYPE="CONTEXT"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'file_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        exit 2
        ;;
esac


SAFE_DIRECTORY="/tmp/testdir"
mkdir -m 777 $SAFE_DIRECTORY
DUMMY_FILE=$(mktemp -p $SAFE_DIRECTORY)
dd if=/dev/urandom of=${DUMMY_FILE} bs=1MiB count=10 status=none && chmod 777 ${DUMMY_FILE}


IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE_ID --path $DUMMY_FILE --type $IMAGE_TYPE | awk '{print $NF}')
sleep 5
IMAGE_STATE_CODE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/STATE")

oneimage delete $IMAGE_ID
rm -rf $SAFE_DIRECTORY


if [[ $IMAGE_STATE_CODE -eq 1 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi