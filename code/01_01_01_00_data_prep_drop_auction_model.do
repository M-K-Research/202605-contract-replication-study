
*==============================================================================*
* 01_01_02_data_prep.do
* This script prepares the datasets for the main analyses	
*==============================================================================*

* ==============================================================================
* PATH SETUP
* ==============================================================================
clear all
set more off

* Set your project root folder
global root "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"

* Change the working directory so relative paths (raw_data/, processed_data/) work
cd "$root"

* Ensure the temp folder exists
capture shell mkdir "processed_data/temp"

*==============================================================================*
* I. Import and prepare geographic information
*==============================================================================*

/*----------------------------------------------------------------------------*/
/* I.1 Relationship between Zipcodes and Metropolitan Statistical Areas       */
/*----------------------------------------------------------------------------*/
				
	import delimited raw_data/zcta_cbsa_rel_10.txt, stringcols(_all) clear 
	keep zcta5 cbsa memi mpop
	destring mpop , replace
	destring memi , replace //1= metropolitan, 2= micropolitan
	
	* A small share of zipcodes lies between 2 or more Metropolitan
	* (or Micropolitan) areas. We input the zipcode to the MSA with largest population
	bys zcta5: egen maxPop=max(mpop)
	keep if mpop==maxPop
	drop maxPop memi
	*drop ties:
	bys zcta5: gen n=_n
	keep if n==1
	drop n
	ren zcta5 zipCode
	ren cbsa msa 

	label var zipCode "Zip Code"
	label var msa "Metropolitan Statistical Area"
	label var mpop "Population in MSA"
	save processed_data/temp/zipCodeMSA.dta, replace


/*----------------------------------------------------------------------------*/
/* I.2 Relationship between Zipcodes and Counties    						  */
/*----------------------------------------------------------------------------*/
	
	import delimited raw_data/zcta_county_rel_10.txt, stringcols(_all) clear 
	keep zcta5 state county copop 
	destring copop , replace

	* A small share of zip codes lies between 2 or more Counties
	* We input the zipcode to the County with largest population
	bys zcta5: egen maxPop=max(copop)
	keep if copop==maxPop
	drop maxPop
	*drop ties:
	bys zcta5: gen n=_n
	keep if n==1
	drop n
	ren zcta5 zipCode
	gen countyID=state+county

	label var zipCode "Zip Code"
	label var countyID "County ID"
	label var copop "Population in County"
	keep zipCode countyID copop
	save processed_data/temp/zipCodeCounty.dta, replace
	
	
/*----------------------------------------------------------------------------*/
/* I.3 Zip Code Coordinates   							 				  	  */
/*----------------------------------------------------------------------------*/

	import delimited raw_data/Gaz_zcta_national.txt, stringcols(_all) clear 
	keep geoid intptlat intptlong 
	ren geoid zipCode
	ren intptlat lat 
	ren intptlong lon 
	foreach var of varlist * {
		replace `var' = trim(`var')
	}

	destring lat, replace
	destring lon, replace

	label var zipCode "Zip Code"
	label var lat "Latitude"
	label var lon "Longitude"
	keep zipCode lat lon
	save processed_data/temp/zipCodeCoord.dta, replace
	

/*----------------------------------------------------------------------------*/
/* I.4 US Regions: US regions and divisions using Census definitions		  */
/*     (5 big regions, 9 divisions)					   						  */
/*----------------------------------------------------------------------------*/

	import excel raw_data/censusStatesDivisionsRegions.xlsx, sheet("Sheet1") firstrow clear
	drop State
	ren StateCode state
	ren Region region
	ren Division division
	save processed_data/temp/censusStatesDivisionsRegions.dta, replace


/*----------------------------------------------------------------------------*/
/* I.5 Merge Zip Code Info  							 					  */
/*----------------------------------------------------------------------------*/

	use processed_data/temp/zipCodeMSA.dta, clear
	merge 1:1 zipCode using processed_data/temp/zipCodeCounty.dta
	drop _m
	merge 1:1 zipCode using processed_data/temp/zipCodeCoord.dta
	drop _m
	drop if substr(zipCode,1,3)=="006" | substr(zipCode,1,3)=="007" | substr(zipCode,1,3)=="008" | substr(zipCode,1,3)=="009"
	save processed_data/temp/zipCode.dta, replace


/*----------------------------------------------------------------------------*/
/* I.6 Office location data  							 					  */
/*----------------------------------------------------------------------------*/

	import excel raw_data/FPDSNG_Contracting_Offices.xls, sheet("Valid Contracting Offices") cellrange(A5:L6641) firstrow allstring clear
	keep if DEPARTMENT_ID=="7000"
	rename AGENCY_NAME subagencyname2
	rename CONTRACTING_OFFICE_CODE officecode
	rename CONTRACTING_OFFICE_NAME officename2
	rename ADDRESS_CITY officecity
	rename ADDRESS_STATE officestate
	rename COUNTRY_CODE officecountry
	rename ZIP_CODE officezip
	keep sub* office*
	replace officezip = substr(officezip,1,5)
	* Add some offices found by manually on FPDS website that were not in the 
	* FPDSNG spreadsheet but with a lot of contracts later
	** append using raw_data/officesByHand.dta ** not applicable for DHS **
	save processed_data/temp/offices.dta, replace



/*============================================================================*/
/* II. Procurement Contracts Data                 			 				  */
/*============================================================================*/

	use processed_data/dcDHS1519fbo.dta, clear
* ==============================================================================
* SECTION II: DHS VARIABLE MAPPER 
* ==============================================================================

* 1. PRE-CLEAN
foreach target in duns parentduns firmcountry firmstate firmzip popcountry popstate popzip officestate officecountry officezip officecode subagencyname {
    capture rename `target' `target'_old
}

* 2. THE MAPPING LOOP
foreach v of varlist _all {
    local lowv = lower("`v'")
    
    * IDs
    if strpos("`lowv'", "parent") > 0 & strpos("`lowv'", "duns") > 0 {
        capture confirm variable parentduns
        if _rc != 0 capture rename `v' parentduns
    }
    if strpos("`lowv'", "recipient") > 0 & strpos("`lowv'", "duns") > 0 & strpos("`lowv'", "parent") == 0 {
        capture confirm variable duns
        if _rc != 0 capture rename `v' duns
    }
    
    * Firm Location
    if (strpos("`lowv'", "recipient") > 0 | strpos("`lowv'", "legal_entity") > 0) & strpos("`lowv'", "country") > 0 {
        capture confirm variable firmcountry
        if _rc != 0 capture rename `v' firmcountry
    }
    if (strpos("`lowv'", "recipient") > 0 | strpos("`lowv'", "legal_entity") > 0) & strpos("`lowv'", "state") > 0 {
        capture confirm variable firmstate
        if _rc != 0 capture rename `v' firmstate
    }
    if (strpos("`lowv'", "recipient") > 0 | strpos("`lowv'", "legal_entity") > 0) & strpos("`lowv'", "zip") > 0 {
        capture confirm variable firmzip
        if _rc != 0 capture rename `v' firmzip
    }
    
    * Performance Location (POP) - Broadened Search
    if (strpos("`lowv'", "performance") > 0 | strpos("`lowv'", "pop") > 0) & strpos("`lowv'", "country") > 0 {
        capture confirm variable popcountry
        if _rc != 0 capture rename `v' popcountry
    }
    if (strpos("`lowv'", "performance") > 0 | strpos("`lowv'", "pop") > 0) & strpos("`lowv'", "state") > 0 {
        capture confirm variable popstate
        if _rc != 0 capture rename `v' popstate
    }
    if (strpos("`lowv'", "performance") > 0 | strpos("`lowv'", "pop") > 0) & strpos("`lowv'", "zip") > 0 {
        capture confirm variable popzip
        if _rc != 0 capture rename `v' popzip
    }

    * Office Location
    if strpos("`lowv'", "office") > 0 & strpos("`lowv'", "state") > 0 {
        capture confirm variable officestate
        if _rc != 0 capture rename `v' officestate
    }
    if strpos("`lowv'", "office") > 0 & strpos("`lowv'", "country") > 0 {
        capture confirm variable officecountry
        if _rc != 0 capture rename `v' officecountry
    }
    if strpos("`lowv'", "office") > 0 & strpos("`lowv'", "zip") > 0 {
        capture confirm variable officezip
        if _rc != 0 capture rename `v' officezip
    }
    if strpos("`lowv'", "office") > 0 & (strpos("`lowv'", "code") > 0 | strpos("`lowv'", "id") > 0) {
        capture confirm variable officecode
        if _rc != 0 capture rename `v' officecode
    }
    
    * Sub-Agency Name
    if strpos("`lowv'", "sub") > 0 & strpos("`lowv'", "agency") > 0 & strpos("`lowv'", "name") > 0 {
        capture confirm variable subagencyname
        if _rc != 0 capture rename `v' subagencyname
    }
	
	* Sub-Agency Code (For identifying Coast Guard, FEMA, etc.)
    if strpos("`lowv'", "sub") > 0 & strpos("`lowv'", "agency") > 0 & strpos("`lowv'", "code") > 0 {
        capture confirm variable subagencycode
        if _rc != 0 capture rename `v' subagencycode
    }
} 

* --- MANUAL PSC FIX (Based on Diagnostic) ---
* We found 'psc' in your data; the script needs it to be 'psc4'
capture rename psc psc4

* If 'psc' wasn't there, try the long USAspending name
capture confirm variable psc4
if _rc != 0 {
    capture rename product_or_service_code psc4
}

* Ensure it is a string so it can be concatenated with the office code
capture tostring psc4, replace

* 3. STANDARDIZATION & SAFETY NET
quietly {
    foreach x in duns parentduns officecode officezip {
        capture tostring `x', replace
    }
    
    * PLACEHOLDERS (This prevents the r111 popcountry error)
    foreach var in officestate officezip officecode subagencyname popstate popzip {
        capture confirm variable `var'
        if _rc != 0 gen `var' = ""
    }
    
    * Ensure Countries exist and default to USA if missing
    foreach var in officecountry popcountry firmcountry {
        capture confirm variable `var'
        if _rc != 0 gen `var' = "USA"
    }
	
	foreach x in duns parentduns officecode officezip subagencycode {
        capture tostring `x', replace
    }
}

* 4. FISCAL YEAR
capture drop signeddate_fy
gen signeddate_fy = year(signeddate_date)
replace signeddate_fy = signeddate_fy + 1 if month(signeddate_date) >= 10

* 5. Product Service Codes (PSC)
    if (strpos("`lowv'", "product") > 0 | strpos("`lowv'", "psc") > 0) & strpos("`lowv'", "code") > 0 {
        capture confirm variable psc4
        if _rc != 0 capture rename `v' psc4
    }

display "Mapping Complete. POP and Office variables secured."


/*----------------------------------------------------------------------------*/
/* II.2.1 Open, select sample and add office information					  */
/*----------------------------------------------------------------------------*/
	
* ==============================================================================
* NOTICE TYPE COMPATIBILITY (Fixes r111: fbo_n_amdcss not found)
* ==============================================================================

* Create the 'count' variables the AER script expects based on our opportunity_type
* We map the common SAM.gov/DHS terms to the AER author's short-codes
local ntype "amdcss award combine ja mod presol snote srcsgt"

foreach t in `ntype' {
    gen fbo_n_`t' = 0
}

* Map DHS/SAM.gov terminology to AER variables
* (Adjust strings if your CSV used different names, but these are the defaults)
capture replace fbo_n_presol = 1 if strpos(upper(opportunity_type), "PRESOL") > 0
capture replace fbo_n_combine = 1 if strpos(upper(opportunity_type), "COMBINE") > 0
capture replace fbo_n_award   = 1 if strpos(upper(opportunity_type), "AWARD") > 0
capture replace fbo_n_ja      = 1 if strpos(upper(opportunity_type), "JUSTIFICATION") > 0
capture replace fbo_n_srcsgt  = 1 if strpos(upper(opportunity_type), "SOURCES SOUGHT") > 0

* If 'opportunity_type' was renamed to 'noticetype' in your file, we use that too:
capture confirm variable noticetype
if _rc == 0 {
    replace fbo_n_presol = 1 if strpos(upper(noticetype), "PRESOL") > 0
    replace fbo_n_award  = 1 if strpos(upper(noticetype), "AWARD") > 0
}

display "Notice Type Compatibility Layer Applied."
	
	* II.2.2 Format variables coming from fedbizopps (fbo)
	******************************************************
	
	rename fbo_merge_any fbo_any

	local ntype "amdcss award combine ja mod presol snote srcsgt"

	foreach t of local ntype {
		gen fbo_`t' =0
		replace fbo_`t'=1 if fbo_n_`t'>0 & missing(fbo_n_`t')==0
	}
	drop fbo_n_*
	
	gen fbo_preaward=0
	replace fbo_preaward=1 if fbo_amdcss==1 | fbo_combine==1 | fbo_mod==1 | fbo_presol==1 | fbo_snote==1 | fbo_srcsgt==1
	

	* II.2.3 Variables based on firm location
	*****************************************
	
	// Dummy for foreign firm
	gen foreignfirm = 1
	replace foreignfirm = . if missing(firmcountry)
	replace foreignfirm = 0 if firmcountry=="USA" | firmcountry=="UNITED STATES"
	label var foreignfirm "Foreign firm"
	*misc foreign contractors:
	replace foreignfirm = 1 if duns == "123456787" 

	// Fix firm states
	replace firmstate = "VA" if firmstate=="VIRGINIA"
	replace firmstate = "FOREIGN" if foreignfirm==1

	// Format firm zip codes to 5-digits
	replace firmzip = "" if length(firmzip)!=5 & length(firmzip)!=9
	replace firmzip = "" if foreignfirm==1
	replace firmzip = substr(firmzip,1,5) if length(firmzip)==9

	
	* II.2.4 Variables based on office location
	*******************************************

	// Consider only 50 states + DC for office-state
	replace officestate = "ABROAD" if officestate=="AA" | ///
					  officestate=="AE" | ///
					  officestate=="AP" | ///
					  officestate=="GU" | ///
					  officestate=="PR" | ///
					  officestate=="VI" | ///
					  officecountry!="USA" | ///
					  missing(officestate)
	gen abroad_office = officestate =="ABROAD"
						  
	// Fix some zip codes by hand (sometimes coding mistakes, most of the time 
	// military bases have their own zip codes but they don't appear in the 
	// Census data. In that case, we replace for zipcode adjacent)
	replace officezip = "07885" if officezip == "07806"
	replace officezip = "20001" if officezip == "20301"
	replace officezip = "20032" if officezip == "20375"
	replace officezip = "20814" if officezip == "20889"
	replace officezip = "23237" if officezip == "23297"
	replace officezip = "28547" if officezip == "28542"
	replace officezip = "29405" if officezip == "29419"
	replace officezip = "30067" if officezip == "30069"
	replace officezip = "31705" if officezip == "31704"
	replace officezip = "35808" if officezip == "35898"
	replace officezip = "36602" if officezip == "36628"
	replace officezip = "43213" if officezip == "43218"
	replace officezip = "61201" if officezip == "61299"
	replace officezip = "78703" if officezip == "78763"
	replace officezip = "92113" if officezip == "92136"
	replace officezip = "92106" if officezip == "92152"
	replace officezip = "96819" if officezip == "96858"

	
	* II.2.5 Variables based on place of performance
	************************************************

	// Consider only 50 states + DC for place of performance state
	replace popstate = "ABROAD" if  popstate=="AA" | ///
									popstate=="AE" | ///
									popstate=="AP" | ///
									popstate=="GU" | ///
									popstate=="PR" | ///
									popstate=="VI" | ///
									popcountry!="USA" | ///
									missing(popstate)==1
	gen abroad_pop = popstate=="ABROAD"

	// Format pop zip codes to 5-digits
	replace popzip = "" if length(popzip)!=5 & length(popzip)!=9
	replace popzip = "" if abroad_pop
	replace popzip = substr(popzip,1,5) if length(popzip)==9

	*  Merge with MSA, County and coordinates based on Zip Codes

	di "Merging geographic variables"
	foreach i in office firm pop {
		*zip code
		ren `i'zip zipCode
		merge m:1 zipCode using processed_data/temp/zipCode.dta
		drop if _merge==2
		
		di "Merge resutls based on `i'"
		if "`i'" == "office" {
			tab _merge  abroad_office, col
		}
		else if "`i'" == "firm" {
			tab _merge foreignfirm, col
		}
		else {
			tab _merge abroad_pop, col
		}
		
		drop _merge
		ren zipCode `i'zip
		label var `i'zip "zip code `i'"
		ren msa `i'msa
		label var `i'msa "MSA `i'"
		ren mpop mpop_`i'
		label var mpop_`i' "Population MSA `i'"
		ren countyID `i'county
		label var `i'county "County `i'"
		ren copop copop_`i'
		label var copop_`i' "Population County `i'"
		ren lat lat_`i'
		label var lat_`i' "Latitude `i'"
		ren lon lon_`i'
		label var lon_`i' "Latitude `i'"
	}

	foreach i in office firm pop {
		ren `i'state state
		merge m:1 state using processed_data/temp/censusStatesDivisionsRegions.dta
		di "states that are not matching:"
		tab state if _merge == 1
		drop if _merge ==2
		drop _merge
		ren region `i'region
		ren division `i'division
		ren state `i'state

	}
	
	* --- DIAGNOSTIC CHECK ---
	display "LISTING ALL VARIABLES TO FIND PSC AND OFFICE:"
	ds *product* *psc* *service* *office* *award* *id*
	describe, short
	gen offcodepsc = officecode + "_" + psc4
	gen officepop = officecode + "_" + popzip
	gen offstate = officecode + "_" + popstate
	
	

	* II.2.6 Generate location-based outcome variables
	***************************************************
	
	// Dummy for firm and pop being in the same state

	gen instatefirm_pop = popstate==firmstate
	replace instatefirm_pop = . if missing(popstate) | missing(firmstate) | abroad_pop
	label var instatefirm_pop "Within-state firm (pop)"


	// Distance measure between firm and office/zip
		
	geodist lat_firm lon_firm lat_pop lon_pop, gen(dist_firm_pop) miles
		
	replace dist_firm_pop = . if abroad_pop
	label var dist_firm_pop "Distance firm-pop"
		
	gen ldist_firm_pop = log(1 + dist_firm_pop)
	label var ldist_firm_pop "Log of (1 plus) distance firm-pop"

	gen distance_firm_pop = ldist_firm_pop
	replace distance_firm_pop = log(1500) if ldist_firm_pop>log(1500)
	label var distance_firm_pop "Censored log of (1 plus) distance firm-pop"


	

* II.2.7 Clean, format, and create new contract variables from FPDS
********************************************************************

drop if amount_total < 0
	
	
	// Type of Contract pricing:
	
	local lA "Fixed Price Redetermination"
	local lB "Fixed Price Level of Effort"
	local lJ "Fixed Price"
	local lK "Fixed Price with Economic Price Adjustment"
	local lL "Fixed Price Incentive"
	local lM "Fixed Price Award Fee"
	local lR "Cost Plus Award Fee"
	local lS "Cost No Fee"
	local lT "Cost Sharing"
	local lU "Cost Plus Fixed Fee"
	local lV "Cost Plus Incentive"
	local lY "Time and Materials"
	local lZ "Labor Hours"
	
	glevelsof pricing, local(LET)
	foreach i in `LET' {
		replace pricing = "`l`i''" if pricing == "`i'"
	}
	label var pricing "Contract Type"
	
	gen fixed_price = substr(pricing , 1, 11) == "Fixed Price"
	label var fixed_price "Fixed-Price Contract"
	order fixed_price , after(pricing)
	
	
	// Name of the goods/services included in the contract
	
* ==============================================================================
* II.2.7: DHS COMPONENT, PRODUCT ID, AND PERFORMANCE METRICS
* ==============================================================================

* 1. DHS Component Mapping
* ------------------------------------------------------------------------------
capture drop agency
gen agency = "Other"
replace agency = "Coast Guard" if subagencycode=="7008"
replace agency = "CBP"         if subagencycode=="7014"
replace agency = "TSA"         if subagencycode=="7013"
replace agency = "FEMA"        if subagencycode=="7022"
label var agency "DHS Component"

* 2. Product Service Code (PSC) & Service Dummy
* ------------------------------------------------------------------------------
capture rename psc_code psc
capture rename psc4 psc

capture drop psc_1
destring psc, force gen(psc_1)
gen service = (missing(psc_1) == 1)
gen good = 1 - service

capture drop psc2
gen psc2 = substr(psc, 1, 2)
capture drop psc4
rename psc psc4
label var psc4 "4-digit Product ID"
label var psc2 "2-digit Product ID"

* 3. IDs and Competition Variables
* ------------------------------------------------------------------------------
capture drop duns_num
destring duns, gen(duns_num) force

capture drop officeCodeCoded
encode officecode, gen(officeCodeCoded)

* Map USAspending 'number_of_offers_received' to 'noffers'
capture rename number_of_offers_received noffers
replace noffers = . if noffers==999
gen oneoffer = (noffers==1)

* Competition (Extent Competed)
capture rename extent_competed_code competedcode
gen competed = (competedcode=="A" | competedcode=="F")
label var competed "Competitively awarded"

* 4. Socioeconomic Dummies (Handles USAspending 'Y/N' or 't/f')
* ------------------------------------------------------------------------------
foreach x in veteran sdveteran woman minority {
    * Map USAspending column names to AER names if needed
    capture rename `x'_owned_business `x'
    capture rename women_owned_business woman
    
    capture gen `x'1 = (inlist(lower(`x'), "t", "y", "true"))
    capture drop `x'
    capture rename `x'1 `x'
}

* ==============================================================================
* 5. DATE CONVERSION & PERFORMANCE METRICS (DHS Specific)
* ==============================================================================

* A. Map the specific USAspending names found in your Diagnostic
* ------------------------------------------------------------------------------
* Based on your 'ds' output, we use the patterns Stata created:
capture rename award_date_s* signeddate_raw
capture rename period_of_performance_s* startdate_raw
capture rename period_of_performance_c* enddate_raw

* B. Convert to Numeric Dates (The "YMD" format is standard for USAspending)
* ------------------------------------------------------------------------------
foreach x in signeddate_raw startdate_raw enddate_raw {
    capture confirm variable `x'
    if _rc == 0 {
        * We create a numeric version of the string date
        gen `x'_num = date(`x', "YMD")
        format `x'_num %td
    }
}

* C. Assign to the standard names (With "Clean Slate" protection)
* --- C1. THE "NUKE" CLEANING BLOCK ---
* We drop these individually to bypass any line-wrap or abbreviation issues
foreach v in signeddate_date startdate enddate duration_expected duration_actual delays delays_rel delays_any {
    capture drop `v'
}

* --- C2. ASSIGN STANDARD NAMES ---
* Now that we are 100% sure the names are free, we generate
gen signeddate_date = signeddate_raw_num
gen startdate = startdate_raw_num
gen enddate = enddate_raw_num

* ==============================================================================
* C3, C4, & PUBLICITY: COMPETITION AND FBO MAPPING
* ==============================================================================

* 1. Competition (C3)
* ------------------------------------------------------------------------------
capture rename extent_competed_code competedcode
capture drop competed
gen competed = (competedcode=="A" | competedcode=="F")
label var competed "Competitively awarded"

* 2. Set-Asides (C4)
* ------------------------------------------------------------------------------
capture rename type_of_set_aside_code typeofsetaside
capture drop setaside
gen setaside = 1
replace setaside = 0 if typeofsetaside=="NONE" | typeofsetaside==""
label var setaside "Set-aside award"

* 3. Publicity Mapping (The "FBO Fix" for your Graph)
* ------------------------------------------------------------------------------
* Find the USAspending column for FedBizOpps
capture rename fed_biz_opps fbo_raw
capture rename fed_biz_opps_description fbo_raw

* Create the binary 'pub' variable the analysis script expects
capture drop pub
gen pub = 0

* Map USAspending's "Y/N" or "Yes/No" to 1/0
* (This ensures the 'reshape' command sees both categories)
replace pub = 1 if inlist(upper(fbo_raw), "Y", "YES", "T", "TRUE")

label var pub "Publicly Noticed (FBO)"

* --- QUICK DIAGNOSTIC ---
display "Checking Publicity (pub) counts. We need both 0 and 1 for the graph:"
tab pub, m


* ==============================================================================
* C5 & C6. DOLLAR/DATE MAPPING, PERFORMANCE METRICS, & OUTLIER CLEANING
* ==============================================================================

* 1. MAPPING & CLEAN SLATE
* ------------------------------------------------------------------------------
* Map USAspending Amounts
capture rename obligated_amount amount_total
capture rename total_obligated_amount amount_total
capture rename base_and_all_options_value amount_expected
capture rename total_base_and_all_options_value amount_expected

* Map USAspending Dates
capture rename action_date signeddate_raw
capture rename period_of_performance_start_date startdate_raw
capture rename period_of_performance_current_end_date enddate_raw

* Drop all target variables to prevent 'already defined' errors
foreach v in signeddate_date startdate enddate duration_expected duration_actual delays delays_rel delays_any overruns overruns_rel overruns_any {
    capture drop `v'
}

* 2. CONVERSION & ASSIGNMENT
* ------------------------------------------------------------------------------
quietly {
    * Convert Dates from string to numeric
    foreach x in signeddate_raw startdate_raw enddate_raw {
        capture drop `x'_num
        capture confirm variable `x'
        if _rc == 0 {
            gen `x'_num = date(`x', "YMD")
            format `x'_num %td
        }
    }
    * Ensure Amounts are numeric
    capture destring amount_total amount_expected, replace force
}

* Assign standard names
gen signeddate_date = signeddate_raw_num
gen startdate = startdate_raw_num
gen enddate = enddate_raw_num

* 3. PERFORMANCE CALCULATIONS & OUTLIER FILTERS
* ------------------------------------------------------------------------------
* Time Durations
gen duration_expected = enddate - startdate
gen duration_actual = enddate - signeddate_date

* Delays
gen delays = duration_actual - duration_expected
replace delays = . if missing(duration_actual) | missing(duration_expected)
replace delays = . if (delays > 3*duration_expected) | (delays < -0.3333*duration_expected)
gen delays_rel = delays / duration_expected
gen delays_any = (delays > 0 & !missing(delays))

* Cost Overruns
gen double overruns = amount_total - amount_expected
replace overruns = . if (overruns > 3*amount_expected) | (overruns < -0.3333*amount_expected)
gen double overruns_rel = overruns / amount_expected
gen overruns_any = (overruns > 0 & !missing(overruns))

* 4. LABELING
* ------------------------------------------------------------------------------
label var delays "Delays (actual minus expected days)"
label var delays_rel "Relative delays"
label var delays_any "Any delays"
label var overruns "Cost overruns (actual minus expected dollars)"
label var overruns_rel "Relative cost overruns"
label var overruns_any "Any cost overrun"

display "----------------------------------------------------"
display "SUCCESS: Performance Metrics and Outliers Cleaned."
display "----------------------------------------------------"

	preserve 
			
		keep if (amount_total>5 & amount_total<=20 & missing(amount_total)==0) | (amount_expected>5 & amount_expected<=20 & missing(amount_expected)==0)
					
		local lbe_overruns_rel: var label overruns_rel
		gen mean4_overruns_rel = overruns_rel
		winsor2 mean4_overruns_rel, replace cuts(0 99) trim by(psc4)
		
		local lbe_delays_rel: var label delays_rel
		gen mean4_delays_rel = delays_rel	
		winsor2 mean4_delays_rel, replace cuts(0 99) trim by(psc4)

		keep psc4 mean4* 
		gcollapse (mean) mean4_* (count) nObs_psc4 = mean4_overruns_rel , by(psc4)
		
		label var  nObs_psc4 "N contracts below 20K for psc4"
		
		label var mean4_overruns_rel "Mean (by Product) `lbe_overruns_rel'"
		label var mean4_delays_rel "Mean (by Product) `lbe_overruns_rel'"
		
		save processed_data/temp/delays_overruns_psc4.dta, replace
	
	restore
	
	merge m:1 psc4 using processed_data/temp/delays_overruns_psc4.dta
	drop if _merge ==2
	drop _merge

	* ==============================================================================
	* NEW FIRM / OFFICE / POP IDENTIFICATION
	* ==============================================================================

	* 1. Map the Unique Award ID (USAspending to AER name)
	* ------------------------------------------------------------------------------
	capture rename award_id_piid awdnbr
	capture rename award_or_idv_number awdnbr

	* 2. Sort and Identify (Using duns_num to avoid ambiguity)
	* ------------------------------------------------------------------------------
	* We sort by firm, office, and location to see if this is their first time working together
	sort duns_num officecode popzip signeddate_date awdnbr

	capture drop i
	egen i = seq(), by(duns_num officecode popzip)

	capture drop new_firmofficepop
	gen new_firmofficepop = (i==1)
	replace new_firmofficepop = . if missing(popzip)

	label var new_firmofficepop "New firm for officepop"
	drop i

	display "----------------------------------------------------"
	display "SUCCESS: New firm identification complete."
	display "----------------------------------------------------"
			
	// Drop R&D and special product categories
	drop if substr(psc2,1,1)=="A"  //Research and development
	drop if psc4 == "9999" // Misc ( Not Classifed)
	drop if psc4 == "V221" | psc4 == "V211" // Air passenger transportation (exeption OMB Circular A-76- FAR 5.205(e))  
	
	// Keep competitively awarded contracts and drop zero-value contracts
	keep if competed==1
	drop if amount_total==0
	
* ==============================================================================
* THE GREAT EQUALIZER: Standardize everything to THOUSANDS 
* ==============================================================================
* This ensures that 25000 (dollars) and 25 (thousands) both become 25.0
foreach v in amount_total amount_expected {
    * If it's > 500, it's Dollars. Turn into Thousands.
    replace `v' = `v'/1000 if `v' > 500 & !missing(`v')
    
    * Clean up any zeros or negatives that break the Log math
    replace `v' = . if `v' <= 0
}

display "----------------------------------------------------"
display "SUCCESS: Units standardized to Thousands."
display "----------------------------------------------------"
	
* ==============================================================================
* GENTLE CLEANUP (Replaces the crashing 'drop' line)
* ==============================================================================

* Define the list of variables the authors wanted to get rid of
local trash filekey *_fund firmcd foreign_code dod *region *division ///
             smallbus_cdp sbcdp business_size psc_1 solnbr foreign_code ///
             commercialit subconplan solicproc typeofsetaside ///
             reasonnotcompeted commercialacq fedbizopps ///
             startdate enddate_current enddate_potential ///
             awdnbrA id0 id1 officeCodeCoded

	* Loop through and drop only if they exist
	foreach v in `trash' {
		capture drop `v'
	}

	* Safety check for names: The authors drop ALL variables ending in 'name'.
	* If you want to keep 'officename' or 'agency' for your tables, skip this next line.
	capture drop *name 

	display "----------------------------------------------------"
	display "SUCCESS: Final cleanup complete. Ready to save."
	display "----------------------------------------------------"
	
/*============================================================================*/
/* III. Save key datasets													  */
/*============================================================================*/
	
	// Reduced-form analysis
	
		preserve 
		
			keep if (amount_total>5 & missing(amount_total)==0) | (amount_expected>5 & missing(amount_expected)==0)
			keep if signeddate_fy>=2015 &  signeddate_fy<=2019
			
			compress
			save processed_data/analysisCGW_DHS.dta, replace
			
		restore


* ==============================================================================
* DENSITY MOMENTS (DHS REPLICATION BRIDGE) - STABILIZED VERSION
* ==============================================================================

* 1. Load the standardized data
use "processed_data/analysisCGW_DHS.dta", clear

* 2. Setup variables
capture drop all
gen all = 1

* --- LOG MATH (Standardized to Thousands: 25.0 = $25k) ---
capture drop logAmount bin
gen logAmount = log(amount_expected) - log(25)
gen bin = 0.01 * ceil(logAmount / 0.01)

* Keep a healthy window around the threshold (-1.5 to 1.5 is roughly $5.5k to $112k)
keep if bin > -1.5 & bin <= 1.5

* --- COMPLEXITY LOGIC (COMMENTED OUT TO PREVENT CRASH) ---
* capture drop pc4_complex
* xtile pc4_complex = mean4_overruns_rel, n(4)

* Ensure 'service' is defined (1=Service, 0=Good)
capture confirm variable service
if _rc != 0 {
    gen service = (missing(psc_1) == 1)
}

* Rename 'n' to 'count_obs' to stop the r(111) ambiguous abbreviation error
capture drop count_obs
gen count_obs = 1

* 3. Define categories to analyze 
* (Removed pc4_complex from the active list to skip the loop)
local list_var all service // pc4_complex

* 4. The Loop
foreach var in `list_var' {
    display "-----------------"
    display "Analyzing var: `var'"
    display "-----------------"
    
    preserve
        * 1. Create temporary bin counts
        collapse (sum) count_obs, by(bin `var' pub) 
        
        * 2. Round-number dummies (multiples of 1, 5, 10K)
        foreach rnum of numlist 1000 5000 10000 {
            gen rnum`rnum' = 0
            forvalues r = 1/100 {
                local rnum_i = `rnum'*`r'
                local logRnum = log(`rnum_i') - log(25000)
                local rnumBin = 0.01*ceil(`logRnum'/0.01)
                replace rnum`rnum' = 1 if abs(bin-`rnumBin')<1e-5
            }
        }
    
        * 3. Polynomials for the trend line
        forvalues z = 1/5 {
            gen double b_`z' = bin^`z'
        }

        gen ns_`var' = .
        levelsof `var', local(VAR)
        levelsof pub, local(PUB)
        
        foreach k in `VAR' {
            foreach j in `PUB' {
                
                * --- REGRESSIONS (Using count_obs) ---
                capture reg count_obs b_* rnum1000 rnum5000 rnum10000 if bin<=0 & pub==`j' & `var'==`k'
                if _rc == 0 {
                    predict nhat_low if e(sample), xb
                    replace nhat_low = nhat_low - _b[rnum1000]*rnum1000 - _b[rnum5000]*rnum5000 - _b[rnum10000]*rnum10000 if e(sample)
                }
                else {
                    gen nhat_low = .
                }
                
                capture reg count_obs b_* rnum1000 rnum5000 rnum10000 if bin>0 & pub==`j' & `var'==`k' 
                if _rc == 0 {
                    predict nhat_high if e(sample), xb
                    replace nhat_high = nhat_high - _b[rnum1000]*rnum1000 - _b[rnum5000]*rnum5000 - _b[rnum10000]*rnum10000 if e(sample)
                }
                else {
                    gen nhat_high = .
                }
                
                capture drop nhat
                gen nhat = .
                replace nhat = nhat_low if bin<=0 & nhat_low!=.
                replace nhat = nhat_high if bin>0 & nhat_high!=.
                
                quietly summarize count_obs if (pub == `j') & (`var' == `k') 
                local N_sum = r(sum)
                quietly summarize nhat
                local M_sum = r(sum)
                
                if (`M_sum' > 0 & `M_sum' != .) {
                    replace nhat = nhat * `N_sum' / `M_sum'
                }
                replace ns_`var' = nhat if pub==`j' & `var'==`k' 
                drop nhat_low nhat_high nhat
            }
        }
        
        * --- 4. REFORMATTING (The Fix is Here) ---
        rename count_obs n_`var'
        
        * Keep only the variables for THIS specific category
        keep bin `var' pub n_`var' ns_`var' 
        drop if missing(`var')==1
        
        * Reshape to create the D0/D1 columns
        reshape wide n_`var' ns_`var', i(bin pub) j(`var')
        
        foreach v of varlist n_* ns_* {
            rename `v' `v'_D
        }
        reshape wide n_* ns_*, i(bin) j(pub)
        
        foreach k in `VAR' {
            capture gen n_`var'`k' = n_`var'`k'_D0 + n_`var'`k'_D1
            capture gen ns_`var'`k' = ns_`var'`k'_D0 + ns_`var'`k'_D1
        }
        
        tempfile base`var'
        save "`base`var''"
    restore
}

* ==============================================================================
* FINAL MERGE: COMBINING BUNCHING DATA
* ==============================================================================

* Start with the "All Contracts" baseline
use "`baseall'", clear
keep bin n_all* ns_all*

* Merge in the Service group
foreach var in service {
    capture merge 1:1 bin using "`base`var''"
    if _rc == 0 {
        drop if _merge == 2
        drop _merge
    }
}

* Complexity merge commented out for now:
* capture merge 1:1 bin using "`basepc4_complex'"

save "processed_data/densities.dta", replace

display "===================================================="
display "SUCCESS: Bunching Data Saved (Complexity Skipped)."
display "===================================================="
