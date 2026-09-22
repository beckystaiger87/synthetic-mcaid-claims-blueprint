# =============================================================================
# NN_<topic>.r — <one-line purpose>
#
# Purpose:  <2-3 lines>
# Inputs:   _output/intermediate/<file>.csv
# Outputs:  _output/diagnostics/calibration/<topic>_<grain>.csv
#
# Generator parameters this recalibrates:
#   synth$<param1>, synth$<param2>
# If this line is empty, ask whether the script belongs in _output/qc/ instead.
#
# RUNS IDENTICALLY LOCALLY AND IN THE ENCLAVE. Do not fork it into two files.
# If behavior must differ, branch on config$env inside this script.
# =============================================================================

t0 <- Sys.time()

source(file.path(.script_dir, "..", "_utils", "config.r"))
source(file.path(config$shared_dir, "R", "suppression.R"))
suppressPackageStartupMessages(library(data.table))

message("\n=== NN_<topic>.r ===")

path <- file.path(config$out_dir, "intermediate", "<file>.csv")
if (!file.exists(path)) {
  stop("[NN_<topic>] <file>.csv not found. Run <prereq> first.", call. = FALSE)
}
dt <- fread(path,
            select     = c(<cols>),
            colClasses = list(character = c(<id_and_code_cols>)))


# ---- Moment 1: <what it measures> -------------------------------------------
# Target: synth$<param1>

m <- dt[<filter>,
        .(n     = uniqueN(<unit>),
          share = <derived>),
        by = .(<group_cols>)]

write_diagnostic(m, "<topic>_<grain>", "calibration",
                 out_dir    = config$out_dir,
                 count_col  = "n",
                 value_cols = "share",        # every derived column, or it leaks
                 group_cols = c("<suppression_grouping>"))


# ---- Moment 2: ... -----------------------------------------------------------


message(sprintf("[NN_<topic>] done in %.1fs",
                as.numeric(Sys.time() - t0, units = "secs")))
