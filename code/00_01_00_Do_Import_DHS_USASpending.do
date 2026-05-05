* ==============================================================================
* STAGE 1: IMPORT, FIX LONG NAMES, AND MAP TO AER FORMAT
* Project: Econometrics Replication (Carril, Gonzalez-Lira, and Walker 2026)
* ==============================================================================

clear all
set more off

* 1. SET PROJECT ROOT & GLOBALS
* ------------------------------------------------------------------------------
global root "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"

global code           "$root/code"
global images         "$root/images"
global processed_data "$root/processed_data"
global raw_data       "$root/raw_data"
global results        "$root/results"

* 2. CREATE FOLDERS (if they don't exist)
* ------------------------------------------------------------------------------
foreach dir in "$code" "$images" "$processed_data" "$raw_data" "$results" {
    capture confirm file "`dir'/nul"
    if _rc != 0 shell mkdir "`dir'"
}

* 3. IMPORT THE SPECIFIC DHS CSV
* ------------------------------------------------------------------------------
global dhs_csv "$raw_data/2015-2019_DHS_10-40k/Contracts_PrimeTransactions_2026-03-24_H19M21S45_1.csv"

* We use 'case(preserve)' to help match the renaming logic below
import delimited "$dhs_csv", varnames(1) case(preserve) clear

* 4. MAPPING: RENAME DHS VARIABLES TO AER FORMAT
* ------------------------------------------------------------------------------
* Identification
rename award_id_piid          awdnbr
rename awarding_agency_name   agencyname
rename awarding_sub_agency_name subagencyname

* Firm & Location (Using wildcards to bypass the 32-character limit)
rename recipient_duns         duns
rename recipient_state_code   firmstate
capture rename primary_place_of_performance_s* popstate
capture rename primary_place_of_performance_c* popcountry
capture rename primary_place_of_performance_z* popzip

* Contract Characteristics
rename type_of_contract_pricing_code pricing
rename product_or_service_code       psc
rename naics_code                    naics
rename number_of_offers_received     noffers

* 5. DATE CONVERSION
* ------------------------------------------------------------------------------
* Note: USAspending CSVs often use YYYY-MM-DD. We use 'YMD' mask.
gen temp_date = date(action_date, "YMD")
format temp_date %td
gen signeddate_year = year(temp_date)
rename temp_date signeddate_date

gen startdate = date(period_of_performance_start_date, "YMD")
format startdate %td

* 6. FINANCIALS
* ------------------------------------------------------------------------------
rename federal_action_obligation amount_initial
rename total_dollars_obligated   amount_total

* 7. BUSINESS SIZE LOGIC
* ------------------------------------------------------------------------------
* Handling the extremely long "contracting_officers_determination..." variable
capture rename contracting_officers_determina* bus_size_raw
gen business_size = ""
replace business_size = "SMALL BUSINESS" if bus_size_raw == "S"
replace business_size = "OTHER THAN SMALL" if bus_size_raw == "O"

* 8. SAVE TO PROCESSED FOLDER
* ------------------------------------------------------------------------------
compress
save "$processed_data/DHS_mapped_cleaned.dta", replace

display "SUCCESS: Data imported and mapped. Ready for Stage 2 analysis."
