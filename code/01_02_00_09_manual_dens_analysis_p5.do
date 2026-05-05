*==============================================================================*
* Manual Optimal Density Search
*==============================================================================*

* 1. RELOAD & CLEAN
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"
use "processed_data/densities.dta", clear
capture replace bin = round(bin * 1000, 1)

* Continuity Fix
preserve
    clear
    set obs 301
    gen bin = (_n-1)*10 - 1500
    tempfile master_bins
    save `master_bins'
restore
merge 1:1 bin using `master_bins'
foreach v of varlist n_* ns_* {
    replace `v' = 0 if missing(`v')
}
drop _merge

* 2. THE TESTER (Testing your -0.0185 guess)
* ------------------------------------------------------------------------------
local test_g = -0.0185   
local poly   = 5

capture drop manual_tilde manual_tilde_D0 manual_tilde_D1
gen manual_tilde = .

cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
             p(`poly') binWidth(10) minB(-1500) maxB(1500) ///
             lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
             gammaMean(`test_g') cfDensity(manual_tilde) ///
             deltaMin(0) deltaStep(2) deltaMax(1000)

* 3. VERIFIED TOTAL CALCULATION
* ------------------------------------------------------------------------------
quietly gen n_total = n_all1_D0 + n_all1_D1
quietly sum n_total if inrange(bin, -150, 200)
local obs_total = r(sum)

quietly gen cf_total = manual_tilde_D0 + manual_tilde_D1
quietly sum cf_total if inrange(bin, -150, 200)
local cf_total = r(sum)

display " "
display "****************************************************"
display "TOTAL SYSTEM RESULTS FOR p=`poly' AT GAMMA `test_g':"
display "TOTAL BALANCE (M):        " `obs_total' - `cf_total'
display "****************************************************"


* Calculate the excess mass in the bunching zone (left of 0)
quietly sum n_all1_D0 if inrange(bin, -150, 0)
local obs_bunch = r(sum)
quietly sum manual_tilde_D0 if inrange(bin, -150, 0)
local cf_bunch = r(sum)

local B_hat = `obs_bunch' - `cf_bunch'

* Calculate the average height of counterfactual at threshold
quietly sum manual_tilde_D0 if bin == 0
local h_zero = r(mean)

local bunching_share = `B_hat' / `h_zero'

display "Point Estimate (Gamma): -0.0185"
display "Excess Mass (B-hat):    " `B_hat'
display "Bunching Share (b):     " `bunching_share'

*==============================================================================*
* Bootstrapping
*==============================================================================*

* Calculate Bunching Share

* 1. Estimate the "Null" Counterfactual (No Price Effect, gamma = 0)
capture drop null_tilde*
gen null_tilde = .

cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
             p(5) binWidth(10) minB(-1500) maxB(1500) ///
             lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
             gammaMean(0) cfDensity(null_tilde) ///
             deltaMin(0) deltaStep(2) deltaMax(1000)

* 2. Calculate the Area of the Spike (Excess Mass)
* This is the difference between Reality and the "Zero-Manipulation" model
quietly sum n_all1_D0 if inrange(bin, -150, 0)
local obs_spike = r(sum)

quietly sum null_tilde_D0 if inrange(bin, -150, 0)
local null_cf = r(sum)

local excess_mass = `obs_spike' - `null_cf'

* 3. Calculate b (Excess Mass / Height of Counterfactual at Cutoff)
quietly sum null_tilde_D0 if bin == 0
local h_zero = r(mean)
local b_academic = `excess_mass' / `h_zero'

display " "
display "******************************************"
display "RESEARCH QUESTION 1: BUNCHING SIGNIFICANCE"
display "Point Estimate (Gamma):   -0.0185"
display "Excess Mass (B-hat):      " `excess_mass'
display "Academic Bunching Share (b): " `b_academic'
display "******************************************"

*==============================================================================*
* Poisson Bootstrap Analysis: THE FIXED VERSION
*==============================================================================*

set seed 12345
tempname res_boot
tempfile boot_results
postfile `res_boot' b_val using "`boot_results'", replace

display "Starting REAL Poisson Bootstrap... (This should take 10+ minutes)"

forvalues i = 1/50 {
    preserve
        * 1. THE POISSON JITTER
        foreach v of varlist n_all1_D0 n_all1_D1 {
            quietly replace `v' = rpoisson(`v')
        }
        
        * 2. INITIALIZE THE GHOST VARIABLE (Crucial Fix)
        capture drop btilde
        gen btilde = . 
        
        * 3. RUN THE MODEL
        * Note: We use p=4 here. It's often more stable for bootstrapping small samples.
        capture quietly cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
                     p(4) binWidth(10) minB(-1500) maxB(1500) ///
                     lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
                     gammaMean(0) cfDensity(btilde) ///
                     deltaMin(0) deltaStep(2) deltaMax(1000)
        
        if _rc == 0 {
            * Calculate the excess mass 
            * (We use the absolute value to show the 'magnitude' of the displacement)
            quietly sum n_all1_D0 if inrange(bin, -150, 0)
            local b_obs = r(sum)
            quietly sum btilde_D0 if inrange(bin, -150, 0)
            local b_cf = r(sum)
            quietly sum btilde_D0 if bin == 0
            local h0 = r(mean)
            
            * We post the ABSOLUTE bunching share to measure significance of the deviation
            local b_share = abs(`b_obs' - `b_cf') / `h0'
            post `res_boot' (`b_share')
        }
    restore
    if mod(`i', 10) == 0 display "Iteration `i' complete..."
}
postclose `res_boot'

* VIEW THE SIGNIFICANCE
use "`boot_results'", clear
count // This should now say '50'
summarize b_val, detail
_pctile b_val, p(2.5, 97.5)
display " "
display "****************************************************"
display "95% CONFIDENCE INTERVAL FOR BUNCHING MAGNITUDE: [" r(r1) ", " r(r2) "]"
display "****************************************************"
