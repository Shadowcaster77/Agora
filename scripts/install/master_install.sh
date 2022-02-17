#! /bin/bash

# Description
# * Run this script on your laptop
# * This script installs dependent packages and Hydra on remote servers
#   listed in config/platform.json
# * To see options, run master_install.sh -h

set -e

# Find the root directory of Hydra project
script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
hydra_root_dir=$( cd ${script_dir}/../.. >/dev/null 2>&1 && pwd )

source ${hydra_root_dir}/scripts/utils/utils.sh

# Run server initialization scripts on all remote servers
# Check scripts/system/server_init.sh
RUN_SERVER_INIT=0 

# Specify the remote server to install packages and Hydra app
# If ONLY_SINGLE_SERVER is all, then install on all remote servers
#   listed in config/platform.json
ONLY_SINGLE_SERVER="all" 

# Install all system-level packages required by Hydra on remote servers (require sudo)
# By default, system-level packages are not installed by this script
INSTALL_HYDRA_PKGS_SYSTEM_LEVEL=0

# The JSON file describing all remote servers to install Hydra and dependencies
# User can specify this parameter using 'hydra_server_list_json' in config/config.json
HYDRA_SERVER_LIST_JSON=${hydra_root_dir}/config/platform.json

# The root directory for Hydra app and other dependencies on remote servers
# User can specify this parameter using 'hydra_runner_root' in config/config.json
HYDRA_RUNNER_ROOT="~/HydraRemoteRunner"

# Parse input arguments
# Run "master_install.sh -h" to check all argument options
while getopts "h?:is:a" opt; do
  case "$opt" in
    h|\?)
      echo "Help"
      echo -e "\t-h\tShow this infomation"
      echo -e "\t-i\tRun server initialization scripts on all remote servers (Check scripts/system/server_init.sh)"
      echo -e "\t-s [hostname]\tSpecify the only remote server to install packages and Hydra app"
      echo -e "\t-a\tInstall all system-level packages required by Hydra on remote servers (require sudo)"
      exit 0
      ;;
    i)
      RUN_SERVER_INIT=1
      ;;
    s)
      ONLY_SINGLE_SERVER="${OPTARG}"
      ;;
    a)
      INSTALL_HYDRA_PKGS_SYSTEM_LEVEL=1
      ;;
  esac
done

# Read HYDRA_SERVER_LIST_JSON and HYDRA_RUNNER_ROOT from file config/config.json
hydra_master_config_json=${hydra_root_dir}/config/config.json
if [ ! -f ${hydra_master_config_json} ]; then
  echored "ERROR: config file ${hydra_master_config_json} does not exist"
fi
res=$(cat ${hydra_master_config_json} | jq '.hydra_server_list_json' | tr -d '"')
if [ "${res}" != "null" ]; then
  HYDRA_SERVER_LIST_JSON=${hydra_root_dir}/${res}
fi
res=$(cat ${hydra_master_config_json} | jq '.hydra_runner_root' | tr -d '"')
if [ "${res}" != "null" ]; then
  HYDRA_RUNNER_ROOT=${res}
fi

echocyan "Hydra global configurations:"
echocyan "  Hydra server list: ${HYDRA_SERVER_LIST_JSON}"
echocyan "  Hydra root runner directory on remote servers: ${HYDRA_RUNNER_ROOT}"
echo

# Create a diretory for storing logs
mkdir -p /tmp/Hydra

# Parse the JSON file describing remote servers using jq tool
hydra_server_num=$(cat ${HYDRA_SERVER_LIST_JSON} | jq '. | length')

# If ONLY_SERVER_SERVER is "all", install on all remote servers in HYDRA_SERVER_LIST_JSON
if [ ${ONLY_SINGLE_SERVER} == "all" ]; then
  echocyan "Detected ${hydra_server_num} servers listed in ${HYDRA_SERVER_LIST_JSON}"
  echocyan "Copying Hydra codebase to all remote servers"
  for (( i=0; i<${hydra_server_num}; i++ )) do
    server_name=$(cat ${HYDRA_SERVER_LIST_JSON} | jq --argjson i $i '. | keys | .[$i]' | tr -d '"')
    hydra_tmp_dir[$i]=$(ssh -oStrictHostKeyChecking=no ${server_name} "mktemp -d")
    # (scp -oStrictHostKeyChecking=no -r ${hydra_root_dir} ${server_name}:${hydra_tmp_dir[$i]}/ > /dev/null 2>&1; \
    #   echo "${server_name} copy complete") &
    (rsync -a --exclude '*.bin' --exclude '*.git/*' ${hydra_root_dir} ${server_name}:${hydra_tmp_dir[$i]}/ > /dev/null 2>&1; \
      echo "${server_name} rsync complete") &
  done
  wait
  if [ "${RUN_SERVER_INIT}" == 1 ]; then
    echocyan "Initialize server setup on all remote servers"
    for (( i=0; i<${hydra_server_num}; i++ )) do
      server_name=$(cat ${HYDRA_SERVER_LIST_JSON} | jq --argjson i $i '. | keys | .[$i]' | tr -d '"')
      (ssh -oStrictHostKeyChecking=no ${server_name} "cd ${hydra_tmp_dir[$i]}/Agora; \
        ./scripts/system/server_init.sh" > /tmp/Hydra/init_${server_name}.log 2>&1; \
        echo "${server_name} initialization complete";) &
    done
    wait
  fi
  echocyan "Install dependent packages and Hydra application on all remote servers"
  for (( i=0; i<${hydra_server_num}; i++ )) do
    server_name=$(cat ${HYDRA_SERVER_LIST_JSON} | jq --argjson i $i '. | keys | .[$i]' | tr -d '"')
    (ssh -oStrictHostKeyChecking=no ${server_name} "mkdir -p ${HYDRA_RUNNER_ROOT}; \
      cd ${HYDRA_RUNNER_ROOT}; cp -r ${hydra_tmp_dir[$i]}/Agora ./; rm -rf ${hydra_tmp_dir[$i]}/Agora; \
      cd Agora; INSTALL_HYDRA_PKGS_SYSTEM_LEVEL=${INSTALL_HYDRA_PKGS_SYSTEM_LEVEL} \
      ./scripts/install/install_all.sh"; \
      scp -oStrictHostKeyChecking=no ${server_name}:/tmp/Hydra/install.log /tmp/Hydra/install_${server_name}.log; \
      echo "${server_name} installation complete") &
  done
  wait
  echocyan "All remote servers installation complete. Check /tmp/Hydra/install_{server_name}.log for details"
# If ONLY_SERVER_SERVER is not "all", install on the only server named ${ONLY_SERVER_SERVER}
else
  server_name=${ONLY_SINGLE_SERVER}
  echocyan "Copying Hydra codebase to ${server_name}"
  hydra_tmp_dir=$(ssh -oStrictHostKeyChecking=no ${server_name} "mktemp -d")
  # scp -oStrictHostKeyChecking=no -r ${hydra_root_dir} ${server_name}:${hydra_tmp_dir}/ > /dev/null 2>&1
  rsync -a --exclude '*.bin' --exclude '*.git/*' ${hydra_root_dir} ${server_name}:${hydra_tmp_dir}/ > /dev/null 2>&1
  if [ "${RUN_SERVER_INIT}" == 1 ]; then
    echocyan "Initialize server setup on ${server_name}"
    ssh -oStrictHostKeyChecking=no ${server_name} "cd ${hydra_tmp_dir}/Agora; \
      ./scripts/system/server_init.sh" > /tmp/Hydra/init_${server_name}.log 2&>1
  fi
  echocyan "Install dependent packages and Hydra application on ${server_name}"
  ssh -oStrictHostKeyChecking=no ${server_name} "mkdir -p ${HYDRA_RUNNER_ROOT}; \
    cd ${HYDRA_RUNNER_ROOT}; cp -r ${hydra_tmp_dir}/Agora ./; rm -rf ${hydra_tmp_dir}/Agora; cd Agora; \
    INSTALL_HYDRA_PKGS_SYSTEM_LEVEL=${INSTALL_HYDRA_PKGS_SYSTEM_LEVEL} \
    ./scripts/install/install_all.sh"
  scp -oStrictHostKeyChecking=no ${server_name}:/tmp/Hydra/install.log /tmp/Hydra/install_${server_name}.log > /dev/null 2>&1
  echocyan "${server_name} installation complete. Please check /tmp/Hydra/install_${server_name}.log for details"
fi
