* ==============================================================================
* RDD COLOR-CODED COMPARISON (MANUAL BUILD)
* Linear (Orange) vs Quadratic (Navy)
* ==============================================================================
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"
use "processed_data/analysisCGW_DHS.dta", clear

* 1. Prep and Narrow the Window
capture gen logAmount_centered = ln(amount_initial) - ln(25000)
drop if missing(overruns_any) | missing(logAmount_centered)
keep if abs(logAmount_centered) <= 0.3

* 2. GENERATE BINNED MEANS (The Dots)
* We use the 'genvars' option to save the x and y coordinates of the dots
capture drop rdplot_*
rdplot overruns_any logAmount_centered, c(0) nbins(15 15) hide genvars

* 3. THE "MANUAL" TWOWAY PLOT
* This approach never fails because it uses standard Stata plotting
twoway ///
    (scatter rdplot_mean_y rdplot_mean_x, mcolor(gray%50) msize(small)) ///  <- The Dots
    (qfit overruns_any logAmount_centered if logAmount_centered < 0, lcolor(navy) lwidth(medium)) /// <- Quadratic Left
    (qfit overruns_any logAmount_centered if logAmount_centered >= 0, lcolor(navy) lwidth(medium)) /// <- Quadratic Right
    (lfit overruns_any logAmount_centered if logAmount_centered < 0, lcolor(orange) lwidth(medium) lpattern(dash)) /// <- Linear Left
    (lfit overruns_any logAmount_centered if logAmount_centered >= 0, lcolor(orange) lwidth(medium) lpattern(dash)), /// <- Linear Right
    xline(0, lcolor(black) lwidth(thin)) ///
    title("{bf:Figure 3: Overrun Share (p=1 vs p=2)}") ///
    subtitle("DHS Replication | Narrow Window (+/- 0.3)") ///
    xtitle("Log Distance from $25,000 Threshold") ///
    ytitle("Share of Contracts (%)") ///
    legend(order(1 "Binned Means" 2 "Quadratic (p=2)" 4 "Linear (p=1)") rows(1)) ///
    graphregion(color(white))

* 4. SAVE
graph export "images/figure3_final_comparison.png", as(png) replace
