#!/bin/bash
set -euo pipefail

if [[ $(type -t module) == "function" ]]; then 
    echo "This wrapper script should only be run in a module-naive shell"
    exit 1
fi

if [[ ! -z ${SPACK_MIRROR:-} && -d ${SPACK_MIRROR:-} ]]; then
echo "-------------- Setting up local mirror --------------"
    cat >mirrors.yaml <<EOF
mirrors:
  local: file://${SPACK_MIRROR}
EOF
fi

echo "-------------- Setting paths --------------"
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [ "$#" -eq 1 ]; then
    SPACK_DIR=$(readlink -f $1)
else
    SPACK_DIR=${THIS_DIR}/spack
fi
SPACK=${SPACK_DIR}/bin/spack
echo "THIS_DIR=${THIS_DIR}"
echo "SPACK_DIR=${SPACK_DIR}"
echo "SPACK=${SPACK}"

echo "-------------- Check or make clone of spack --------------"
if [[ -d ${SPACK_DIR} ]]; then
    echo "${SPACK_DIR} already exists; skipping clone"
else
    git clone --depth 1 https://github.com/spack/spack.git ${SPACK_DIR}
fi
SPACK_COMMIT="$(cd ${SPACK_DIR}; git rev-parse HEAD)"
echo "Current spack commit (HEAD): ${SPACK_COMMIT}"

echo "-------------- Installing our packages --------------"
export SPACK_ROOT=$(${SPACK} location -r)

# copy custom config files to spack
cp packages.yaml modules.yaml ${SPACK_ROOT}/etc/spack/
if [[ -f mirrors.yaml ]]; then
    cp mirrors.yaml ${SPACK_ROOT}/etc/spack/
fi

# build our compiler
my_compiler=gcc@8.4.0
if ! ${SPACK} location -i ${my_compiler} > /dev/null 2>&1; then
    ${SPACK} compiler find
    ${SPACK} install --fail-fast ${my_compiler}
    ${SPACK} compiler add --scope site $(${SPACK} location -i ${my_compiler})
fi

# build packages
for package in $(grep -o '^[^#]*' packages.txt); do
    echo ">>> Working on ${package}..."
    ${SPACK} install --fail-fast ${package}
done

if [[ ! -z ${SPACK_MIRROR:-} && -d ${SPACK_MIRROR:-} ]]; then
    # copy any new tar.gz files into the mirror, using checksums to determine newness
    rsync -rvc ${SPACK_ROOT}/var/spack/cache/ ${SPACK_MIRROR}
exit


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
