# -*- mode: sh -*-
# vim: set ft=sh
#
#
# The typical user's .bash_profile would include:
#
# SPACK_AUTOLOAD_MODULES="tree jq parallel"
# source /path/to/this/init.sh
#
# Even setting APPS_MODULES is optional if user is ok with default list...
#
# That will:
#
# 1. Fetch the name of the "current" spack tree from the Well Known
#    File if the user hasn't explicitly provided one.
# 2. Use the spack executable in that tree to ask for the location of
#    the Lmod directory in that tree.
# 3. Load the Lmod bash initialization file from within that Lmod dir.
# 4. Tell Lmod to use the Core dir that spack built.
# 5. Tell Lmod to use our directory of handcrafted module files.
# 6. Load the core compiler module, which makes the bulk of the
#    modulefiles accessible.
# 7. Load the user's modulefiles.
#

THIS_DIR="$(cd "$(dirname "$BASH_SOURCE")"; pwd)" 

if [[ -z ${SPACK_DIR:-} ]]; then
    SPACK_DIR=${THIS_DIR}/spack-current
fi
SPACK_EXE=${SPACK_DIR}/bin/spack
SPACK_LMOD_INIT_DIR=$(${SPACK_EXE} location -i lmod)/lmod/lmod/init      ######### POPULATE THIS
SPACK_GCC_VERSION=8.4.0
SPACK_LMOD_CORE_DIR=$(find spack/share/spack/lmod -name Core)
SPACK_LMOD_MODULES_DIR=$(dirname ${SPACK_LMOD_CORE_DIR})/gcc/${SPACK_GCC_VERSION}    #### PREPOPULATE THIS
SPACK_AUTOLOAD_MODULES=${SPACK_AUTOLOAD_MODULES:-"tree jq parallel the-silver-searcher"}

echo SPACK_LMOD_INIT_DIR $SPACK_LMOD_INIT_DIR
echo SPACK_LMOD_CORE_DIR $SPACK_LMOD_CORE_DIR
echo SPACK_LMOD_MODULES_DIR $SPACK_LMOD_MODULES_DIR
echo APPS_CORE_COMPILER $APPS_CORE_COMPILER
echo SPACK_AUTOLOAD_MODULES $SPACK_AUTOLOAD_MODULES

# set up an empty MANPATH, so that when lmod adds to it we can still access the system man pages.
if [[ -z ${MANPATH:-} ]]; then
    export MANPATH=":"
fi

# set up modules
if [[ -z ${_INIT_LMOD:-} ]]; then             # only do the full setup first time through
    export _INIT_LMOD=1
    export BASH_ENV=${SPACK_LMOD_INIT_DIR}/bash
    source ${BASH_ENV}                        # load the init file into this shell
    module use ${SPACK_LMOD_MODULES_DIR}      # hook up the Core modules directory
####    module load ${APPS_CORE_COMPILER}
    module load ${SPACK_AUTOLOAD_MODULES}
else                                          # otherwise just refresh things
    source ${BASH_ENV}
    module refresh
fi

# friendly message
echo -e "
* Spack tree initialized using these env vars:
  SPACK_DIR=${SPACK_DIR}
  SPACK_AUTOLOAD_MODULES=\"${SPACK_AUTOLOAD_MODULES}\"

* You can export these env vars prior to sourcing this script for more control over your environment.

* Type module avail to see a list of available packages.
"
