
*==============================================================================*
* 01_02_00_density_analysis_main.do
* This script performs the density analysis	
*==============================================================================*


* I. Load programs

	do code/01_02_01_density_analysis_programs.do

	
* II. Define estimation parameters

	local binFactor = 1000
	local p = 5
	local m0 = 0
	local m1 = 0.05
	local m2 = 0.05
	local m3 = -0.05
	local gammaMin = -0.1
	local gammaStep = 0.00025
	local deltaMin = 0
	local deltaStep = 2
	local deltaMax = 1000
	local nsamples = 500


* III. Estimate price effects and bunching

	* 1. Open data, adjust bins for precision and other implied parameters
	
	use processed_data/densities.dta, clear
	replace bin = round(bin*`binFactor',1)
	sort bin
	local binWidth = 0.01*`binFactor'
	local minB = -`binWidth'*75
	local maxB = -`minB'
	local lB0 = -`binWidth'*5
	local uB0 = `binWidth'*12
	local lB1 = -`binWidth'*12
	local uB1 = `binWidth'*12


	* 2. Estimation of cf densities and price effects
	
	foreach x in all1 service0 service1 pc4_complex1  pc4_complex2  pc4_complex3  pc4_complex4 {
		
		display " "
		display " "
		display "********************************************"
		display "********************************************"
		display "Estimation procedure for sample: `x'"
		display "********************************************"
		display "********************************************"
		display " "
		display " "
		
		qui {
		
			priceFx, bin(bin) n_observed_D0(ns_`x'_D0) n_observed_D1(ns_`x'_D1) p(5) binWidth(`binWidth') minB(`minB') maxB(`maxB') lB(`lB1') uB(`uB1') gammaMin(`gammaMin') gammaStep(`gammaStep') binFactor(`binFactor') cfDensityName(n_tilde_`x')
			
			local gamma`x' = r(gammaStar)
			gen mean_gamma_`x' = r(gammaStar)
			
			
			cfDensities, bin(bin) n_observed_D0(ns_`x'_D0) n_observed_D1(ns_`x'_D1) p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') gammaMean(`gamma`x'') cfDensity(n_tilde_`x') deltaMin(`deltaMin') deltaStep(`deltaStep') deltaMax(`deltaMax')
			
			local delta`x' = r(deltaHat)
			
			gammaF, bin(bin) n_observed_D1(ns_`x'_D1) binWidth(`binWidth') lB1(`lB1') binFactor(`binFactor') gammaStar(`gamma`x'') deltaStar(`delta`x'') cfDensity_D1(n_tilde_`x'_D1)
			
			gen sd_gamma_`x' = r(stdev)
			
			
			foreach y of varlist F_gamma f_gamma gamma_ {
				rename `y' `y'_`x'
			}
			
			replace gamma__`x' = gamma__`x' - mean_gamma_`x'
			rename gamma__`x' gamma_`x'
			
		}

		preserve 
		
			if ${bootstrap_se}==1 {
			
				bootstrapPriceFx, bin(bin) binFactor(`binFactor') n_observed_D0(ns_`x'_D0) n_observed_D1(ns_`x'_D1) numsamples(`nsamples') p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') gammaMin(`gammaMin') gammaStep(`gammaStep') deltaMin(`deltaMin') deltaStep(`deltaStep') deltaMax(`deltaMax')
				local se_mean_gamma_`x' = r(se_mean_gamma)
				local se_sd_gamma_`x' = r(se_sd_gamma)
				
			}
		
		restore
		
		gen se_mean_gamma_`x' = 0
		gen se_sd_gamma_`x' = 0
		
		if ${bootstrap_se}==1 {
			
			replace se_mean_gamma_`x' = `se_mean_gamma_`x''
			replace se_sd_gamma_`x' = `se_sd_gamma_`x''
			
		}

	}
	
	save processed_data/density_analysis.dta, replace
	
	
		
	* 3. Compute and save excess bunching shares

	use processed_data/density_analysis.dta, clear

	foreach x in all1 service0 service1 pc4_complex1  pc4_complex2  pc4_complex3  pc4_complex4 {
		gen excessB_`x' = (ns_`x'_D0 - n_tilde_`x'_D0) / ns_`x'_D0
	}

	keep if bin>=`lB0' & bin<=0
	keep bin excessB_*

	save processed_data/bunching.dta, replace



* IV. Compute RDD corrections

	* Start from density analysis data
	
	use processed_data/density_analysis.dta, clear

	
	* gamma, F(gamma), f(gamma)
	
	rename gamma_all1 gamma
	rename F_gamma_all1 F_gamma
	rename f_gamma_all1 f_gamma

	
	* rho1 = E[gamma | gamma > p] * [1 - F(gamma)] and rho2 = E[gamma | gamma < p] * F(gamma)

	gen x = gamma*f_gamma
	gsort -gamma
	gen rho1 = x in 1
	replace rho1 = rho1[_n-1] + x if _n>1
	sort gamma
	gen rho2 = x in 1
	replace rho2 = rho2[_n-1] + x if _n>1
	drop x

	
	* F_xi (assume no measurement error, i.e. xi=0 for all contracts)
	
	gen F_xi = 0
	replace F_xi =1 if bin>0

	
	* Save and change units of gamma
	
	preserve
	keep rho* gamma f_gamma F_gamma F_xi
	rename gamma bin
	replace bin = round(bin*100,1)*10
	save processed_data/temp/pfxCorrection.dta, replace
	restore

	
	* pi_D and merge
	
	gen double pi_D = ns_all1_D1/ns_all1
	keep bin pi_D
	merge 1:1 bin using processed_data/temp/pfxCorrection.dta
	drop if _m==2

	
	* Fill out extreme observations (covering full range of contracts in sample)

	replace F_gamma=F_gamma[_n-1] if missing(F_gamma)
	replace f_gamma=f_gamma[_n-1] if missing(f_gamma)
	replace F_xi=F_xi[_n-1] if missing(F_xi)
	replace rho1=rho1[_n-1] if missing(rho1)
	replace rho2=rho2[_n-1] if missing(rho2)
	drop _m
	
	
	* Compute key correction terms

	gen lambda2 = (bin<=0)*(1-pi_D) + (1-F_gamma)*pi_D
	gen lambda4 = (bin>0)*(1-pi_D) + F_gamma*pi_D

	
	* Save
	
	save processed_data/priceFxCorrectionInput.dta, replace


