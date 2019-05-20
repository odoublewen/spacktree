# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
although this project does not adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [20190128]

### Added

- package `sra-toolkit`

### Changed

- removed `set +u` from ci-wrapper.sh now that https://github.com/spack/spack/pull/10381 is merged

- Added `develop` branch to this repository. 
  - Nightly CI builds 
    ([groovy source](https://github.audentestx.com/bioinformatics/bioinfo_cimr/blob/6867de8ee877faaee2ceb34e0d24465f67aac487/jobs.groovy#L44), 
    [jenkins UI](https://bioinfo.bold.bio/jenkins/bioinformatics/job/bfx_spacktree_develop/)) 
    now build from develop.  Merge to master will (should) trigger a production build 
    ([groovy source](https://github.audentestx.com/bioinformatics/bioinfo_cimr/blob/6867de8ee877faaee2ceb34e0d24465f67aac487/jobs.groovy#L81))
  - See https://github.audentestx.com/bioinformatics/bioinfo_cimr/pull/7

## [20190117]

### Fixed

- `install-packages.sh` rsync command options to allow srv_bioinfo
  user to copy tar files to mirror location
- `gtkplus` now installs with cairo variant `cairo+X+pdf`

### Added

- New spack packages: hugo, git-lfs
- `packrat.lock` file tracks versioned R packages that we use.
- `ci-wrapper.sh` script automates the process of cloning spack,
  building packages, and then installing stuff into python
  (pip/pipenv) and R (packrat.lock) outside of spack.

### Changed

- README file additions and improvements
- `r_environment` moved to git@github.audentestx.com:bioinformatics/r_environment.git
- pinned pcre variant `+jit`
- improvements to ci-wrapper.sh file (provide build path as argument, other tweaks)

## [20190113]

### Added
- Added version specs for key packages in the HEREDOC `packages.yaml` file
- Added 17 packages needed to build R packages outside of spack

## [20181217]

### Added
- Initial release
