# Тест атрибута с суффиксом М
# Атрибуты: LIMIT_TRANSFER_BW="25M"

function run_by_ssh() {
    local COMMAND="${1}"

    sshpass -p '1' ssh u@buarm "${COMMAND}"
}


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

IMAGE_URL="http://buarm/mini.qcow2"


run_by_ssh "cd /media/sf_git/skts-test/testlink/brest/ && ./apache_with_image.sh &> /dev/null"

IMAGE_ID=$(oneimage create -d $DATASTORE_ID --name "test_$(date +%s%N)" --path $IMAGE_URL --type $IMAGE_TYPE | awk '{print $NF}')


run_by_ssh "cd /media/sf_git/skts-test/testlink/brest/ && timeout 10 ./transmit_speed.sh >> ~/testfile"
AVG_UPLOAD=$(run_by_ssh "cat -e ~/testfile | grep MB/s | grep -o '[0-9]*\.[0-9]*' | awk '{ sum += \$1; count ++ } END { if (count > 0) print int(sum / count) }'")


oneimage delete $IMAGE_ID

run_by_ssh "sudo apt purge apache2 -y &> /dev/null" #; sudo rm -f ~/testfile"



if [[ ${AVG_UPLOAD} -gt 23 ]] && [[ ${AVG_UPLOAD} -lt 27 ]]; then 
    echo "PASSED"
    exit 0
else
    echo "FAILED"
    exit 1
fi