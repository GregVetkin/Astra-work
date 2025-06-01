#!/bin/bash

check_only_image_and_file_type "${DATASTORE_TYPE}"

DATASTORE=$(get_datastore_name_by_type "${DATASTORE_TYPE}")
IMAGE_TYPE=$([ "$DATASTORE_TYPE" == "IMAGE" ] && echo "OS" || echo "CONTEXT")




function test_tar_gz() {
    #  Тест проверки разархивации образа и его работоспособности
    #  Необходимые атрибуты NO_DECOMPRESS="NO"

    if [[ "${DATASTORE_TYPE}" != "IMAGE" ]]
    then
        echo "Тест доступен только для хранилищ типа IMAGE"
        exit 1
    fi

    check_storage_attributes_before_test "${DATASTORE}" "NO_DECOMPRESS=\"NO\""

    (cd /var/tmp/ && wget ftp://10.177.102.240/guest/mini/latest/archive.tar.gz)
    sudo chmod 777 /var/tmp/archive.tar.gz

    $RUN_AS_BRESTADM oneimage create -d "${DATASTORE}" --name "test_image" --path "/var/tmp/archive.tar.gz" --type "OS"
            
    while [[ "$($RUN_AS_BRESTADM oneimage show test_image | grep '^STATE ' | awk '{print $3}')" == "lock" ]]; do
        sleep 1
    done

    if [[ $($RUN_AS_BRESTADM oneimage show test_image | grep '^STATE ' | awk '{print $3}') == "err" ]]
    then
        echo "Образ загруженного архива в статусе ОШИБКА"
        $RUN_AS_BRESTADM oneimage delete "test_image"
        return 1
    fi

    echo '
            NAME = "test_vn"
            AR = [
            IP = "10.0.70.250",
            SIZE = "1",
            TYPE = "IP4" ]
            BRIDGE = "br0"
            GATEWAY = "10.0.70.254"
            DNS = "8.8.8.8 10.0.70.10"
            SEARCH_DOMAIN = "brest.local"
            VN_MAD = "bridge"
    ' > "/tmp/vn_template"

    $RUN_AS_BRESTADM onevnet create "/tmp/vn_template"
    sudo rm -f "/tmp/vn_template"

    echo '
            NAME = "test_vm"
            CONTEXT = [
            NETWORK = "YES",
            SSH_PUBLIC_KEY = "$USER[SSH_PUBLIC_KEY]" ]
            CPU = "2"
            DISK = [
            IMAGE = "test_image",
            IMAGE_UNAME = "brestadm" ]
            FEATURES = [
            GUEST_AGENT = "yes" ]
            GRAPHICS = [
            LISTEN = "0.0.0.0",
            TYPE = "SPICE" ]
            HOT_RESIZE = [
            CPU_HOT_ADD_ENABLED = "NO",
            MEMORY_HOT_ADD_ENABLED = "NO" ]
            HYPERVISOR = "kvm"
            MEMORY = "2048"
            MEMORY_UNIT = "GB"
            MEMORY_UNIT_COST = "MB"
            NIC = [
            NETWORK = "test_vn",
            NETWORK_UNAME = "brestadm",
            SECURITY_GROUPS = "0" ]
            OS = [
            ARCH = "x86_64" ]
            VCPU = "2"
        ' > "/tmp/vm_template"


    $RUN_AS_BRESTADM onevm create "/tmp/vm_template"
    sudo rm -f "/tmp/vm_template"

    while [[ "$($RUN_AS_BRESTADM onevm show test_vm | grep '^STATE ' | awk '{print $3}')" != "POWEROFF" ]]
    do
        sleep 5
    done


    $RUN_AS_BRESTADM onevm resume "test_vm"

    sleep 60

    if ping -c 10 "10.0.70.250"; then
        CODE=0
    else
        CODE=1
    fi

    $RUN_AS_BRESTADM onevm terminate --hard "test_vm"
    sleep 20
    $RUN_AS_BRESTADM oneimage delete "test_image"
    $RUN_AS_BRESTADM onevnet delete "test_vn"
    sudo rm -f /var/tmp/archive.tar.gz

    return $CODE
}


function test_tar_gz_correct_size_with_NO() {
    #  Тест проверки корректного расчета образа
    #  Необходимые атрибуты NO_DECOMPRESS="NO"

    check_storage_attributes_before_test "${DATASTORE}" "NO_DECOMPRESS=\"NO\""
    
    dd if=/dev/zero of=/var/tmp/1gb bs=1MiB count=1024
    cd /var/tmp/ && tar -czvf 1gb.tar.gz 1gb

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/1gb.tar.gz" --type "${IMAGE_TYPE}"

    while [[ "$($RUN_AS_BRESTADM oneimage show test_image | grep '^STATE ' | awk '{print $3}')" == "lock" ]]
    do
        sleep 1
    done
        
    IMAGE_SIZE=$($RUN_AS_BRESTADM oneimage show "test_image" | grep "^SIZE " | awk '{print $3}')
    
    if [[ "${IMAGE_SIZE}" == "1G" ]]
    then
        CODE=0
    else
        CODE=1
    fi

    sudo rm -f /tmp/1gb*
    $RUN_AS_BRESTADM oneimage delete "test_image"

    return $CODE
}


function test_tar_gz_correct_size_with_YES() {
    #  Тест проверки корректного расчета образа
    #  Необходимые атрибуты NO_DECOMPRESS="NO"

    check_storage_attributes_before_test "${DATASTORE}" "NO_DECOMPRESS=\"YES\""
    
    dd if=/dev/zero of=/var/tmp/1gb bs=1MiB count=1024
    cd /var/tmp/ && tar -czvf 1gb.tar.gz 1gb

    $RUN_AS_BRESTADM oneimage create --name "test_image" -d "${DATASTORE}" --path "/var/tmp/1gb.tar.gz" --type "${IMAGE_TYPE}"

    while [[ "$($RUN_AS_BRESTADM oneimage show test_image | grep '^STATE ' | awk '{print $3}')" == "lock" ]]
    do
        sleep 1
    done

    IMAGE_SIZE=$($RUN_AS_BRESTADM oneimage show "test_image" | grep "^SIZE " | awk '{print $3}')
    
    if [[ "${IMAGE_SIZE}" == "1M" ]]
    then 
        CODE=0
    else
        CODE=1
    fi

    sudo rm -f /tmp/1gb*
    $RUN_AS_BRESTADM oneimage delete "test_image"

    return $CODE
}
