#!/bin/bash
#  Тест на проверку работы аттрибута ограничения емкости хранилища
#  Атрибуты: DATASTORE_CAPACITY_CHECK="YES"

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
        echo "Доступные типы: IMAGE FILE"
        exit 2
        ;;
esac

DATASTORE_TOTAL_MB=$(onedatastore show $DATASTORE_ID -x | xmlstarlet sel -t -v "//TOTAL_MB")
FILE_SIZE=$((DATASTORE_TOTAL_MB + 512))
DUMMY_FILE=$(mktemp -p /var/tmp)
dd if=/dev/zero of=${DUMMY_FILE} bs=1 count=0 seek=${FILE_SIZE}M status=none && chmod 777 ${DUMMY_FILE}


IMAGE_NAME="test_$(date +%s%N)"
RESULT_CODE=$(oneimage create --name $IMAGE_NAME -d $DATASTORE_ID --path $DUMMY_FILE --type $IMAGE_TYPE &>/dev/null; echo $?)
sleep 1
IMAGE_ID=$(oneimage list -x | xmlstarlet sel -t -v "//IMAGE[NAME='$IMAGE_NAME']/ID")
oneimage delete $IMAGE_ID
rm -f $DUMMY_FILE


if [[ $RESULT_CODE -eq 0 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi