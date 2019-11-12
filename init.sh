# -*- mode: sh -*-
# vim: set ft=sh
#
#
# The typical user's .bash_profile would include:
#
# APPS_MODULES="emacs git htop"
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
# There are a few things that users can customize:
# Common:
#   APPS_MODULES - your list of modules to load
#      e.g. APPS_MODULES="emacs git htop etc etc etc..."
# Less common:
#   SPACK_DIR - path to top of a Spack apps tree, e.g. a team specific tree
#              (must include lmod)
#   APPS_SPECIAL_MODULES_DIR - path to dir of snowflake modulefiles
# Uncommon:
#   APPS_CORE_COMPILER - Compiler choice for lmod hierarch. scheme
#

THIS_DIR="$(cd "$(dirname "$BASH_SOURCE")"; pwd)" 

if [[ -z ${SPACK_DIR:-} ]]; then
    SPACK_DIR=${THIS_DIR}/spack
fi
_APPS_SPACK_EXE=${SPACK_DIR}/bin/spack
_APPS_LMOD_INIT_DIR=$(${_APPS_SPACK_EXE} location -i lmod)/lmod/lmod/init
_APPS_LMOD_CORE_DIR=${SPACK_DIR}/share/spack/lmod/linux-centos6-x86_64/gcc/8.2.0

# modules to load, core compiler will determine what's available
APPS_CORE_COMPILER=${APPS_CORE_COMPILER:-gcc}
APPS_MODULES=${APPS_MODULES:-"emacs git htop the-silver-searcher tree vim"}

# set up an empty MANPATH, so that when lmod adds to it we can still
# access the system man pages.
if [[ -z ${MANPATH:-} ]]; then
    export MANPATH=":"
fi

# only do the full setup first time through
if [[ -z ${_INIT_LMOD:-} ]]; then
    export _INIT_LMOD=1
    export BASH_ENV=${_APPS_LMOD_INIT_DIR}/bash
    source ${BASH_ENV}                     # load the init file into this shell
    module use ${_APPS_LMOD_CORE_DIR}      # hook up the Core modules directory
#    module load ${APPS_CORE_COMPILER}
    module load ${APPS_MODULES}
else                                   # otherwise just refresh things
    source ${BASH_ENV}
    module refresh
fi
# end of apps tree setup bits

echo -e "
* Spack tree initialized using these env vars:
  SPACK_DIR=${SPACK_DIR}
  APPS_MODULES=${APPS_MODULES}

* You can export these env vars prior to sourcing this script for more control over your environment.

* Type module avail to see a list of available packages.
"
