*==============================================================================*
* MASTER AFK SCRIPT: CONTINUITY FIX + 100-ITERATION BOOTSTRAP
*==============================================================================*
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"

* 1. THE 301-BIN GRID FIX (Ensures your data is perfect before starting)
* ------------------------------------------------------------------------------
use "processed_data/densities.dta", clear
capture replace bin = round(bin * 1000, 1)

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

* Confirming 301 observations
count 

* 2. START THE 100-ITERATION BOOTSTRAP
* ------------------------------------------------------------------------------
set seed 12345
tempname res_boot
local perm_save "processed_data/bootstrap_results_final.dta"
postfile `res_boot' b_val using "`perm_save'", replace

display "!!! STARTING FINAL 100-ITERATION BOOTSTRAP !!!"
display "Started at: $S_TIME"

forvalues i = 1/100 {
    preserve
        * Poisson Jitter (shuffles the height of each bar)
        foreach v of varlist n_all1_D0 n_all1_D1 {
            quietly replace `v' = rpoisson(`v')
        }
        
        * Initialize Ghost Variable (Now should say 301 missing values)
        capture drop btilde
        gen btilde = . 
        
        * Run Null Model (gamma=0)
        capture quietly cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
                     p(4) binWidth(10) minB(-1500) maxB(1500) ///
                     lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
                     gammaMean(0) cfDensity(btilde) ///
                     deltaMin(0) deltaStep(2) deltaMax(1000)
        
        if _rc == 0 {
            quietly sum n_all1_D0 if inrange(bin, -150, 0)
            local b_obs = r(sum)
            quietly sum btilde_D0 if inrange(bin, -150, 0)
            local b_cf = r(sum)
            quietly sum btilde_D0 if bin == 0
            local h0 = r(mean)
            
            * Post the magnitude of bunching
            local b_share = abs(`b_obs' - `b_cf') / `h0'
            post `res_boot' (`b_share')
        }
    restore
    if mod(`i', 10) == 0 display "Iteration `i' of 100 complete at $S_TIME..."
}
postclose `res_boot'

* 3. FINAL SUMMARY & CORRECTED GRAPHING
* ------------------------------------------------------------------------------
use "`perm_save'", clear
summarize b_val, detail
local b_mean = r(mean)
_pctile b_val, p(2.5, 97.5)
local low = r(r1)
local high = r(r2)

* Fixed parentheses and formatting
twoway (hist b_val, fcolor(blue%30) lcolor(blue%50) bin(20)), ///
       xline(0, lcolor(red) lwidth(thick)) ///
       xline(`b_mean', lcolor(blue) lpattern(dash)) ///
       title("Figure 2: Final Bootstrapped Significance") ///
       subtitle("95% CI: [`low', `high']") ///
       xtitle("Bunching Share (b)") ytitle("Frequency") ///
       legend(order(1 "Sample Distribution" 2 "Null Hypothesis (0)")) ///
       graphregion(color(white))

graph export "images/figure2_final_bootstrap.png", as(png) replace

display " "
display "****************************************************"
display "ALL TASKS COMPLETE. 301 BINS PROCESSED."
display "95% CI for b: [`low', `high']"
display "****************************************************"
