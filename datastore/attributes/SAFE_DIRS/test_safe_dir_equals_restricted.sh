#!/bin/bash
#  Тест на корректную регистрацию образа при совпадении RESTRICTED_DIRS и SAFE_DIRS
#  Необходимые атрибуты SAFE_DIRS="/var/tmp", RESTRICTED_DIRS="/var/tmp"

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


DUMMY_FILE=$(mktemp -p /var/tmp)
dd if=/dev/urandom of=${DUMMY_FILE} bs=1MiB count=10 status=none && chmod 777 ${DUMMY_FILE}


IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE --path $DUMMY_FILE --type $IMAGE_TYPE | awk '{print $NF}')
sleep 5
IMAGE_STATE_CODE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/STATE")

rm -f $DUMMY_FILE


if [[ $IMAGE_STATE_CODE -eq 1 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi