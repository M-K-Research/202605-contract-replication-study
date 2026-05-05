* ==============================================================================
* RDD STRESS TEST: POLYNOMIAL SWEEP (P=1, 2, 3, 5)
* Target Specification: Cubic (P=3)
* ==============================================================================
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"

* 1. Load and Prepare
use "processed_data/analysisCGW_DHS.dta", clear
capture gen logAmount_centered = ln(amount_initial) - ln(25000)
drop if missing(overruns_rel) | missing(logAmount_centered)

* 2. RUN THE SWEEP (Results will appear in the Results window)
* ------------------------------------------------------------------------------
display "{bf:--- RDD Sweep: Testing Functional Form Sensitivity ---}"

foreach p in 1 2 3 5 {
    display "{hline}"
    display "{bf:POLYNOMIAL ORDER: p = `p'}"
    rdrobust overruns_rel logAmount_centered, c(0) p(`p') kernel(triangular) bwselect(mserd) all
}

* 3. THE "HERO" GRAPH: CUBIC FIT (P=3)
* ------------------------------------------------------------------------------
* This version balances the curvature of the 'inverse log' dots without overfitting
rdplot overruns_rel logAmount_centered if inrange(logAmount_centered, -0.9, 0.5), ///
    c(0) p(3) kernel(triangular) ///
    title("{bf:Figure 3: Relative Cost Overruns (Cubic p=3 Fit)}") ///
    subtitle("DHS Replication | Optimal Bandwidth (MSE-RD)") ///
    xtitle("Log Distance from $25,000 Threshold") ///
    ytitle("Relative Cost Overrun (%)") ///
    graphregion(color(white)) ///
    note("Note: Bins represent local means. Cubic polynomial (p=3) fit shown with 95% CI.")

* 4. SAVE THE IMAGE
graph export "images/figure3_rdd_p3_fit.png", as(png) replace

display " "
display "****************************************************"
display "SWEEP COMPLETE. Figure 3 (p=3) saved to /images/."
display "****************************************************"
