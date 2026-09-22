# =============================================================================
# ccw_columns.R — Canonical CCW column-name registry, TAF and MAX
#
# ONE source of truth for real-data column names, sourced by BOTH the synthetic
# generator and the analysis pipeline. Neither ever hardcodes a column name.
#
# Structure:  CCW$<era>$<file>$<segment>$<concept>  ->  "REAL_SAS_NAME"
#   <era>      "TAF" (2014+) or "MAX" (through ~2014, last year varies by state)
#   <file>     "DE"/"PS", "OT", "IP", "RX"
#   <segment>  "BASE"/"MNGD_CARE" (TAF DE) or "HEADER"/"LINE" (TAF claims).
#              MAX files are FLAT — no segment level.
#   <concept>  a project-friendly snake_case key whose VALUE is the SAS name.
#
# ---------------------------------------------------------------------------
# THE POINT OF THIS FILE: CONCEPT KEYS ARE STABLE ACROSS ERAS.
#
#   CCW$TAF$OT$HEADER$clm_type_cd  ->  "CLM_TYPE_CD"
#   CCW$MAX$OT$clm_type_cd         ->  "TYPE_CLM_CD"      <- note the swap
#
# Same concept, same key, different SAS name. Downstream code asks for the
# CONCEPT and never branches on era. Without this, every script that touches
# both eras grows an `if (era == "max")` and they drift apart one by one.
#
# Where the eras differ in STRUCTURE rather than naming — MAX claims are flat,
# TAF claims are header+line — the difference is absorbed in the reader, not
# here. SYNTHETIC-DATA-BLUEPRINT.md §7 states the contract that reader has to
# satisfy.
# ---------------------------------------------------------------------------
#
# THIS FILE IS AN ILLUSTRATION, NOT A DATA DICTIONARY.
#
# A deliberately small subset — enough to show the pattern. It is NOT authoritative and it WILL drift from the real layouts.
# Get the current ones from the CCW data dictionaries (public, no login):
#   https://www2.ccwdata.org/web/guest/data-dictionaries
# When the layout and this file disagree, THE LAYOUT WINS.
# =============================================================================

# How many managed-care slots the TAF registry declares. Real TAF DE has 16;
# slots 5-16 are almost always empty, so 4 is the usual working choice.
N_MC_SLOTS <- 4L

CCW <- list(

  # ===========================================================================
  # TAF — T-MSIS Analytic Files (2014+)
  # ===========================================================================
  TAF = list(

    # --- Demographic-Eligibility -------------------------------------------
    # On VRDC, TAF DE is split across several subsegment files (base, dates,
    # disability, household, managed care, waiver). Generate the segments you
    # actually read, under the real split.
    DE = list(
      BASE = list(
        bene_id      = "BENE_ID",
        msis_id      = "MSIS_ID",
        state_cd     = "STATE_CD",            # 2-char ALPHA in real TAF
        birth_dt     = "BIRTH_DT",
        death_dt     = "DEATH_DT",
        sex_cd       = "SEX_CD",
        race_cd      = "RACE_ETHNCTY_CD",
        elg_grp_ltst = "ELGBLTY_GRP_CD_LTST"
        # + monthly families appended below, ZERO-PADDED: <FAM>_01 .. _12
      ),
      MNGD_CARE = list(
        bene_id  = "BENE_ID",
        msis_id  = "MSIS_ID",
        state_cd = "STATE_CD"
        # + MC_PLAN_ID_<SS>_<MM> / MC_PLAN_TYPE_CD_<SS>_<MM>, appended below
      )
    ),

    # --- Other Services: HEADER + LINE -------------------------------------
    OT = list(
      HEADER = list(
        bene_id          = "BENE_ID",
        msis_id          = "MSIS_ID",
        state_cd         = "STATE_CD",
        clm_id           = "CLM_ID",
        clm_type_cd      = "CLM_TYPE_CD",      # cf. MAX "TYPE_CLM_CD"
        srvc_bgn_dt      = "SRVC_BGN_DT",
        srvc_end_dt      = "SRVC_END_DT",
        billing_npi      = "BLG_PRVDR_NPI",    # MAX has NO billing NPI
        billing_taxonomy = "BLG_PRVDR_TXNMY_CD",
        plan_id          = "MC_PLAN_ID",       # cf. MAX "PHP_ID"
        place_of_service = "POS_CD",           # cf. MAX "PLC_OF_SRVC_CD"
        paid_amount      = "MDCD_PD_AMT",      # cf. MAX "MDCD_PYMT_AMT"
        diag_1           = "DGNS_CD_1"         # cf. MAX "DIAG_CD_1"
      ),
      LINE = list(
        bene_id       = "BENE_ID",
        msis_id       = "MSIS_ID",
        clm_id        = "CLM_ID",
        line_num      = "LINE_NUM",
        servicing_npi = "SRVC_PRVDR_NPI",      # LINE-level in TAF
        servicing_lpi = "SRVC_PRVDR_ID",
        proc_cd       = "LINE_PRCDR_CD",
        proc_cd_sys   = "LINE_PRCDR_CD_SYS",
        rev_cd        = "REV_CNTR_CD",
        line_paid     = "LINE_MDCD_PD_AMT"
      )
    ),

    IP = list(
      HEADER = list(
        bene_id          = "BENE_ID",
        msis_id          = "MSIS_ID",
        state_cd         = "STATE_CD",
        clm_id           = "CLM_ID",
        clm_type_cd      = "CLM_TYPE_CD",
        admsn_dt         = "ADMSN_DT",
        srvc_bgn_dt      = "SRVC_BGN_DT",
        srvc_end_dt      = "SRVC_END_DT",
        dschrg_dt        = "DSCHRG_DT",        # MAX IP has NO discharge date
        billing_npi      = "BLG_PRVDR_NPI",
        admitting_npi    = "ADMTG_PRVDR_NPI",
        drg_cd           = "DRG_CD",
        discharge_status = "PTNT_DSCHRG_STUS_CD",
        paid_amount      = "MDCD_PD_AMT"
      ),
      LINE = list(
        clm_id        = "CLM_ID",
        line_num      = "LINE_NUM",
        rev_cd        = "REV_CNTR_CD",
        servicing_npi = "SRVC_PRVDR_NPI"
      )
    ),

    RX = list(
      LINE = list(
        bene_id     = "BENE_ID",
        msis_id     = "MSIS_ID",
        state_cd    = "STATE_CD",
        clm_id      = "CLM_ID",
        fill_dt     = "RX_FILL_DT",            # cf. MAX "PRSCRPTN_FILL_DT"
        ndc         = "NDC",                   # 11-char TAF, 13-char MAX
        days_supply = "DAYS_SUPPLY"
      )
    )
  ),

  # ===========================================================================
  # MAX — Medicaid Analytic eXtract (through ~2014; last year varies by state)
  #
  # THREE STRUCTURAL DIFFERENCES from TAF, none of them naming:
  #   1. Claim files are FLAT. No header/line split, no CLM_ID join.
  #   2. STATE_CD is numeric FIPS ("06"), not alpha ("CA").
  #   3. Monthly columns are UNPADDED: MAX_ELG_CD_MO_1 .. _12, not _01 .. _12.
  # All three are absorbed in read_data(), so downstream sees one convention.
  # ===========================================================================
  MAX = list(

    # --- Person Summary (the MAX analogue of TAF DE) -----------------------
    PS = list(
      bene_id      = "BENE_ID",
      msis_id      = "MSIS_ID",
      state_cd     = "STATE_CD",               # numeric FIPS in real MAX
      birth_dt     = "EL_DOB",
      death_dt     = "EL_DOD",
      sex_cd       = "EL_SEX_CD",
      race_cd      = "EL_RACE_ETHNCY_CD",
      elg_grp_ltst = "EL_MAX_ELGBLTY_CD_LTST"
      # + monthly families appended below, UNPADDED: <FAM>_1 .. _12
    ),

    # --- Other Services: FLAT ----------------------------------------------
    OT = list(
      bene_id          = "BENE_ID",
      msis_id          = "MSIS_ID",
      state_cd         = "STATE_CD",
      yr_num           = "YR_NUM",
      clm_type_cd      = "TYPE_CLM_CD",        # cf. TAF "CLM_TYPE_CD"
      srvc_bgn_dt      = "SRVC_BGN_DT",
      srvc_end_dt      = "SRVC_END_DT",
      plan_id          = "PHP_ID",             # cf. TAF "MC_PLAN_ID"
      place_of_service = "PLC_OF_SRVC_CD",     # cf. TAF "POS_CD"
      paid_amount      = "MDCD_PYMT_AMT",      # cf. TAF "MDCD_PD_AMT"
      diag_1           = "DIAG_CD_1",          # cf. TAF "DGNS_CD_1"
      proc_cd          = "PRCDR_CD",
      proc_cd_sys      = "PRCDR_CD_SYS",
      max_tos          = "MAX_TOS",            # MAX-only: type of service

      # ---------------------------------------------------------------------
      # PROVIDER IDS ON MAX OT — read this before using any of them.
      #
      # There is NO billing-side NPI on MAX. There are three provider columns
      # and they are easy to mis-read:
      #
      #   billing_lpi    PRVDR_ID_NMBR       state-assigned id of the BILLING
      #                                      provider. Not an NPI.
      #   servicing_npi  NPI                 NPI of the provider who TREATED
      #                                      the patient, as opposed to the one
      #                                      who billed. 9-filled 2005-2008;
      #                                      populated from 2009 with wide
      #                                      state variation in fill rate.
      #   servicing_lpi  SRVC_PRVDR_ID_NMBR  state-assigned id for the SAME
      #                                      servicing role. Needs an LPI->NPI
      #                                      crosswalk to resolve.
      #
      # The two servicing paths cover one role — code that wants servicing
      # providers takes the direct NPI where present and falls back to the
      # crosswalked LPI. There is deliberately NO billing_npi key here, so that
      # asking for one raises rather than silently handing back a state-assigned
      # id that is not an NPI. See concept() at the bottom of this file.
      # ---------------------------------------------------------------------
      billing_lpi   = "PRVDR_ID_NMBR",
      servicing_npi = "NPI",
      servicing_lpi = "SRVC_PRVDR_ID_NMBR"
    ),

    IP = list(
      bene_id       = "BENE_ID",
      msis_id       = "MSIS_ID",
      state_cd      = "STATE_CD",
      yr_num        = "YR_NUM",
      clm_type_cd   = "TYPE_CLM_CD",
      admsn_dt      = "ADMSN_DT",
      srvc_bgn_dt   = "SRVC_BGN_DT",
      srvc_end_dt   = "SRVC_END_DT",
      # NO dschrg_dt key: MAX IP is flat and carries no discharge date, so the
      # cleaner's DSCHRG_DT -> SRVC_END_DT fallback is implicit for this era.
      billing_lpi   = "PRVDR_ID_NMBR",
      servicing_npi = "NPI",
      paid_amount   = "MDCD_PYMT_AMT"
    ),

    RX = list(
      bene_id     = "BENE_ID",
      msis_id     = "MSIS_ID",
      state_cd    = "STATE_CD",
      fill_dt     = "PRSCRPTN_FILL_DT",        # cf. TAF "RX_FILL_DT"
      ndc         = "NDC",                     # 13-char MAX, 11-char TAF
      days_supply = "DAYS_SUPPLY"
    )
  )
)


# --- Append the wide monthly / slot families ---------------------------------
# Generated in loops rather than typed out, so the counts are right by
# construction. The two eras use DIFFERENT suffix conventions, which is exactly
# the sort of thing that is invisible until it silently matches nothing.

local({
  mm_padded   <- sprintf("%02d", 1:12)   # TAF: _01 .. _12
  mm_unpadded <- as.character(1:12)      # MAX: _1  .. _12

  # TAF DE BASE — four monthly families, zero-padded
  for (fam in c("ELGBLTY_GRP_CD", "DUAL_ELGBL_CD", "CHIP_CD", "RSTRCTD_BNFTS_CD")) {
    for (m in mm_padded) {
      CCW$TAF$DE$BASE[[paste0(tolower(fam), "_", m)]] <<- paste0(fam, "_", m)
    }
  }

  # TAF DE MNGD_CARE — slot x month grid
  for (ss in sprintf("%02d", 1:N_MC_SLOTS)) {
    for (m in mm_padded) {
      CCW$TAF$DE$MNGD_CARE[[paste0("mc_plan_id_", ss, "_", m)]] <<-
        paste0("MC_PLAN_ID_", ss, "_", m)
      CCW$TAF$DE$MNGD_CARE[[paste0("mc_plan_type_cd_", ss, "_", m)]] <<-
        paste0("MC_PLAN_TYPE_CD_", ss, "_", m)
    }
  }

  # MAX PS — the same four concepts plus a plan id, UNPADDED, under MAX's names.
  # CONCEPT KEYS ARE ZERO-PADDED IN BOTH ERAS (elgblty_grp_cd_03) even though
  # the MAX SAS name is not. The key is the stable interface; the SAS name is
  # the thing that varies. A consumer asks for month 3 without knowing the era.
  max_fams <- c(elgblty_grp_cd   = "MAX_ELG_CD_MO",
                dual_elgbl_cd    = "EL_MDCR_DUAL_MO",
                chip_cd          = "EL_CHIP_FLG_MO",
                rstrctd_bnfts_cd = "EL_RSTRCT_BNFT_FLG_MO",
                mc_plan_id       = "EL_PHP_ID")
  for (i in seq_along(max_fams)) {
    key <- names(max_fams)[i]
    sas <- max_fams[[i]]
    for (m in seq_len(12L)) {
      CCW$MAX$PS[[paste0(key, "_", mm_padded[m])]] <<-
        paste0(sas, "_", mm_unpadded[m])
    }
  }

  # Diagnosis slots
  for (i in 1:5) CCW$TAF$IP$HEADER[[paste0("diag_", i)]] <<- paste0("DGNS_CD_", i)
  for (i in 2:5) CCW$MAX$IP[[paste0("diag_", i)]]        <<- paste0("DIAG_CD_", i)
  CCW$MAX$IP$diag_1 <<- "DIAG_CD_1"
})


# ---------------------------------------------------------------------------
# concept() — look up a SAS name by era and concept, and fail loudly.
#
#   concept("TAF", "OT", "clm_type_cd", "HEADER")  -> "CLM_TYPE_CD"
#   concept("MAX", "OT", "clm_type_cd")            -> "TYPE_CLM_CD"
#   concept("MAX", "OT", "billing_npi")            -> ERROR
#
# The last case is the one that matters. MAX has no billing-side NPI, so asking
# for one is a bug in the caller. Raising here stops the run at the point of the
# mistake; returning NULL would propagate as a missing column three steps later,
# or worse, as a column quietly dropped from a select.
# ---------------------------------------------------------------------------
concept <- function(era, file, key, segment = NULL) {
  node <- CCW[[era]][[file]]
  if (is.null(node)) {
    stop(sprintf("[ccw] no file '%s' in era '%s'", file, era), call. = FALSE)
  }
  if (!is.null(segment)) node <- node[[segment]]
  val <- node[[key]]
  if (is.null(val)) {
    stop(sprintf(paste0("[ccw] concept '%s' does not exist in %s %s%s. ",
                        "Check the record layout — this may be a concept that ",
                        "era genuinely does not have."),
                 key, era, file,
                 if (is.null(segment)) "" else paste0(" ", segment)),
         call. = FALSE)
  }
  val
}


# ---------------------------------------------------------------------------
# concepts() — vector form, for building a projection list.
#   concepts("MAX", "OT", c("bene_id", "srvc_bgn_dt", "servicing_npi"))
# ---------------------------------------------------------------------------
concepts <- function(era, file, keys, segment = NULL) {
  vapply(keys, function(k) concept(era, file, k, segment), character(1),
         USE.NAMES = FALSE)
}
