#!/bin/bash
# Проверка при загрузке локально
# Атрибуты: BRIDGE_LIST="bufn1.brest.local" STAGING_DIR="/testdir" SAFE_DIRS="/var/tmp"

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





STAGE_DIRECTORY="/testdir"
TEST_FILE_PATH=$(mktemp)
IMAGE_PATH=$(mktemp -p /var/tmp)
dd if=/dev/urandom of=${IMAGE_PATH} bs=1MiB count=2048 status=none && chmod 777 ${IMAGE_PATH}

mkdir -m 777 ${STAGE_DIRECTORY}


IMAGE_ID=$(oneimage create -d $DATASTORE_ID --name "test_$(date +%s%N)" --path $IMAGE_PATH --type "$IMAGE_TYPE" | awk '{print $NF}')


while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]
do 
    ls $STAGE_DIRECTORY >> $TEST_FILE_PATH
    sleep 1 
done


oneimage delete $IMAGE_ID
rm -fr $STAGE_DIRECTORY


if [ -s $TEST_FILE_PATH ] then 
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi