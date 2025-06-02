#!/bin/bash
#  Тест на проверку работы аттрибута ограничения емкости хранилища
#  Атрибуты: DATASTORE_CAPACITY_CHECK="NO"

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



DUMMY_FILE=$(mktemp -p /var/tmp)
dd if=/dev/zero of=${DUMMY_FILE} bs=1 count=0 seek=1T status=none && chmod 777 ${DUMMY_FILE}

RESULT_CODE=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE_ID --path $DUMMY_FILE --type $IMAGE_TYPE; echo $?)
sleep 1

rm -f $DUMMY_FILE


if [[ $RESULT_CODE -ne 0 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi