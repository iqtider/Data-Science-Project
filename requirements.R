# CSC 3220 Team 8 - R Package Requirements

required_packages <- c(
  "tidyverse",
  "tidymodels",
  "kknn",
  "rpart",
  "ranger",
  "LiblineaR"
)

# Use the user's R package library on Windows
r_minor <- strsplit(
  R.version$minor,
  "\\."
)[[1]][1]

r_version <- paste0(
  R.version$major,
  ".",
  r_minor
)

if (.Platform$OS.type == "windows") {

  user_lib <- file.path(
    Sys.getenv("LOCALAPPDATA"),
    "R",
    "win-library",
    r_version
  )

  dir.create(
    user_lib,
    recursive = TRUE,
    showWarnings = FALSE
  )

  .libPaths(
    c(
      user_lib,
      .libPaths()
    )
  )
}

# Check for missing packages
missing_packages <- required_packages[
  !required_packages %in% rownames(
    installed.packages()
  )
]

# Install any packages that are missing
if (length(missing_packages) > 0) {

  install.packages(
    missing_packages,
    repos = "https://cloud.r-project.org",
    lib = .libPaths()[1]
  )
}

cat("\nRequired project packages are installed.\n")
cat("R Version:", R.version.string, "\n")
cat("Package Library:", .libPaths()[1], "\n")