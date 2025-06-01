#!/bin/bash

BACKUP_DIRECTORY="/tmp"



function backup_datastore_template() {
    local DATASTORE="$1"
    local BACKUP_FILE_NAME="${DATASTORE}_attributes"
    local BACKUP_FILE_PATH="${BACKUP_DIRECTORY}/${BACKUP_FILE_NAME}"

    onedatastore show ${DATASTORE} -x | xmlstarlet sel -t -c "//TEMPLATE" -n > ${BACKUP_FILE_PATH}

    echo "Шаблон атрибутов хранилища ${DATASTORE} сохранен в ${BACKUP_FILE_PATH}"
}



if [ -z $1 ]; then
    DATASTORE_NAMES=($(onedatastore list -x | xmlstarlet sel -t -v "//DATASTORE/NAME"))

    for DATASTORE_NAME in "${DATASTORE_NAMES[@]}"; do
        backup_datastore_template $DATASTORE_NAME
    done
else
    backup_datastore_template $1
fi

