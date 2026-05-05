
*==============================================================================*
* 01_01_02_data_prep.do
* This script prepares the datasets for the main analyses	
*==============================================================================*


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
	keep if DEPARTMENT_ID=="9700"
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
	append using raw_data/officesByHand.dta
	save processed_data/temp/offices.dta, replace



/*============================================================================*/
/* II. Procurement Contracts Data                 			 				  */
/*============================================================================*/

/*----------------------------------------------------------------------------*/
/* II.2.1 Open, select sample and add office information					  */
/*----------------------------------------------------------------------------*/
	
	use raw_data/dcDoD0619fbo.dta, clear
	keep if signeddate_fy>=2010 
	drop if parentduns == "161906193"	/* Governement is the vendor */
	drop if subagencycode=="97AS"		/* DLA	*/
	merge m:1 officecode using processed_data/temp/offices.dta
	drop if _m==2
	drop _m
	drop officename subagencyname agencycode agencyname
	rename officename2 officename
	rename subagencyname2 subagencyname
	
	
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

	// Award amounts in thousands and drop negative totals
	
	foreach x of varlist amount_* {
		replace `x' = `x'/1000
	}
	drop if amount_total<0
	
	
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
	
	ren psc psc_code
	merge m:1 psc_code using raw_data/psc_labels.dta
	drop if _merge ==2
	drop _merge
	ren psc_code psc

	
	// Agency within DOD
	
	gen agency = "Other"
	replace agency = "Army" if subagencycode=="2100"
	replace agency = "Navy" if subagencycode=="1700"
	replace agency = "AirForce" if subagencycode=="5700"
	
	
	// NAICS Code
	
	label var naics "NAICS Code (6-digit)"
	
	
	// Dummy for small business
	
	gen smallbus = substr(business_size,1,5) == "SMALL"
	label var smallbus "Small business"

	
	// Dummy for service
	
	destring psc, force gen(psc_1)
	gen service = missing(psc_1)==1
	label var service "Service"
	gen good = 1-service
	label var good "Good"


	// Product ID
	
	gen psc2 = psc
	drop psc
	label var psc2 "2-digit Product ID"
	label var psc4 "4-digit Product ID"

	// Firm ID (DUNS):
	
	destring duns, gen(duns_num) 
	
	
	// Office code
	
	encode officecode, gen(officeCodeCoded)

	
	// Number of offers
	
	replace noffers = . if noffers==999
	label var noffers "Number of offers"
	
	
	// One offer
	
	gen oneoffer = noffers==1
	label var oneoffer "One offer"


	// Decode socioeconomic dummies

	foreach x of varlist veteran sdveteran woman* minority {

		gen `x'1 = `x'=="t"
		drop `x'
		rename `x'1 `x'

	}


	// Competition
	
	gen competed = competedcode=="A" | competed=="F"
	label var competed "Competitively awarded"

	
	// Set aside
	
	gen setaside = 1
	replace setaside = 0 if typeofsetaside=="NONE"
	label var setaside "Set-aside award"
	

	// Solicitation procedures
	
	gen sap = solicproc=="SP1"
	label var sap "Used simplified acquisition procedures"

	
	// Modifications
	
	label var modified "Contract Modified"
	label var nmods "Number of Modifications"
	label var ninmods "Number of In-Scope Modifications"

	
	// Delays
	
	gen delays = duration_actual - duration_expected
	replace delays = . if (delays > 3*duration_expected) | (delays < - 0.3333*duration_expected) | terminated==1
	label var delays "Delays (actual minus expected days)"
	gen delays_rel = delays/duration_expected
	label var delays_rel "Relative delays (actual minus expected, divided by expected days)"
	gen delays_any = delays>0 & missing(delays)==0
	label var delays_any "Any delays"

	
	// Cost overruns
	
	gen double overruns = amount_total - amount_expected
	replace overruns = . if (overruns > 3*amount_expected) | (overruns < -0.3333*amount_expected) | terminated==1
	label var overruns "Cost overruns (actual minus expected dollars)"
	gen double overruns_inscope = amount_totalinscope - amount_expected
	gen double overruns_rel = overruns/amount_expected
	label var overruns_rel "Relative cost overruns (actual minus expected, divided by expected dollars)"
	gen overruns_any = overruns>0 & missing(overruns)==0
	label var overruns_any "Any cost overrun"

	
	// Product complexity: PSC4s prone to cost-overruns and delays
	// (these statistics are calculated for contracts below 20K)
	
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

	// New firm 
	sort duns officecode popzip signeddate_date awdnbr
	egen i = seq(), by(duns officecode popzip)
	gen new_firmofficepop = i==1
	replace new_firmofficepop = . if missing(popzip)==1
	label var new_firmofficepop "New firm for officepop"
	drop i
			
	// Drop R&D and special product categories
	drop if substr(psc2,1,1)=="A"  //Research and development
	drop if psc4 == "9999" // Misc ( Not Classifed)
	drop if psc4 == "V221" | psc4 == "V211" // Air passenger transportation (exeption OMB Circular A-76- FAR 5.205(e))  
	
	// Keep competitively awarded contracts and drop zero-value contracts
	keep if competed==1
	drop if amount_total==0
	
	// Drop unnecesary variables
	drop filekey *_fund firmcd foreign_code dod *name *region *division smallbus_cdp sbcdp business_size psc_1 solnbr foreign_code commercialit subconplan solicproc typeofsetaside reasonnotcompeted commercialacq smallbus_cdp fedbizopps business_size startdate enddate_current enddate_potential psc_1 sbcdp awdnbrA id0 id1 officeCodeCoded
	
	
/*============================================================================*/
/* III. Save key datasets													  */
/*============================================================================*/
	
	// Reduced-form analysis
	
		preserve 
		
			keep if (amount_total>5 & missing(amount_total)==0) | (amount_expected>5 & missing(amount_expected)==0)
			keep if signeddate_fy>=2015 &  signeddate_fy<=2019
			
			compress
			save processed_data/analysisCGW.dta, replace
			
		restore

	
	// Auction model
	
		* Start two years earlier for computation of local/nonlocal
		keep if signeddate_fy>=2013 &  signeddate_fy<=2019
		
		* Use Office's MSA as key geographic variable
		gen offmsa = officecode + "_" + officestate + "_" + officemsa
		
		* Definition Local:
		gen vendor_local = 0
		replace vendor_local = 1 if fbo_preaward == 0  //vendor won without publicity
		
		* Definition Number of Potential Locals and NonLocals per Auction
		bys offmsa psc4 duns : egen local_offmsa_psc4_max = max(vendor_local)  //anytime local
		
		egen tag_offmsa_psc4_duns = tag(offmsa psc4 duns)
		gen tag_offmsa_psc4_duns_l = tag_offmsa_psc4_duns*local_offmsa_psc4_max
		
		* Ever publicized
		bys offmsa psc4 : egen fbo_max_offmsa_psc4 = max(fbo_preaward)
		bys offmsa psc4 : egen fbo_min_offmsa_psc4 = min(fbo_preaward)
		
		* Total Number
		bys offmsa psc4 : gen N_obs_offmsa_psc4 = _N
		bys offmsa psc4 : egen N_total_offmsa_psc4 = total(tag_offmsa_psc4_duns)
		bys offmsa psc4 : egen N_l_offmsa_psc4 = total(tag_offmsa_psc4_duns_l)
		gen  N_nl_offmsa_psc4 = N_total_offmsa_psc4  - N_l_offmsa_psc4
		
		* Number of Bidders:
		bys offmsa psc4 : egen noffers_max_offmsa_psc4 = max(noffers)
		bys offmsa psc4 : egen noffers_max_offmsa_psc4_1 = max(noffers*fbo_preaward)
		bys offmsa psc4 : egen noffers_max_offmsa_psc4_0 = max(noffers*(1-fbo_preaward))
		*
		replace noffers_max_offmsa_psc4_1 = . if noffers_max_offmsa_psc4_1 == 0
		replace noffers_max_offmsa_psc4_0 = . if noffers_max_offmsa_psc4_0 == 0
		*difference:
		gen noffers_max_offmsa_psc4_d = (noffers_max_offmsa_psc4_1 - noffers_max_offmsa_psc4_0)
		
		* Proposed Definition:
		*NL + L
		egen Nmax_tot_offmsa_psc4 = rowmax(N_total_offmsa_psc4 noffers_max_offmsa_psc4_1)
		*L
		egen Nmax_l_offmsa_psc4 = rowmax(N_l_offmsa_psc4 noffers_max_offmsa_psc4_0)
		*NL:
		egen Nmax_nl_offmsa_psc4 = rowmax(N_nl_offmsa_psc4 noffers_max_offmsa_psc4_d)
	
		* Sample definition:
		gen a = 1
		gen s = (N_obs_offmsa_psc4>=4 & N_obs_offmsa_psc4<=50 & fbo_max_offmsa_psc4 != fbo_min_offmsa_psc4 )
		keep if signeddate_fy>=2015 &  signeddate_fy<=2019
		
		* Variable manipulation
		gen month9 = signeddate_month == 9
		gen month = signeddate_month 
		gen fy = signeddate_fy
		gen Nl = Nmax_l_offmsa_psc4
		gen Nnl = Nmax_nl_offmsa_psc4
		gen local = local_offmsa_psc4_max
		gen ov_rel = overruns_rel + 1 // final over initial
		gen del_rel = delays_rel + 1 
		gen fbo = fbo_preaward
		replace nmods = 10 if nmods > 10 & nmods !=.
		gen lduration = log(duration_expected+1)
		replace duration_expected = 365 if duration_expected >= 365 & duration_expected !=.
		
		* Transform values into logs:
		gen lB = log(amount_expected)
		
		* Restrict values
		drop if amount_total==0
		keep if amount_expected>10 & amount_expected<40
		
		* Save dataset with all variables first
		save processed_data/dataToModel_allVars.dta, replace
		
		* Sample:
		keep if s == 1

		* Transform to numerical
		encode officecode, gen(buyer_id)
		encode subagencycode, gen(subagencycode_id)
		encode agency, gen(agency_id)
		encode awdnbr, gen(contract_id)
		encode psc2, gen(psc2_id)
		encode psc4, gen(psc4_id)
		encode offmsa, gen(offmsa_id)
		encode naics, gen(naics_id)
		encode duns, gen(duns_id)
		
		* List of vars
		global ids contract_id agency_id subagencycode_id buyer_id offmsa_id duns_id naics_id
		global vars amount_expected lB noffers competed Nl Nnl local ov_rel fbo
		global cov month9  month fy psc4_id psc2_id service lduration mean4_overruns_rel nmods  
		global other_covs distance_firm_pop good overruns_rel overruns_any
		
		* Select variables
		order $vars $cov $other_covs
		keep s awdnbr $vars $cov $other_covs $ids
		
		* Drop obs with at least one missing (to keep the table complete)
		generate miss = 0
		foreach var of varlist $vars $cov $other_covs  {
			replace miss = 1 if missing(`var') == 1
		}

		drop if miss == 1 
		drop miss
		preserve 
			keep awdnbr s
			ren s sample_model
			save processed_data/dataToModel_sample.dta, replace
		restore
		drop awdnbr s
		
		* Recover original sort of dataToModel data 
		* (necessary for exact numerical replication, no data is changed 
		*	other than order of observations)
		merge 1:1 contract_id using raw_data/dataToModelSort.dta
		sort i
		drop _m i
				
		* Export to CSV:
		export delimited processed_data/dataToModel.csv,  nolabel replace
		
		
		
	// Density moments 
	
	use processed_data/analysisCGW.dta, clear
	
	* Gen bins and keep sample
	gen logAmount = log(1000*amount_expected) - log(25000)
	gen bin = 0.01*ceil(logAmount/0.01)
	keep if bin>-0.75 & bin<=0.75
	
	
	* Quartiles of complexity
	xtile pc4_complex = mean4_overruns_rel , n(4)
	
	*-------------------------------------------
	capture: drop n
	gen n=1
	gen all2 = 1
	gen pub = fbo_preaward
	*--------------------------------------------
	*base:
	tempfile baseclean
	save "`baseclean'"
	*--------------------------------------------
	
	
	local list_var all service pc4_complex

	
	foreach var in `list_var' {
		di "-----------------"
		di "var: `var'"
		di "-----------------"
		*open dataset:
		use "`baseclean'", clear
		*-----------------------------------
		*collapse:
		collapse (sum) n, by(bin `var' pub) 
		*-----------------------------------
		
		*round-number dummies, i.e. multiples of 1, 5 and 10K:
	
		foreach rnum of numlist 1000 5000 10000 {
		
			gen rnum`rnum' = 0
		
			forvalues r = 1/100 {
				
				local rnum_i = `rnum'*`r'
				local logRnum = log(`rnum_i') - log(25000)
				local rnumBin = 0.01*ceil(`logRnum'/0.01)
				replace rnum`rnum' = 1 if abs(bin-`rnumBin')<1e-5
		
			}
		}
	
		*------------------------------------
		* Polynomial on bin
		forvalues z = 1/5 {
			gen double b_`z' = bin^`z'
		}

		* Dummies for bunching region
		
		gen d_0 = abs(bin)<1e-5
		gen d_1 = abs(bin - 0.01)<1e-5
		
		
		*------------------------------------
		
		gen ns_`var' = .
		
		*-----------------------------------
		levelsof `var', local(VAR) clean
		levelsof pub, local(PUB) clean
		foreach k of numlist `VAR' {
			foreach j of numlist `PUB' {
				*--------------------------
				
				
				* Regressions:
				* Fit polynomial below threshold and without round numbers
				reg n b_* rnum1000 rnum5000 rnum10000 if bin<=0 & pub ==`j' & `var' == `k'
				predict nhat_low if e(sample), xb
				replace nhat_low = nhat_low - _b[rnum1000]*rnum1000 - _b[rnum5000]*rnum5000 - _b[rnum10000]*rnum10000 if e(sample)
				
				* Fit polynomial above threshold and without round numbers
				reg n b_* rnum1000 rnum5000 rnum10000 if bin>0 & pub ==`j' & `var' == `k' 
				predict nhat_high if e(sample), xb
				replace nhat_high = nhat_high - _b[rnum1000]*rnum1000 - _b[rnum5000]*rnum5000 - _b[rnum10000]*rnum10000
				
				* Combine fitted polynomial without round numbers
				gen nhat = .
				replace nhat = nhat_low if bin<=0 & nhat_low!=.
				replace nhat =  nhat_high if bin>0 & nhat_high!=.
				
				* Adjust nhat to satisfy integration constraint
				qui: sum n if pub ==`j' & `var' == `k' 
				local N=r(sum)
				qui: sum nhat
				local M=r(sum)
				replace nhat = nhat*`N'/`M'
			
				replace ns_`var' = nhat if pub ==`j' & `var' == `k' 
				drop nhat_low nhat_high nhat
				
			}
		}
		rename n n_`var'
		keep bin `var' pub n_ ns_ 
		egen i=group(bin pub)
		drop if missing(`var')==1
		reshape wide n_ ns_, i(i) j(`var')
		drop i
		foreach v of varlist n_* ns_* {
			rename 	`v' `v'_D
		}
		reshape wide n_* ns_*, i(bin) j(pub)
		foreach k of numlist `VAR' {
			gen n_`var'`k' = n_`var'`k'_D0 + n_`var'`k'_D1
			gen ns_`var'`k' = ns_`var'`k'_D0 + ns_`var'`k'_D1
		}
		order bin n_* ns_* 
		tempfile base`var'
		save "`base`var''"
		
	}

	*----------------------------------------------
	*merge the data:
	use "`baseall'", clear
	keep bin

	foreach var in `list_var' {
			merge 1:1 bin using "`base`var''"
			drop if _merge ==2
			drop _merge
	}
	order bin n_* ns_*
	
	save processed_data/densities.dta, replace

	