#!/bin/bash
set -euo pipefail

if [[ $(type -t module) == "function" ]]; then 
    echo "This wrapper script should only be run in a module-naive shell"
    exit 1
fi

echo "-------------- Setting paths --------------"
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [ "$#" -eq 1 ]; then
    APPS_DIR=$(readlink -f $1)
else
    APPS_DIR=${THIS_DIR}/spack
fi
SPACK=${APPS_DIR}/bin/spack
echo "THIS_DIR=${THIS_DIR}"
echo "APPS_DIR=${APPS_DIR}"
echo "SPACK=${SPACK}"

echo "-------------- Making fresh clone of spack --------------"
if [[ -d ${APPS_DIR} ]]; then
    echo "${APPS_DIR} already exists; skipping clone"
else
    git clone https://github.com/spack/spack.git ${APPS_DIR}
fi

echo "-------------- Installing our packages --------------"
export SPACK_ROOT=$(${SPACK} location -r)

# copy custom config files to spack
cp packages.yaml modules.yaml mirrors.yaml ${SPACK_ROOT}/etc/spack/

# build our compiler
my_compiler=gcc@8.2.0
if ! ${SPACK} location -i ${my_compiler} > /dev/null 2>&1; then
    ${SPACK} install ${my_compiler}
    ${SPACK} compiler add --scope site $(${SPACK} location -i ${my_compiler})
fi

# build packages
for package in $(grep -o '^[^#]*' packages.txt); do
    echo ">>> Working on ${package}..."
    ${SPACK} install ${package}
done

# copy any new tar.gz files into the mirror, using checksums to determine newness
rsync -rvc ${SPACK_ROOT}/var/spack/cache/ /raid/software/spack/mirror/

echo "-------------- Activating the new spack env --------------"
source ${THIS_DIR}/init.sh

echo "-------------- Getting git-pip.py --------------"
wget -O ${THIS_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py

echo "-------------- Setting up pip/pipenv for Python2 --------------"
module purge
PYTHON2_MOD_NAME=$(module spider python/2.7.15 2>&1 | sed -n '\|python: |s|.*\(python/2.7.15-.*\)|\1|p')
module load ${PYTHON2_MOD_NAME}
python get-pip.py
pip install pipenv

echo "-------------- Setting up pip/pipenv for Python3 --------------"
module purge
PYTHON3_MOD_NAME=$(module spider python/3.6.5 2>&1 | sed -n '\|python: |s|.*\(python/3.6.5-.*\)|\1|p')
module load ${PYTHON3_MOD_NAME}
python get-pip.py
pip install pipenv