* 1. Set the path
cd "C:/Users/shark/OneDrive/Documents/George Mason/Spring 2026/Econometrics/Replication Project/Replication_Files"

* 2. Load the environment
do "code/01_02_01_density_analysis_programs.do"
use "processed_data/analysisCGW_DHS.dta", clear

* 3. Run ONE replication "Loudly"
bsample 
gen logAmount = log(amount_expected) - log(25)
gen bin = 1000 * (0.01 * ceil(logAmount / 0.01))
gen n_all1_D0 = (pub == 0)
gen n_all1_D1 = (pub == 1)
collapse (sum) n_all1_D0 n_all1_D1, by(bin)

* Re-generate polynomials
forvalues z = 1/3 {
    gen double b_`z' = bin^`z'
}

* Test the Density Function (Loudly)
cfDensities, bin(bin) n_observed_D0(n_all1_D0) n_observed_D1(n_all1_D1) ///
         p(3) binWidth(10) minB(-750) maxB(750) lB0(-50) uB0(120) lB1(-120) uB1(120) ///
         binFactor(1000) gammaMean(-0.283) cfDensity(temp_tilde)
