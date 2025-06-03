#  Тест на проверку корректности работы атрибута при значении в виде списка id хранилищ
#  Атрибут: COMPATIBLE_SYS_DS="42"

DATASTORE_TYPE=$1

case ${DATASTORE_TYPE} in
    IMAGE)
        IMAGE_TYPE="OS"
        DATASTORE_ID=$(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE[starts-with(NAME, 'image_')]/ID")
        ;;
    *)
        echo "Данный тип [${DATASTORE_TYPE}] не поддерживается тестом"
        echo "Доступные типы: IMAGE"
        exit 2
        ;;
esac





IMAGE_ID=$(oneimage create --name "test_$(date +%s%N)" -d ${DATASTORE_ID} --type $IMAGE_TYPE --size 10 | awk '{print $NF}')
while [[ $(oneimage show $IMAGE_ID -x | xmlstarlet sel -t -v "//STATE") -ne 1 ]]; do sleep 1; done
VM_ID=$(onevm create --name "test_$(date +%s%N)" --memory 128 --cpu 1 --disk $IMAGE_ID | awk '{print $NF}')

sleep 20

SCHED_MESSAGE=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/USER_TEMPLATE/SCHED_MESSAGE")
VM_STATE=$(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE")


onevm terminate --hard $VM_ID
while [[ $(onevm show $VM_ID -x | xmlstarlet sel -t -v "/VM/STATE") -ne 6 ]]; do sleep 1; done
oneimage delete $IMAGE_ID


if [ "$VM_STATE" -eq 1 ] && [ -n "$SCHED_MESSAGE" ]; then
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi