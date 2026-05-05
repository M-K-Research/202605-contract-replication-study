* ==============================================================================
* BRIDGE SCRIPT: MERGE DHS CONTRACTS WITH FEDBIZOPS NOTICES 
* Adapted from: Carril, Gonzalez-Lira, and Walker (2026) - Script 06
* Written with Google Gemini
* ==============================================================================

clear all
set more off

* 1. SET PATHS
global root "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"
global processed "$root/processed_data"
global temp      "$processed/temp"

* 2. PREPARE THE "USING" (NOTICE) DATA
use "$processed/DHS_FedBizOps_Combined.dta", clear
capture gen agencyname = "DEPARTMENT OF HOMELAND SECURITY"

* Clean IDs in the Notice data
capture rename notice_id solnbr
egen solnbr_clean = sieve(solnbr), keep(a n)
replace solnbr_clean = upper(solnbr_clean)
egen awdnbr_clean = sieve(awdnbr), keep(a n)
replace awdnbr_clean = upper(awdnbr_clean)

sort solnbr_clean signeddate_date
egen i = seq(), by(solnbr_clean)
keep if i == 1
save "$temp/dhs_notices_by_solnbr.dta", replace

* Create unique award version
drop if missing(awdnbr_clean)
sort awdnbr_clean signeddate_date
egen j = seq(), by(awdnbr_clean)
keep if j == 1
save "$temp/dhs_notices_by_awdnbr.dta", replace

* 3. PREPARE THE "MASTER" (CONTRACT) DATA & MERGE
* ------------------------------------------------------------------------------
use "$processed/DHS_mapped_cleaned.dta", clear

* CRITICAL FIX: Clean the IDs in the Master file so they match the Sieve format
capture rename solicitation_identifier solnbr
egen solnbr_clean = sieve(solnbr), keep(a n)
replace solnbr_clean = upper(solnbr_clean)

egen awdnbr_clean = sieve(awdnbr), keep(a n)
replace awdnbr_clean = upper(awdnbr_clean)

* PASS A: Merge by Cleaned Solicitation ID
merge m:1 solnbr_clean using "$temp/dhs_notices_by_solnbr.dta", keep(master match)
rename _merge merge_sol

* PASS B: Merge by Cleaned Award ID
* Removed 'nogen' so we can create merge_awd
merge m:1 awdnbr_clean using "$temp/dhs_notices_by_awdnbr.dta", update replace keep(master match)
rename _merge merge_awd

* 4. FINAL FLAG & SAVE
* ------------------------------------------------------------------------------
gen fbo_merge_any = (merge_sol == 3 | merge_awd == 3 | merge_awd == 4)

save "$processed/dcDHS1519fbo.dta", replace

display "SUCCESS: Integrated DHS file created: dcDHS1519fbo.dta"
