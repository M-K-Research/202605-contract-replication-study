* 1. Load Data
use "processed_data/analysisCGW_DHS.dta", clear

* 2. Run ONE bootstrap draw manually
set seed 123
bsample 

* 3. Scale and Bin (Corrected to 25000)
gen logAmount = log(amount_expected) - log(25000)
gen bin = 1000 * (0.01 * ceil(logAmount / 0.01))

* 4. Count observations in the "Estimation Window"
count if bin >= -120 & bin <= 120

* 5. Run the Bunching Command LOUDLY (No capture, no quietly)
gen n_all1_D0 = (pub == 0)
gen n_all1_D1 = (pub == 1)
collapse (sum) n_all1_D0 n_all1_D1, by(bin)

priceFx, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
         p(3) binWidth(10) minB(-750) maxB(750) lB(-120) uB(120) ///
         gammaMin(-0.283) gammaStep(0.001) binFactor(1000) cfDensityName(t_tilde)
