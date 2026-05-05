
*==============================================================================*
* 01_02_00_density_analysis_main.do
* This script performs the density analysis	
*==============================================================================*


* I. Load programs

	do code/01_02_01_density_analysis_programs.do

	
* II. Define estimation parameters

	local binFactor = 1000
	local p = 3
	local m0 = 0
	local m1 = 0.05
	local m2 = 0.05
	local m3 = -0.05
	local gammaMin = -0.15
	local gammaStep = 0.0001
	local deltaMin = 0
	local deltaStep = 2
	local deltaMax = 1000
	local nsamples = 500


* III. Estimate price effects and bunching
    * 1. Open data and EXPAND THE MAP
    
    use "processed_data/densities.dta", clear
    replace bin = round(bin*`binFactor',1)

    * --- STEP A: Create a 'Master Map' of all 151 bins (-750 to 750) ---
    preserve
        clear
        set obs 151
        gen bin = (_n-1)*10 - 750
        tempfile master_map
        save `master_map'
    restore

    * --- STEP B: Merge your DHS data into the Master Map ---
    merge 1:1 bin using `master_map'
    
    * Note: _merge == 2 are the 'Ghost Bins' that had no contracts
    
    * --- STEP C: Fill the holes with Zeros ---
    foreach v of varlist n_* ns_* {
        replace `v' = 0 if missing(`v')
    }
    
    drop _merge
    sort bin

    * --- DIAGNOSTIC CHECK ---
    count
    list bin ns_all1_D0 ns_all1_D1 in 1/10
	
	* Set implied parameters
	local binWidth = 0.01*`binFactor'
	local minB = -`binWidth'*75
	local maxB = -`minB'
	local lB0 = -`binWidth'*5
	local uB0 = `binWidth'*12
	local lB1 = -`binWidth'*12
	local uB1 = `binWidth'*12

* ==============================================================================
* III.2 ESTIMATION LOOP (Price Effect Only)
* ==============================================================================

foreach x in all1 {
    display " "
    display "----------------------------------------------------"
    display "RUNNING DHS ANALYSIS FOR: `x'"
    display "----------------------------------------------------"
    
    * Use noisily to see the iterations scroll
    noisily priceFx, bin(bin) n_observed_D0(ns_`x'_D0) n_observed_D1(ns_`x'_D1) p(`p') ///
             binWidth(`binWidth') minB(`minB') maxB(`maxB') lB(`lB1') uB(`uB1') ///
             gammaMin(`gammaMin') gammaStep(`gammaStep') binFactor(`binFactor') ///
             cfDensityName(n_tilde_`x')
             
    if _rc == 0 {
        * Store the result
        gen gamma_result_`x' = r(gammaStar)
        local final_gamma = r(gammaStar)
        
        display " "
        display "****************************************************"
        display " SUCCESS! THE DHS PRICE EFFECT (GAMMA) IS: " `final_gamma'
        display "****************************************************"
        
        * 2. Counterfactual Densities (Required for the graph)
        capture cfDensities, bin(bin) n_observed_D0(ns_`x'_D0) n_observed_D1(ns_`x'_D1) p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') gammaMean(`final_gamma') cfDensity(n_tilde_`x') deltaMin(`deltaMin') deltaStep(`deltaStep') deltaMax(`deltaMax')
    }
    else {
        display "ERROR: Optimization failed for `x'."
    }
}

save "processed_data/final_gamma_results.dta", replace

* ==============================================================================
* III.3 BUNCHING SUMMARY (Simplified)
* ==============================================================================

use "processed_data/final_gamma_results.dta", clear

* Calculate Excess Bunching using the result
capture gen excessB_all1 = (ns_all1_D0 - n_tilde_all1_D0) / ns_all1_D0

* Hard-code the range so it doesn't delete your data if locals are lost
keep if bin >= -50 & bin <= 0

display " "
display "FINAL DHS BUNCHING SUMMARY:"
list bin ns_all1_D0 n_tilde_all1_D0 excessB_all1 if bin >= -150 & bin <= 150

	save "processed_data/bunching.dta", replace


