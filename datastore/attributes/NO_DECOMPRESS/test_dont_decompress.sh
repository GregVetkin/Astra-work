#!/bin/bash
#  Тест проверки корректного расчета образа
#  Необходимые атрибуты NO_DECOMPRESS="YES"

DATASTORE_TYPE=$1


case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        echo "Доступный тип: IMAGE"
        exit 2
        ;;
esac


RAW_SIZE_MB="2048"
DUMMY_FILE=$(mktemp -p /var/tmp)
DUMMY_TAR_GZ="${DUMMY_FILE}.tar.gz"

dd if=/dev/zero of=${DUMMY_FILE} bs=1MiB count=$RAW_SIZE_MB status=none 
chmod 777 ${DUMMY_FILE}
tar -czvf $DUMMY_TAR_GZ $DUMMY_FILE &>/dev/null
chmod 777 $DUMMY_TAR_GZ


IMAGE_ID=$(oneimage create -d $DATASTORE_ID --name "test_$(date +%s%N)" --path $DUMMY_TAR_GZ --type $IMAGE_TYPE | awk '{print $NF}')

while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]; do sleep 1; done

IMAGE_SIZE=$(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "/IMAGE/SIZE")


oneimage delete $IMAGE_ID
rm -f $DUMMY_FILE
rm -f $DUMMY_TAR_GZ


if [[ $IMAGE_SIZE -lt $RAW_SIZE_MB ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi