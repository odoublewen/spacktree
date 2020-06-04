# uses renv to restore the environment that was originally created as follows:
# install.packages('renv', repos = "https://cran.rstudio.com")
# install.packages(c('tidyverse', 'plyr', 'reshape', 'reshape2', 'Seurat', 'BiocManager', 'devtools'))
# devtools::install_version("foreign", version='0.8-76')
# install.packages("Hmisc")
# BiocManager::install(c("GenomicFeatures", 'DESeq2', 'Rsamtools', 'biomaRt', 'GenomicAlignments'))

install.packages('renv', repos = "https://cran.rstudio.com")
renv::restore()
