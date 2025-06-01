#!/bin/bash
#  Тест работы атрибута при списке узлов, где первый недоступный, а второй - рабочий
#  Необходимые атрибуты BRIDGE_LIST="badhost bufn1.brest.local"

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


IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d $DATASTORE_ID --type $IMAGE_TYPE --path $DUMMY_FILE | awk '{print $NF}')

while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -eq 4 ]]; do sleep 1; done

IMAGE_STATE_CODE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE")



oneimage delete $IMAGE_ID
rm -f $DUMMY_FILE



if [[ $IMAGE_STATE_CODE -eq 1 ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi