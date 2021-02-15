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

echo "SPACKTREE: Check or make clone of spack"
if [[ -d ${SPACK_DIR} ]]; then
  echo "SPACKTREE: ${SPACK_DIR} already exists; skipping clone"
else
  git clone --depth 1 https://github.com/spack/spack.git "${SPACK_DIR}"
fi
SPACK_COMMIT=$(cd "${SPACK_DIR}" &&  git rev-parse HEAD)
echo "SPACKTREE: Current spack commit (HEAD): ${SPACK_COMMIT}"

SPACK_ROOT=$(${SPACK_EXE} location -r)
export SPACK_ROOT

echo "SPACKTREE: Configuring spack"
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

echo "SPACKTREE: Installing packages"

${SPACK_EXE} compiler find

# build packages
while read -r line; do
#  IFS=" " read -r -a linearray <<< "$line"
  linearray=(${line})
  package=${linearray[0]}

  if [[ ${package:0:1} == "#" ]]; then
    continue
  fi

  echo "SPACKTREE: Working on ${package}"
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


SPACK_LMOD_MODULES_DIR=$(find "$SPACK_ROOT/share/spack/lmod" -path "*gcc/${GCC_VERSION[1]}")
SPACK_LMOD_BASH_INIT=$(${SPACK_EXE} location -i lmod)/lmod/lmod/init/bash


echo "SPACKTREE: Writing activation script"
cat >"${THIS_DIR}/activate.sh" <<EOF
# if MANPATH var is unset, initialize it so that when lmod adds to it,
# we can still access the system man pages.
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
* Type 'module avail' to see a list of available packages.
* You can set the env var SPACK_AUTOLOAD_MODULES before sourcing activate.sh
  e.g. export SPACK_AUTOLOAD_MODULES=\"tree git jq parallel\"
"
EOF
