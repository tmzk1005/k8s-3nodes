#!/usr/bin/env bash

MAIN_HOME=$(dirname "$0")
cd "${MAIN_HOME}" || exit -1
MAIN_HOME=$(pwd)

WORK_DIR=".work"

NODE_IP_REPFIX="192.168.56.18"
NODE_IP_1="${NODE_IP_REPFIX}1"
NODE_IP_2="${NODE_IP_REPFIX}2"
NODE_IP_3="${NODE_IP_REPFIX}3"


function prepare_work_dir() {
    if [ ! -d ${WORK_DIR} ]; then
        mkdir ${WORK_DIR} && echo "创建工作目录.work"
    fi
}

function cmd_exist () {
    cmd_name=$1
    if command -v ${cmd_name} > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function check_deps() {
    pass=1
    if ! cmd_exist vagrant; then
        echo "vagrant未安装，请先安装!"
        pass=0
    fi

    if ! cmd_exist virtualbox; then
        echo "virtualbox未安装，请先安装！"
        pass=0
    fi

    if [ $pass -eq 0 ]; then
        exit -1
    fi
}

function download_k8s_bins() {
    k8s_bins="${WORK_DIR}/k8s_bins"
    if [ ! -d ${k8s_bins} ]; then
        mkdir ${k8s_bins}
    fi

    for program in "kube-apiserver" "kube-controller-manager" "kube-scheduler"; do
        if [ ! -f "${k8s_bins}/${program}" ]; then
            echo "TODO: download ${program}"
        fi
    done
}

function generate_base_box_vagrant_file() {
    vag_file=$1
    touch ${vag_file}

    cat << EOF > ${vag_file}
Vagrant.configure("2") do |config|
  config.vm.box_check_update = false
  config.vm.box = "ubuntu/kinetic64"

  config.vm.define "k8s-base"

  config.vm.provider "virtualbox" do |vb|
    vb.name = "k8s-base"
    vb.memory = 2048
    vb.cpus = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    mv /etc/apt/sources.list /etc/apt/sources.list.backup
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ kinetic main restricted universe multiverse' > /etc/apt/sources.list
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ kinetic-updates main restricted universe multiverse' >> /etc/apt/sources.list
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ kinetic-backports main restricted universe multiverse' >> /etc/apt/sources.list
    echo 'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ kinetic-security main restricted universe multiverse' >> /etc/apt/sources.list
    # apt-get update
    # apt-get install -y docker
  SHELL
end
EOF
}


function create_base_box() {
    base_box_dir="${WORK_DIR}/base_box_dir"
    if [ -d ${base_box_dir} ]; then
        return
    fi

    echo "创建制作vagrant box的工作目录${base_box_dir}"
    mkdir ${base_box_dir}

    vag_file="${base_box_dir}/Vagrantfile"
    generate_base_box_vagrant_file ${vag_file}

    cd ${base_box_dir} || exit -1
    if [ ! -d "${base_box_dir}/.vagrant" ];then
        vagrant up
        vagrant halt
        vagrant package --base k8s-base --output k8s-base.box
        vagrant box add --force --force --name k8s-base k8s-base.box
    fi

    cd "${MAIN_HOME}" || exit -1
}

function generate_vagrant_file() {
    vag_file=$1
    touch ${vag_file}
    echo '' > ${vag_file}

    echo 'Vagrant.configure("2") do |config|' >> ${vag_file}

    echo '  config.vm.box_check_update = false' >> ${vag_file}

    echo '  config.vm.provision "shell", inline: <<-SHELL' >> ${vag_file}
    echo "    echo '${NODE_IP_1}  k8s-node1' >> /etc/hosts" >> ${vag_file}
    echo "    echo '${NODE_IP_2}  k8s-node2' >> /etc/hosts" >> ${vag_file}
    echo "    echo '${NODE_IP_3}  k8s-node3' >> /etc/hosts" >> ${vag_file}
    echo '  SHELL' >> ${vag_file}

    echo '' >> ${vag_file}

    echo '  (1..3).each do |i|' >> ${vag_file}
    echo '    config.vm.define "k8s-node#{i}" do |node|' >> ${vag_file}
    echo '      node.vm.box = "k8s-base"' >> ${vag_file}
    echo '      node.vm.hostname = "k8s-node#{i}"' >> ${vag_file}
    echo "      node.vm.network 'private_network', ip: '${NODE_IP_REPFIX}#{i}'" >> ${vag_file}
    echo '      node.vm.provider "virtualbox" do |vb|' >> ${vag_file}
    echo '        vb.memory = 2048' >> ${vag_file}
    echo '        vb.cpus = 2' >> ${vag_file}
    echo '      end' >> ${vag_file}
    echo '    end' >> ${vag_file}
    echo '  end' >> ${vag_file}
    echo 'end' >> ${vag_file}
}

function create_vms() {
    vms_dir="${WORK_DIR}/vms"
    if [ -d ${vms_dir} ]; then
        return
    fi

    echo "创建vagrant工作目录${vms_dir}"
    mkdir ${vms_dir}

    vag_file="${vms_dir}/Vagrantfile"
    generate_vagrant_file $vag_file
}

function main() {
    prepare_work_dir
    check_deps
    download_k8s_bins
    create_base_box
    create_vms
}

main
