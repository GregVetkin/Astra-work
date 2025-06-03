#  Тест на проверку работы аттрибута при нахождении доступного хранилище в списке в конце
#  Атрибут: COMPATIBLE_SYS_DS="42, {system_ds_id}"

DATASTORE_TYPE=$1

case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        IMAGE_DATASTORE_ID=$(   onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        SYSTEM_DATASTORE_ID=$(  onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'system_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        echo "ДоступныЙ тип: IMAGE"
        exit 2
        ;;
esac



IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d ${IMAGE_DATASTORE_ID} --type $IMAGE_TYPE --size 10 | awk '{print $NF}')
while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]; do sleep 1; done
VM_ID=$(onevm create --name "test_$(date +%s%N)" --memory 128 --cpu 1 --disk $IMAGE_ID | awk '{print $NF}')

sleep 20

VM_DS_ID=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/HISTORY_RECORDS/HISTORY[last()]/DS_ID")
VM_STATE=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE")


onevm terminate --hard $VM_ID
while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE") -ne 6 ]]; do sleep 1; done
oneimage delete $IMAGE_ID


if [[ $VM_STATE -eq 8 ]] && [[ $VM_DS_ID -eq $SYSTEM_DATASTORE_ID ]]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi