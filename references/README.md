# References

Every external source the generator depends on, what it is used for, and where to get the current version.

**Nothing in this folder is authoritative.** These are dated copies, kept so the code here runs without a download and so a reader can see exactly what it was built against. CMS revises all of them. When a current layout and anything in this repository disagree, **the layout wins**.

---

## Included here

| File | Used for | Source | Copy dated |
|---|---|---|---|
| `max-taf-availability-matrix.xlsx` | Which era (MAX / MAX-T / TAF) covers each state-year | [CMS](https://www.cms.gov/data-research/computer-data-systems/medicaid-data-sources-general-information/medicaid-analytic-extract-max-general-information) — "MAX TAF Availability Matrix (ZIP)" | 2025-12 |
| `ccw_availability.csv` | Machine-readable extract of the above, as a flat state-year table | derived here | — |
| `record-layout-taf-claims.xlsx` | TAF claim layouts, one sheet each: **IP, LT, OT, RX** (+ revision log) | [CCW](https://www2.ccwdata.org/web/guest/data-dictionaries) | 2025-12 |
| `record-layout-taf-demographic-eligibility.xlsx` | TAF DE, one sheet per subsegment: **Base, Dates, Managed Care, Waiver, MFP, Health Home, Disability & Need**. Monthly and slot×month families live here. | [CCW](https://www2.ccwdata.org/web/guest/data-dictionaries) | 2025-12 |
| `record-layout-max.xlsx` | MAX layouts, one sheet each: **PS, IP, LT, OT, RX**. Includes the three provider-id columns on OT. | [CCW](https://www2.ccwdata.org/web/guest/data-dictionaries) | 2019-12 |

**Three workbooks, not three file types.** The split is how ResDAC packages the layouts, not a taxonomy of the data. Each source has five analytic file types — person/eligibility, IP, LT, OT, RX — plus ancillary files. MAX ships all five in one workbook; TAF splits the claim files from demographic-eligibility, and subdivides DE further into seven subsegments that are separate files on the VRDC.

**`R/ccw_columns.R` omits LT.** The registry is an illustrative subset covering DE/PS, IP, OT, and RX. Long-term care is in both layout workbooks and is not in the registry — if your analysis touches institutional or waiver LTC, add the concepts yourself from the LT sheet. The same applies to the DE subsegments beyond Base and Managed Care.

## Linked, not copied

Deliberately not vendored — too large, revised often, or distributed to credentialed users:

| Source | Used for | Where |
|---|---|---|
| **DQ Atlas** | Injection rates in `R/dq_inject.R`; which state-years are unusable for which measures | [medicaid.gov/dq-atlas](https://www.medicaid.gov/dq-atlas/) |
| TAF / MAX codebooks | Value sets and field definitions behind the layouts | [ResDAC](https://resdac.org/) |
| CCW VRDC user guides | Enclave operations — not a generator input | CCW, to credentialed users |

---

## `ccw_availability.csv`

Extracted from the workbook's two sheets and reshaped long. **796 state-year rows, 58 states and territories, 2010–2023.** The workbook's "2017 and later years" column is expanded through 2023.

```
state_name,state_cd,fips,first_tmsis_submission,year,data_source
Alaska,AK,02,2013-10-01,2010,MAX
```

`data_source` takes four values:

| Value | Meaning | File format |
|---|---|---|
| `MAX` | Medicaid Analytic eXtract, built from MSIS | MAX |
| `MAX-T` | MAX-format file built from T-MSIS during the transition | MAX |
| `TAF` | T-MSIS Analytic File | TAF |
| `N/A` | No Medicaid data for that state-year | — |

**`MAX-T` is a MAX-format file, not a third format.** Map both `MAX` and `MAX-T` to the MAX reader while keeping the distinction in the table, because the provenance matters for data-quality expectations even though the layout does not differ.

**`N/A` is not zero and not missing-at-random.** It means the state has no usable data that year. `era_for()` raises on it rather than returning a default, because generating or reading a file for a state-year that has no data is a mistake the pipeline would otherwise analyze without complaint.

The spread is the whole point — states crossed to TAF anywhere from 2014 to 2016, and some sat on MAX-T through 2015. There is **no national cutover date**.

---

## Regenerating the CSV

If CMS publishes a revised matrix, download it from the [MAX general information page](https://www.cms.gov/data-research/computer-data-systems/medicaid-data-sources-general-information/medicaid-analytic-extract-max-general-information) (link text: *MAX TAF Availability Matrix (ZIP)*), drop the new workbook in and re-run:

```bash
Rscript references/build_availability.R
```
