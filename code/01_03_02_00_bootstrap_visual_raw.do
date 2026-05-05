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

* QUICK RAW TEST (No Absolute Value)
set seed 12345
tempname res_raw
postfile `res_raw' b_raw using "processed_data/raw_test.dta", replace

forvalues i = 1/50 {
    preserve
        foreach v of varlist n_all1_D0 n_all1_D1 {
            quietly replace `v' = rpoisson(`v')
        }
        capture drop btilde
        gen btilde = . 
        capture quietly cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
                     p(4) binWidth(10) minB(-1500) maxB(1500) ///
                     lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
                     gammaMean(0) cfDensity(btilde)
        
        if _rc == 0 {
            quietly sum n_all1_D0 if inrange(bin, -150, 0)
            local b_obs = r(sum)
            quietly sum btilde_D0 if inrange(bin, -150, 0)
            local b_cf = r(sum)
            quietly sum btilde_D0 if bin == 0
            local h0 = r(mean)
            
            * NO ABSOLUTE VALUE HERE
            local b_share = (`b_obs' - `b_cf') / `h0'
            post `res_raw' (`b_share')
        }
    restore
}
postclose `res_raw'

use "processed_data/raw_test.dta", clear
summarize b_raw, detail

*==============================================================================*
* VISUALIZING THE RAW (UNFOLDED) DISTRIBUTION
*==============================================================================*
use "processed_data/raw_test.dta", clear

* 1. Get the stats for the labels
summarize b_raw, detail
local b_mean = r(mean)
_pctile b_raw, p(2.5, 97.5)
local low = r(r1)
local high = r(r2)

* 2. Generate the "Honest" Histogram
twoway (hist b_raw, fcolor(green%30) lcolor(green%50) bin(20)), ///
       xline(0, lcolor(red) lwidth(thick)) ///
       xline(`b_mean', lcolor(blue) lpattern(dash)) ///
       title("{bf:Figure 2 (Raw): Unfolded Bunching Distribution}") ///
       subtitle("95% CI: [`low', `high'] (No Absolute Value Applied)") ///
       xtitle("Raw Bunching Share (b)") ///
       ytitle("Density") ///
       legend(order(1 "Raw Iterations" 2 "Null Hypothesis (0)" 3 "Mean Estimate")) ///
       note("Note: This version includes negative values to test for mechanical bias.") ///
       graphregion(color(white))

* 3. Export for your records
graph export "images/figure2_raw_unfolded.png", as(png) replace

display "****************************************************"
display "RAW MEAN: `b_mean'"
display "95% CI:   [`low', `high']"
display "****************************************************"
