* ==============================================================================
* STAGE 1: IMPORT & COMBINE FEDBIZOPS - "SMART SEARCH" VERSION
* ==============================================================================

clear all
set more off

* 1. PATHS
* ------------------------------------------------------------------------------
global root "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"
global raw_folder "$root/raw_data/FedBizOps"
global processed  "$root/processed_data"

* 2. GET LIST OF ALL CSV FILES
* ------------------------------------------------------------------------------
local filelist : dir "$raw_folder" files "*.csv"

* 3. LOOP THROUGH AND APPEND FILES
* ------------------------------------------------------------------------------
tempfile master_data
save `master_data', emptyok

foreach f in `filelist' {
    display "----------------------------------------------------"
    display "Processing File: `f'"
    
    import delimited "$raw_folder/`f'", varnames(1) clear case(preserve)
    
    * --- SMART SEARCH RENAMING ---
    * This loop looks through every variable name in the current file
    foreach v of varlist _all {
        local lowv = lower("`v'") // Convert name to lowercase for checking
        
        * Find the Award Date (looking for "award" AND "date")
        if strpos("`lowv'", "award") > 0 & strpos("`lowv'", "date") > 0 {
            capture rename `v' award_date_str
        }
        
        * Find the Notice ID
        if strpos("`lowv'", "notice") > 0 & strpos("`lowv'", "id") > 0 {
            capture rename `v' notice_id
        }
        
        * Find the Award Number
        if strpos("`lowv'", "award") > 0 & strpos("`lowv'", "number") > 0 {
            capture rename `v' awdnbr
        
		}
		
		* NEW: Find the Agency/Department
        if strpos("`lowv'", "agency") > 0 | strpos("`lowv'", "department") > 0 {
            capture rename `v' agencyname
		}
		
		* FORCE PSC TO LOWERCASE
        if "`lowv'" == "psc" {
            capture rename `v' psc
			
        }
		
		* Find the Set Aside (New, more aggressive search)
        if strpos("`lowv'", "set") > 0 & strpos("`lowv'", "aside") > 0 {
            capture rename `v' typeofsetaside
			
        }
		
		* Find the Pricing (looking for "type" AND "contract" OR "pricing")
        if (strpos("`lowv'", "type") > 0 & strpos("`lowv'", "contract") > 0) | strpos("`lowv'", "pricing") > 0 {
            capture rename `v' pricing
        }
        
        * Find the NAICS (looking for "naics")
        if strpos("`lowv'", "naics") > 0 {
            capture rename `v' naics_text
			
        }
		
    }
    
    * Standardize remaining common fields
    capture rename *Awardee* recipient_name
    capture rename *Set_Aside* typeofsetaside
    capture rename *Contract_Opportunity_T* opportunity_type
    
    * Ensure all variables are strings before appending to avoid crashes
    tostring _all, replace force
    
    append using `master_data'
    save `master_data', replace
}

* 4. DATE CONVERSION & FINAL CLEANUP
* ------------------------------------------------------------------------------
use `master_data', clear

* Diagnostic: Check if we successfully created award_date_str
capture confirm variable award_date_str
if _rc != 0 {
    display as error "CRITICAL: Could not identify an Award Date column."
    display "Available variables are:"
    describe, short
}
else {
    * Convert the date string (e.g., "27-Feb-25" or "Mar 10, 2015")
    * We try multiple formats because SAM.gov is inconsistent
    gen signeddate_date = date(award_date_str, "DMY")
    replace signeddate_date = date(award_date_str, "MDY") if signeddate_date == .
    replace signeddate_date = date(award_date_str, "YMD") if signeddate_date == .
    
    format signeddate_date %td
    gen signeddate_year = year(signeddate_date)
    
    display "SUCCESS: Award dates converted."
}

* 5. SAVE
* ------------------------------------------------------------------------------
compress
save "$processed/DHS_FedBizOps_Combined.dta", replace

display "----------------------------------------------------"
display "STAGE 1 COMPLETE: Data saved to $processed"
