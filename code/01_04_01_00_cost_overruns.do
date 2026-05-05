* ==============================================================================
* RESEARCH QUESTION 2: REGRESSION DISCONTINUITY (COST OVERRUNS)
* Running Variable: amount_initial | Outcome: overruns_rel
* ==============================================================================
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"

* 1. LOAD THE CORRECT ANALYSIS DATA
use "processed_data/analysisCGW_DHS.dta", clear

* 2. GENERATE THE CENTERED RUNNING VARIABLE
* We take the log of the initial amount and center it at ln(25,000)
* This ensures that 0 on the x-axis is exactly the $25,000 threshold.
gen logAmount_centered = ln(amount_initial) - ln(25000)
label var logAmount_centered "Log Distance from $25,000 Threshold"

* 3. DATA CLEANING
* Remove missing values to ensure the bandwidth optimizer runs correctly
drop if missing(overruns_rel) | missing(logAmount_centered)

* 4. MAIN RDD SPECIFICATION
* ------------------------------------------------------------------------------
display "RUNNING MAIN RDD SPECIFICATION (Outcome: overruns_rel)..."

rdrobust overruns_rel logAmount_centered, c(0) kernel(triangular) bwselect(mserd) all

* Capture the optimal bandwidth for plotting and sensitivity
local h_opt = e(h_l)

* 5. SENSITIVITY ANALYSIS (Bandwidth Robustness)
* ------------------------------------------------------------------------------
display "SENSITIVITY CHECK: 50% AND 150% OF OPTIMAL BANDWIDTH"
rdrobust overruns_rel logAmount_centered, c(0) h(`=`h_opt'*0.5')
rdrobust overruns_rel logAmount_centered, c(0) h(`=`h_opt'*1.5')

* 6. VISUALIZATION: THE RDD JUMP
* ------------------------------------------------------------------------------
* Note: We use inrange(-0.9, 0.5) to focus on the window around the threshold
rdplot overruns_rel logAmount_centered if inrange(logAmount_centered, -0.9, 0.5), ///
    c(0) p(2) kernel(triangular) ///
    title("{bf:Figure 3: Relative Cost Overruns at $25,000}") ///
    subtitle("DHS Replication: Regression Discontinuity Design") ///
    xtitle("Log Distance from Threshold (0 = $25k)") ///
    ytitle("Relative Cost Overrun (%)") ///
    graphregion(color(white)) ///
    note("Note: Bins represent local means. Quadratic fit shown with 95% CI.")

* Export Figure 3 to your images folder
graph export "images/figure3_rdd_overruns.png", as(png) replace

display " "
display "****************************************************"
display "RDD ANALYSIS COMPLETE."
display "Check Figure 3 for the jump in overruns."
display "****************************************************"
