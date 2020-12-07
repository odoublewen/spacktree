#!/bin/bash
set -euo pipefail

if [[ $(type -t module) == "function" ]]; then
  echo "SPACKTREE: This wrapper script should only be run in a module-naive shell"
  exit 1
fi

echo "SPACKTREE: Setting paths"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
if [ "$#" -eq 1 ]; then
  SPACK_DIR=$(readlink -f $1)
else
  SPACK_DIR=${THIS_DIR}/spack
fi
SPACK_EXE=${SPACK_DIR}/bin/spack
echo "THIS_DIR=${THIS_DIR}"
echo "SPACK_DIR=${SPACK_DIR}"
echo "SPACK=${SPACK_EXE}"

echo "-------------- Check or make clone of spack --------------"
if [[ -d ${SPACK_DIR} ]]; then
  echo "${SPACK_DIR} already exists; skipping clone"
else
  git clone --depth 1 https://github.com/spack/spack.git "${SPACK_DIR}"
fi
SPACK_COMMIT=$(cd "${SPACK_DIR}" &&  git rev-parse HEAD)
echo "Current spack commit (HEAD): ${SPACK_COMMIT}"

SPACK_ROOT=$(${SPACK_EXE} location -r)
export SPACK_ROOT

echo "-------------- Configuring spack --------------"
# copy custom config files to spack
cp packages.yaml modules.yaml "${SPACK_ROOT}/etc/spack/"

if [[ ! -z ${SPACK_MIRROR:-} ]]; then
  if [[ ! -d ${SPACK_MIRROR:-} ]]; then
    mkdir -p ${SPACK_MIRROR}
  fi
  cat >${SPACK_ROOT}/etc/spack/mirrors.yaml <<EOF
mirrors:
  local: file://${SPACK_MIRROR}
EOF
fi

echo "-------------- Installing packages --------------"

${SPACK_EXE} compiler find

# build packages
while read -r line; do
#  IFS=" " read -r -a linearray <<< "$line"
  linearray=(${line})
  package=${linearray[0]}

  if [[ ${package:0:1} == "#" ]]; then
    continue
  fi

  echo ">>> Working on ${package}"
  if [[ ${package:0:4} == "gcc@" ]]; then
    IFS="@" read -r -a GCC_VERSION <<< "$package"
    if ! ${SPACK_EXE} location -i ${package} >/dev/null 2>&1; then
      ${SPACK_EXE} install --fail-fast "${package}"
      ${SPACK_EXE} compiler add --scope site "$(${SPACK_EXE} location -i ${package})"
    fi
  else
    ${SPACK_EXE} install --fail-fast "${package}"
  fi
done < packages.txt

if [[ ! -z ${SPACK_MIRROR:-} && -d ${SPACK_MIRROR:-} ]]; then
  # copy any new tar.gz files into the mirror, using checksums to determine newness
  rsync -rvc "${SPACK_ROOT}/var/spack/cache/" "${SPACK_MIRROR}"
fi


SPACK_LMOD_CORE_DIR=$(find "$SPACK_ROOT/share/spack/lmod" -name Core)
SPACK_LMOD_MODULES_DIR=$(dirname "${SPACK_LMOD_CORE_DIR}")"/gcc/${GCC_VERSION[1]}"
SPACK_LMOD_BASH_INIT=$(${SPACK_EXE} location -i lmod)/lmod/lmod/init/bash

#export SPACK_LMOD_MODULES_DIR
#export SPACK_LMOD_BASH_INIT

cat >"${THIS_DIR}/activate.sh" <<EOF
# set default modules to load, if SPACK_AUTOLOAD_MODULES is unset
SPACK_AUTOLOAD_MODULES=\${SPACK_AUTOLOAD_MODULES:-"tree jq parallel the-silver-searcher"}

# set up an empty MANPATH, so that when lmod adds to it we can still access the system man pages.
if [[ -z \${MANPATH:-} ]]; then
    export MANPATH=":"
fi

# set up modules -  only do the full setup first time through
if [[ -z \${_INIT_LMOD:-} ]]; then
    export _INIT_LMOD=1
    source ${SPACK_LMOD_BASH_INIT}
    module use ${SPACK_LMOD_MODULES_DIR}
    if [[ -z \${SPACK_AUTOLOAD_MODULES:-} ]]; then
        module load \${SPACK_AUTOLOAD_MODULES}
    fi
else
    source ${SPACK_LMOD_BASH_INIT}
    module refresh
fi

# friendly message
echo -e "
* Spack env modules activated.
* Type `module avail` to see a list of available packages.
* You can set the env var SPACK_AUTOLOAD_MODULES before sourcing activate.sh
  e.g. export SPACK_AUTOLOAD_MODULES=\"tree git jq parallel\"
"
EOF





# echo "-------------- Activating the new spack env --------------"
# source ${THIS_DIR}/init.sh

# echo "-------------- Getting git-pip.py --------------"
# wget -O ${THIS_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py

# echo "-------------- Setting up pip/pipenv for Python2 --------------"
# module purge
# PYTHON2_MOD_NAME=$(module spider python/2.7.18 2>&1 | sed -n '\|python: |s|.*\(python/2.7.18-.*\)|\1|p')
# module load ${PYTHON2_MOD_NAME}
# python get-pip.py
# pip install pipenv

# echo "-------------- Setting up pip/pipenv for Python3 --------------"
# module purge
# PYTHON3_MOD_NAME=$(module spider python/3.8.6 2>&1 | sed -n '\|python: |s|.*\(python/3.8.6-.*\)|\1|p')
# module load ${PYTHON3_MOD_NAME}
# python get-pip.py
# pip install pipenv
