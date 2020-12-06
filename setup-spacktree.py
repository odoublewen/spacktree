#!/usr/bin/env python

from __future__ import print_function
import logging
import argparse
from os import path, makedirs, rename
import subprocess
import urllib.request
import zipfile
import tempfile
import sys
import glob

LOGGING_FORMAT = '==== SPACKTREE ===> %(message)s'

SPACKTREE_DIR = path.dirname(path.realpath(__file__))

MIRRORS_YAML = """mirrors:
  local: file://{path}"""

PACKAGES_YAML = """packages:
  all:
    compiler: [gcc@{gcc_version}]
  cairo:
    variants: -X+pdf
  clapack:
    variants: ~external-blas
  pcre:
    variants: +jit
  perl:
    version: [5.32.0]
  python:
    version: [3.8.6]
"""

MODULES_YAML = """modules:
  enable::
    - lmod
  lmod:
    core_compilers:
      - 'gcc@{gcc_version}'
    whitelist:
      - gcc
#    blacklist:
#      - '%gcc@4.8.2'
#      - '%gcc@4.8.5'
#      - '%gcc@4.8'
    verbose_autoload: false
    all:
      autoload: 'direct'
      suffixes:
        '+jit': jit
        '^python@2.7': 'py2.7'
        '^python@3.8': 'py3.8'
      environment:
        set:
          'SPACK_{{name}}_ROOT': '{{prefix}}'
    ^python:
      autoload:  'direct'
"""

ACTIVATE_SCRIPT = """

SPACK_AUTOLOAD_MODULES=${{SPACK_AUTOLOAD_MODULES:-"tree jq parallel the-silver-searcher"}}

# set up an empty MANPATH, so that when lmod adds to it we can still access the system man pages.
if [[ -z ${{MANPATH:-}} ]]; then
    export MANPATH=":"
fi

# set up modules
if [[ -z ${{_INIT_LMOD:-}} ]]; then             # only do the full setup first time through
    export _INIT_LMOD=1
    source {BASH_ENV}                        # load the init file into this shell
    module use {SPACK_LMOD_MODULES_DIR}      # hook up the Core modules directory
####    module load ${{APPS_CORE_COMPILER}}
    module load ${{SPACK_AUTOLOAD_MODULES}}
else                                          # otherwise just refresh things
    source {BASH_ENV}
    module refresh
fi

# friendly message
echo -e "
* Spack tree initialized using these env vars:
  SPACK_AUTOLOAD_MODULES=\"${{SPACK_AUTOLOAD_MODULES}}\"

* You can export these env vars prior to sourcing this script for more control over your environment.

* Type module avail to see a list of available packages.
"
"""


def setup_spacktree(spack_root, gcc_version, spack_mirror):

    spack_root_abs = path.abspath(path.normpath(spack_root))
    spack_exe = path.join(spack_root_abs, 'bin/spack')

    if path.exists(spack_root_abs):
        logging.info(f'Directory {spack_root_abs} exists, skipping download')
    else:
        makedirs(path.dirname(spack_root_abs), exist_ok=True)
        logging.info('Downloading Spack')
        filepath, result = urllib.request.urlretrieve("https://github.com/spack/spack/archive/develop.zip")
        logging.info('Unzipping Spack')
        with zipfile.ZipFile(filepath, 'r') as zip_ref, tempfile.TemporaryDirectory() as tmp_dir:
            zip_ref.extractall(tmp_dir)
            rename(path.join(tmp_dir, 'spack-develop'), spack_root_abs)

    if spack_mirror is not None:
        logging.info('Configuring local Spack mirror')
        spack_mirror_abs = path.abspath(path.normpath(spack_mirror))
        if not path.exists(spack_mirror_abs):
            logging.info(f'Creating dir {spack_mirror_abs}')
            makedirs(spack_mirror_abs, exist_ok=True)
        with open(path.join(spack_root_abs, 'etc/spack/mirrors.yaml'), 'w') as fh:
            fh.write(MIRRORS_YAML.format(path=spack_mirror_abs))

    logging.info('Configuring Modules')
    with open(path.join(spack_root_abs, 'etc/spack/modules.yaml'), 'w') as fh:
        fh.write(MODULES_YAML.format(gcc_version=gcc_version))

    gcc_string = f'gcc@{gcc_version}'
    logging.info(f'Checking compiler {gcc_string}')
    try:
        subprocess.check_call([sys.executable, spack_exe, 'location', '-i', gcc_string])
    except subprocess.CalledProcessError:
        pass
        logging.info(f'Building compiler {gcc_string}')
        subprocess.check_call([sys.executable, spack_exe, 'compiler', 'find'])
        subprocess.check_call([sys.executable, spack_exe, 'install', '--fail-fast', gcc_string])
        gcc_location, ret = subprocess.check_output([sys.executable, spack_exe, 'location', '-i', gcc_string], universal_newlines=True).strip()
        subprocess.check_call([sys.executable, spack_exe, 'compiler', 'add', '--scope', 'site', gcc_location])

    with open(path.join(SPACKTREE_DIR, 'packages.txt'), 'r') as fh:
        for line in fh.read().splitlines():
            if line.startswith('#'):
                continue
            package_str = line.split()[0]
            logging.info(f'Installing {package_str}')
            subprocess.check_call([sys.executable, spack_exe, 'install', '--fail-fast', package_str])

    logging.info(f'Configuring activate.sh script')
    glob.glob(path.join(spack_root_abs, 'share/spack/lmod/**/Core'))
    # SPACK_LMOD_CORE_DIR=$(find spack/share/spack/lmod -name Core)
    # SPACK_LMOD_MODULES_DIR=$(dirname ${SPACK_LMOD_CORE_DIR})/gcc/${SPACK_GCC_VERSION}    #### PREPOPULATE THIS
    # SPACK_LMOD_INIT_DIR=$(${SPACK_EXE} location -i lmod)/lmod/lmod/init      ######### POPULATE THIS

    with open(path.join(SPACKTREE_DIR, 'activate.sh'), 'w') as fh:
        fh.write(ACTIVATE_SCRIPT.format(SPACK_LMOD_INIT_DIR='', SPACK_LMOD_MODULES_DIR=''))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Set up the spacktree')
    parser.add_argument('--spack_root', '-s', default='./spack', help='path to spack root')
    parser.add_argument('--gcc_version', '-g', default='8.4.0', help='GCC version')
    parser.add_argument('--spack_mirror', '-m', help='path to spack mirror', required=False)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format=LOGGING_FORMAT)

    setup_spacktree(**vars(args))


# # build packages
# for package in $(grep -o '^[^#]*' packages.txt); do
#     echo ">>> Working on ${package}..."
# done
#
# if [[ ! -z ${SPACK_MIRROR:-} && -d ${SPACK_MIRROR:-} ]]; then
#     # copy any new tar.gz files into the mirror, using checksums to determine newness
#     rsync -rvc ${SPACK_ROOT}/var/spack/cache/ ${SPACK_MIRROR}
# fi
#
#
# # echo "-------------- Activating the new spack env --------------"
# # source ${THIS_DIR}/init.sh
#
# # echo "-------------- Getting git-pip.py --------------"
# # wget -O ${THIS_DIR}/get-pip.py https://bootstrap.pypa.io/get-pip.py
#
# # echo "-------------- Setting up pip/pipenv for Python2 --------------"
# # module purge
# # PYTHON2_MOD_NAME=$(module spider python/2.7.18 2>&1 | sed -n '\|python: |s|.*\(python/2.7.18-.*\)|\1|p')
# # module load ${PYTHON2_MOD_NAME}
# # python get-pip.py
# # pip install pipenv
#
# # echo "-------------- Setting up pip/pipenv for Python3 --------------"
# # module purge
# # PYTHON3_MOD_NAME=$(module spider python/3.8.6 2>&1 | sed -n '\|python: |s|.*\(python/3.8.6-.*\)|\1|p')
# # module load ${PYTHON3_MOD_NAME}
# # python get-pip.py
# # pip install pipenv
