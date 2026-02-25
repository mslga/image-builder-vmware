#!/usr/bin/env bash

function _get_current_date() {
    CURRENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

}

function _get_date_suffix() {
    MONTH=$(date +%m)
    YEAR=$(date +%y)

    # interpret the variable as a decimal number rather than an octal number
    MONTH=$((10#$MONTH))
    YEAR=$((10#$YEAR))

    if [[ ${MONTH} = 01 ]] ; then
        PREV_MONTH=12
        YEAR=$((YEAR - 1))
    else
        PREV_MONTH=$((MONTH - 1))
    fi

    # if the number has 1 sign
    if [[ ${#PREV_MONTH} -eq 1 ]]; then
        export DATE_SUFFIX="${YEAR}0${PREV_MONTH}"
    # if the number has 2 signs
    elif [[ ${#PREV_MONTH} -eq 2 ]]; then
        export DATE_SUFFIX="${YEAR}${PREV_MONTH}"
    fi

}

function _get_tpl_name() {
    export TPL_NAME="ubuntu-${UBUNTU_VERSION}-kube-${K8S_VERSION}"
    export TPL_NAME_SUFFIX="ubuntu-${UBUNTU_VERSION}-kube-${K8S_VERSION}-${DATE_SUFFIX}"

}

function _get_vsphere_values() {
    export VSPHERE_SERVER_NAME=$(jq -r '.vcenter_server' values/vsphere.json)
    export VSPHERE_DATACENTER=$(jq -r '.datacenter' values/vsphere.json)
    export VSPHERE_DATASTORE=$(jq -r '.datastore' values/vsphere.json)
    export VSPHERE_NETWORK=$(jq -r '.network' values/vsphere.json)
    export VSPHERE_RESOURCE_POOL=$(jq -r '.resourse_pool' values/vsphere.json)
    export VSPHERE_ADMIN_NAME=$(jq -r '.username' values/vsphere.json)
    export VSPHERE_ADMIN_PASSWD=$(jq -r '.password' values/vsphere.json)

}

function _govc_config() {
    _get_vsphere_values

    export GOVC_INSECURE=1
    export GOVC_USERNAME="${VSPHERE_ADMIN_NAME}"
    export GOVC_PASSWORD="${VSPHERE_ADMIN_PASSWD}"
    export GOVC_URL="https://${VSPHERE_SERVER_NAME}"
    export GOVC_DATACENTER="${VSPHERE_DATACENTER}"
    export GOVC_DATASTORE="${VSPHERE_DATASTORE}"
    export GOVC_NETWORK="${VSPHERE_NETWORK}"
    export GOVC_RESOURCE_POOL="${VSPHERE_RESOURCE_POOL}"

}

function _vm_find() {
    # find only tpls ends with word
    export IS_VM_EXISTS=$(govc find / -type m 2>/dev/null | grep -q "${TPL_NAME}\$" && echo 0 || echo 1)
    echo $IS_VM_EXISTS

}

function _vm_snapshot() {
    govc snapshot.create -vm "${TPL_NAME}" root

}

function _vm_destroy() {
    VM_NAME=$1

    govc vm.destroy "${VM_NAME}"

}

function _vm_to_template(){
    IS_SUFFIX=$1

    if [[ ${IS_SUFFIX} == "with_suffix" ]]; then 
        TPL=${TPL_NAME_SUFFIX}
    else
        TPL=${TPL_NAME}
    fi

    govc vm.markastemplate "${TPL}"

}

function _template_to_vm() {
    VM_NAME=$1

    # check if VM_NAME is empty
    if [[ -z ${VM_NAME} ]]; then
        VM_NAME=${TPL_NAME}
    fi

    govc vm.markasvm -pool "${VSPHERE_RESOURCE_POOL}" "${VM_NAME}"

}

function _vm_rename() {
    echo "set govc conf"
    _govc_config

    _vm_find
    if [[ ${IS_VM_EXISTS} -eq 0 ]]; then
        _template_to_vm
        govc vm.change -vm "${TPL_NAME}" -name "${TPL_NAME_SUFFIX}"
        _vm_to_template with_suffix
    fi

}

function _rotate_templates() {
    TPL_STR=$(govc find / -type m 2>/dev/null | grep ${TPL_NAME}- || true | sort -r)

    # from a multiline string to an array 
    TPL_ARR=($(echo "$TPL_STR" | awk '{print $0}'))
    # rotate templates only if they exist
    if [[ ${#TPL_ARR[@]} > 3 ]]; then
        OLD_TEMPLATES=("${TPL_ARR[@]:3}")
        for i in "${OLD_TEMPLATES[@]}"; do
            _template_to_vm ${i}
            _vm_destroy ${i}
        done
    fi

}

function render_values_by_find_replace() {
    ELEMENTS=( "$@" )

    # assert arguments count
    if [[ $((${#ELEMENTS[@]}%2)) -ne 0 ]]; then
        echo 'Find-replace pairs do not match. Ensure all values are not empty, or use "" to pass empty string.'
        exit -1
    fi;

    VALUES_FILE=values/vsphere.json

    SIZE=${#ELEMENTS[@]}
    for ((i=0; i<${SIZE}; i++)); do
        FIND=${ELEMENTS[$i]} i=$((${i}+1)) REPLACE=${ELEMENTS[$i]}
        sed -i "s/${FIND}/${REPLACE}/g" ${VALUES_FILE}
    done

}

function image_build(){
    echo "get date"
    _get_current_date
    echo "$CURRENT_DATE INFO start build image ubuntu-${UBUNTU_VERSION}"

    _get_date_suffix
    _get_tpl_name

    _vm_rename

    export IMAGE_BUILDER_PATH="/home/imagebuilder"

    docker run -i --rm --net=host \
    --env PACKER_VAR_FILES="${IMAGE_BUILDER_PATH}/vsphere.json ${IMAGE_BUILDER_PATH}/custom-vars.json"\
    -v ${CI_PROJECT_DIR}/values/vsphere.json:${IMAGE_BUILDER_PATH}/vsphere.json\
    -v ${CI_PROJECT_DIR}/values/vars.json:${IMAGE_BUILDER_PATH}/custom-vars.json\
    ${IMAGE_BUILDER_IMAGE}\
    build-node-ova-vsphere-ubuntu-${UBUNTU_VERSION}

    _vm_snapshot
    _vm_to_template
    _rotate_templates

    _get_current_date
    echo "$CURRENT_DATE INFO builded image ubuntu-${UBUNTU_VERSION}"

}
