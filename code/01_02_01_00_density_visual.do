*==============================================================================*
* FINAL VISUALIZATIONS & FILE EXPORT (FIXED)
*==============================================================================*

* 1. PREPARE DIRECTORIES
cd "C:\Users\shark\OneDrive\Documents\George Mason\Spring 2026\Econometrics\Replication Project\Replication_Files"
capture mkdir "images"

* 2. MAIN BUNCHING PLOT
* ------------------------------------------------------------------------------
use "processed_data/densities.dta", clear
capture replace bin = round(bin * 1000, 1)

* Placeholder initialization to fix r(111)
capture drop hero_tilde*
gen hero_tilde = .

* Run winning model (p=5, gamma=-0.0185)
quietly cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
             p(5) binWidth(10) minB(-1500) maxB(1500) ///
             lB0(-150) uB0(200) lB1(-150) uB1(200) binFactor(1000) ///
             gammaMean(-0.0185) cfDensity(hero_tilde) ///
             deltaMin(0) deltaStep(2) deltaMax(1000)

gen total_obs = n_all1_D0 + n_all1_D1
gen total_cf  = hero_tilde_D0 + hero_tilde_D1

twoway (bar total_obs bin if inrange(bin, -600, 600), fcolor(gs13) lcolor(gs13)) ///
       (line total_cf bin if inrange(bin, -600, 600), lcolor(red) lwidth(medium)), ///
       xline(0, lcolor(black) lpattern(dash)) ///
       xline(-150 200, lcolor(gs10) lpattern(shortdash)) ///
       title("Figure 1: DHS Contract Bunching at $25,000") ///
       subtitle("Counterfactual Price Effect (Gamma) = -0.0185") ///
       xtitle("Log Distance from Threshold (x1000)") ///
       ytitle("Number of Contracts") ///
       legend(order(1 "Observed Density" 2 "Counterfactual (Carril et al.)") pos(6) row(1)) ///
       note("Dashed lines indicate the excluded bunching window [-150, 200].") ///
       graphregion(color(white))

* EXPORT FIGURE 1
graph export "images/figure1_bunching_plot.png", as(png) replace

