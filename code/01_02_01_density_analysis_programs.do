
*==============================================================================*
* 01_02_01_density_analysis_programs.do
* This script defines the programs used to perform the density analysis
*==============================================================================*


//////////////////////////////////
//////////////////////////////////
* PART I: PRICE EFFECTS
//////////////////////////////////
//////////////////////////////////

*******************************************************
* I.A. FBO price effects 
*******************************************************
* Program to estimate average price effect
*******************************************************
* Key Input: bins and frequency distributions of pub and unpub
* Key Output: estimated average price effect
*******************************************************



capture program drop interpolate

program define interpolate, rclass
	
	syntax, [bin(varname numeric) n_observed_D0(varname numeric) n_observed_D1(varname numeric) p(integer 4) binWidth(integer 4) minB(integer 4) maxB(integer 4) lB(integer 4) uB(integer 4) gammaHat(real 1.0) binFactor(integer 4)]
	
	* Construct shifted distribution
				
	local bw = `binWidth'/2
	gen binX = `bin' + `gammaHat'*`binFactor'
	lpoly `n_observed_D1' binX, bwidth(`bw') nograph at(`bin') gen(n_shifted_D1)
	gen n_shifted = `n_observed_D0' + n_shifted_D1
	
	* Polynomial terms
	
	forvalues z=1/`p' {
		gen double bin_`z' = (`bin'/`binFactor')^`z'	
	}
	
	* Exclusion dummies
	local lB2 = `lB'+ `binWidth'
	forvalues ex = `lB2'(`binWidth')0 {
		local exname = abs(`ex')
		gen exclL`exname' = `bin'==`ex'
	}
	forvalues ex = `binWidth'(`binWidth')`uB' {
		gen exclR`ex' = `bin'==`ex'
	}
	
	* Interpolate
	
	reg n_shifted bin_* excl*  if `bin' >`minB' & `bin' <= `maxB'
	predict nhat if `bin' >`minB' & `bin' <= `maxB', xb 
	
	forvalues ex = `lB2'(`binWidth')0 {
		local exname = abs(`ex')
		replace nhat = nhat - _b[exclL`exname']*exclL`exname'  if `bin'>`minB' & `bin'<= `maxB'
	}
	forvalues ex = `binWidth'(`binWidth')`uB' {
		replace nhat = nhat - _b[exclR`ex']*exclR`ex'  if `bin'>`minB' & `bin'<= `maxB'
	}
	
	* Compute excess mass below (B) and missing mass above (M)
	egen massBelow = total(n_shifted - nhat) if `bin'>=`lB' & `bin'<=0
	egen massAbove = total(nhat - n_shifted) if `bin'>0 & `bin'<=`uB'
	sum massBelow 
	local B_i = r(mean)
	sum massAbove
	local M_i = r(mean)
	
	drop binX n_shift* bin_* excl* mass*
	
	return local B = `B_i'
	return local M = `M_i'
	
end
	

capture program drop priceFx

program define priceFx, rclass
	
	syntax, [bin(varname numeric) n_observed_D0(varname numeric) n_observed_D1(varname numeric) p(integer 4) binWidth(integer 4) minB(integer 4) maxB(integer 4) lB(integer 4) uB(integer 4) gammaMin(real 1.0) gammaStep(real 1.0) binFactor(integer 4) cfDensityName(string)]
	
	* Initialize values
	local B = 1
	local M = 0
	local gammaHat = `gammaMin'
	local i = 0
	gen `cfDensityName' = 0
		
	display "**********************"
	
	* Search for gamma
	
	while (`B'>`M') {
					
			qui: interpolate, bin(`bin') n_observed_D0(`n_observed_D0') n_observed_D1(`n_observed_D1') p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB(`lB') uB(`uB') gammaHat(`gammaHat') binFactor(`binFactor')
			local B = r(B)
			local M = r(M)
			local i = `i' + 1
			local gammaHat = `gammaHat' + `gammaStep'
			qui: replace `cfDensityName' = nhat
			drop nhat
			
			display "iteration = `i'"
			display "gamma = `gammaHat'"
			display "B = `B'"
			display "M = `M'"
			display "**********************"

		}
	
	return scalar gammaStar = `gammaHat'
	
end




*******************************************************
* I.B. Recovering separate counterfactual distributions
*******************************************************
* From knowledge of the average price effect, we compute
* counterfactual densities for D=0 and D=1
*******************************************************
* Key Inputs: average price effects, bins, obs frequency distributions 
* of pub and unpub, counterfactual total density
* Key Output: counterfactual densities of D=0 and D=1
*******************************************************


* Step 1: counterfactual construction given Delta

capture program drop cfDensitiesInner

program define cfDensitiesInner, rclass
	
	syntax, [bin(varname numeric) n_observed_D0(varname numeric) n_observed_D1(varname numeric) p(integer 4) binWidth(integer 4) minB(integer 4) maxB(integer 4) lB0(integer 4) uB0(integer 4)  lB1(integer 4) uB1(integer 4) binFactor(integer 4) gammaMean(real 1.0) delta(integer 4) cfDensity(varname numeric) ]

	* Construct "true" horizontally shifted density of D=1
	local bw = `binWidth'/2
	gen binX = `bin' + `gammaMean'*`binFactor'
	lpoly `n_observed_D1' binX, bwidth(`bw') nograph at(`bin') gen(n_shifted_D1)

	* Generate vertically shifted densities
	gen n_vshifted_D0 = `n_observed_D0'
	replace n_vshifted_D0 = n_vshifted_D0 + `delta' if `bin'>0
	gen n_vshifted_D1 = n_shifted_D1
	replace n_vshifted_D1 = n_vshifted_D1 - `delta' if `bin'>0

	* Polynomial terms
	forvalues z=1/`p' {
		gen double bin_`z' = (`bin'/`binFactor')^`z'	
	}
	
	* Weights
	gen w = abs(`bin'^(-1))
	
	forvalues i=0/1 {
	
		* Exclusion dummies
		local lB`i'_2 = `lB`i''+ `binWidth'
		forvalues ex = `lB`i'_2'(`binWidth')0 {
			local exname = abs(`ex')
			gen exclL_`i'_`exname' = `bin'==`ex'
		}
		forvalues ex = `binWidth'(`binWidth')`uB`i'' {
			gen exclR_`i'_`ex' = `bin'==`ex'
		}
		
		* Interpolation and sum of squared residuals
		
		reg n_vshifted_D`i' bin_* exclL_`i'_* exclR_`i'_*  [aw=w] if `bin' >`minB' & `bin' <= `maxB'
		
		predict nhat_D`i' if `bin' >`minB' & `bin' <= `maxB', xb
	
		predict e_D`i' if `bin' >`minB' & `bin' <= `maxB', resid
		egen e2_D`i' = total((e_D`i'/100)^2) if `bin' >`minB' & `bin' <= `maxB'
		sum e2_D`i'
		local e2_`i' = r(mean)
		
		forvalues ex = `lB`i'_2'(`binWidth')0 {
			local exname = abs(`ex')
			replace nhat_D`i' = nhat_D`i' - _b[exclL_`i'_`exname']*exclL_`i'_`exname'  if `bin'>`minB' & `bin'<= `maxB'			
		}
		
		forvalues ex = `binWidth'(`binWidth')`uB`i'' {
			replace nhat_D`i' = nhat_D`i' - _b[exclR_`i'_`ex']*exclR_`i'_`ex'  if `bin'>`minB' & `bin'<= `maxB'
		}
		
	}
	
	* Candidate cf Densisties
	replace `cfDensity'_D0 = nhat_D0 
	replace `cfDensity'_D0 = `cfDensity'_D0 - `delta' if `bin'>0
	replace `cfDensity'_D1 = nhat_D1 
	replace `cfDensity'_D1 = `cfDensity'_D1 + `delta' if `bin'>0
	
	drop binX n_vshifted* n_shifted_D1 bin_* excl* nhat* e2* e_* w
	
	return scalar objective = (1/2)*`e2_0' + (1/2)*`e2_1'
	
end


* Step 2: search over Delta to minimize objective


capture program drop cfDensities

program define cfDensities, rclass
	
	syntax, [bin(varname numeric) n_observed_D0(varname numeric) n_observed_D1(varname numeric) p(integer 4) binWidth(integer 4) minB(integer 4) maxB(integer 4) lB0(integer 4) uB0(integer 4) lB1(integer 4) uB1(integer 4) binFactor(integer 4) gammaMean(real 1.0) cfDensity(varname numeric) deltaMin(integer 4) deltaStep(integer 4) deltaMax(integer 4)]
	
	* Number of steps
	local N = floor((`deltaMax'-`deltaMin')/`deltaStep') + 1
	
	* Initialize cfDensitiesInner
	gen `cfDensity'_D0 = .
	gen `cfDensity'_D1 = .
	
	* Iterate over delta
	
	forvalues i=1/`N' {
	
		local delta_`i' = `deltaMin' + `deltaStep'*(`i'-1)
		
		qui: cfDensitiesInner, bin(`bin') n_observed_D0(`n_observed_D0') n_observed_D1(`n_observed_D1') p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') gammaMean(`gammaMean') delta(`delta_`i'') cfDensity(`cfDensity')
		
		local e_`i' = r(objective)
		
	}
	
	* Save results and deltaStar
	
	preserve
	
	clear
	set obs `N'
	gen obj=.
	gen delta = .
	forvalues i=1/`N' {
		replace obj = `e_`i'' in `i'
		replace delta = `delta_`i'' in `i'
	}
	
	save processed_data/temp/deltaSearch.dta, replace
	
	sum obj
	local minobj = r(min)
	sum delta if abs(obj - `minobj')<1e-7
	local deltaStar = r(min)
	
	restore
	
	
	* Get cf densities
	
	qui: cfDensitiesInner, bin(`bin') n_observed_D0(`n_observed_D0') n_observed_D1(`n_observed_D1') p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') gammaMean(`gammaMean') delta(`deltaStar') cfDensity(`cfDensity')
	
	return scalar deltaHat = `deltaStar'
	
end




*******************************************************
* I.C. Estimating the distribution of gamma
*******************************************************
* From knowledge of the the counterfactual distribution
* D=1, we recover the distribution of price effects
*******************************************************
* Key Inputs: bins, obs frequency distributions 
* of pub, counterfactual distribution of pub
* Key Output: empirical distribution F(gamma)
*******************************************************

* We use the following formula. 

* At x<0 close to the threshold:

* (n_p_shifted_D1(x) - n_p_tilde_D1(x)) = Delta * [1 - F_gamma(x)]

* We recover F_gamma (x) for x between lB1 and 0 and assume simmetry


capture program drop gammaF

program define gammaF, rclass

	syntax, [bin(varname numeric) n_observed_D1(varname numeric) binWidth(integer 4) lB1(integer 4) binFactor(integer 4) gammaStar(real 1.0) deltaStar(integer 4) cfDensity_D1(varname numeric)]

	sort `bin'
	
	* Shifted density of D=1
	local bw = `binWidth'/2
	gen binX = `bin' + `gammaStar'*`binFactor'
	lpoly `n_observed_D1' binX, bwidth(`bw') nograph at(`bin') gen(n_shifted_D1)	

	* Number of steps
	local N = floor(-`lB1'/`binWidth')
	
	* F_gamma
	gen F_gamma = (n_shifted_D1 - `cfDensity_D1')/`deltaStar'
	replace F_gamma = 0 if `bin'<=`lB1'
	replace F_gamma = 1 if `bin'>-`lB1'
	
	forvalues i = 1/`N' {
		local b = `i'*`binWidth'
		local k = 2*`i'-1
		replace F_gamma = 1-F_gamma[_n-`k'] if bin==`b'
		
	}
	
	* Variance
	
	gen gamma_ = bin/`binFactor'

	gen f_gamma = 0
	replace  f_gamma = F_gamma -  F_gamma[_n-1] if _n>1
	gen x2 = (gamma_^2)*f_gamma
	sum x2
	local V = r(sum)
	local sd = sqrt(`V')
	
	drop binX n_shifted_D1 x2
	
	return scalar variance = `V'
	return scalar stdev = `sd'
	
end






///////////////////////////////////////
///////////////////////////////////////
* PART II: STANDARD ERRORS / BOOTSTRAP
///////////////////////////////////////
///////////////////////////////////////


*******************************************************
* II.A. Simulated samples
*******************************************************
* Generate B samples of size N contracts, sampling with 
* replacement from binned frequency data. 
* Goal is to generate a B-size distribution of price-effects
*******************************************************
* Key Input: bins and frequency distributions of pub and unpub
* Key Output: data set with B frequency distributions of pub and unpub
*******************************************************


capture program drop simulatedSamples

program define simulatedSamples
	
	syntax, [bin(varname numeric) binFactor(integer 4) n_observed_D0(varname numeric) n_observed_D1(varname numeric) numcontracts(integer 4) numsamples(integer 4) ]
	
	qui {
		
		keep `bin' `n_observed_D0' `n_observed_D1'
		rename `bin' bin
		rename `n_observed_D0' n_obs0
		rename `n_observed_D1' n_obs1
		local N = `numcontracts'
		local B = `numsamples'
		
		* Reshape long 
		*replace bin = round(bin*`binFactor',1)
		tostring bin, replace
		replace bin = bin + "_"
		reshape long n_obs, i(bin) j(D) string
		gen binD = bin+D
		keep binD n_obs
		
	}
	
	* Sample N contracts without replacement directly from the frequency distributions
	* and create new one
	
	forvalues i=1/`B' {
		gsample `N' [aw=n_obs], gen(n_new_`i')
		display "Sample: `i' of `B'"
	}
	
	* Go back to wide
	qui {
		gen D = substr(binD,-2,2)
		gen bin = substr(binD,1,strpos(binD,"_")-1)
		drop binD
		reshape wide n_obs n_new*, i(bin) j(D) string
		destring bin, replace
	}
	
end



*******************************************************
* II.B. Bootstrap price-effect estimates
*******************************************************
* Use simulated samples to compute B price-effects
*******************************************************
* Key Input: bins and frequency distributions of pub and unpub
* Key Output: graph of distribution of price estimates
*******************************************************

	
capture program drop bootstrapPriceFx

program define bootstrapPriceFx, rclass
	
	syntax, [bin(varname numeric) binFactor(integer 4) n_observed_D0(varname numeric) n_observed_D1(varname numeric) numsamples(integer 4) p(integer 4) binWidth(integer 4) minB(integer 4) maxB(integer 4) lB0(integer 4) uB0(integer 4) lB1(integer 4) uB1(integer 4) gammaMin(real 1.0) gammaStep(real 1.0)  deltaMin(integer 4) deltaStep(integer 4) deltaMax(integer 4)]
	
	display "Generating bootstrap samples"
	display "****************************"
	
	qui: sum `n_observed_D0' if bin>`minB' & bin<=`maxB'
	local n1 = r(sum)
	qui: sum `n_observed_D1' if bin>`minB' & bin<=`maxB'
	local n2 = r(sum)
	local ncon = round((`n1' + `n2'),1)
	
	simulatedSamples, bin(`bin') binFactor(`binFactor') n_observed_D0(`n_observed_D0') n_observed_D1(`n_observed_D1') numcontracts(`ncon') numsamples(`numsamples')
	
	forvalues i=1/`numsamples' {
	
		display "Bootstrap iteration no. `i' of `numsamples'"
		
		qui: priceFx, bin(`bin') n_observed_D0(n_new_`i'_0) n_observed_D1(n_new_`i'_1) p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB(`lB1') uB(`uB1') gammaMin(`gammaMin') gammaStep(`gammaStep') binFactor(`binFactor') cfDensityName(tilde_`i')
		local mean_gamma`i' = r(gammaStar)
	
		qui: cfDensities, bin(`bin') n_observed_D0(n_new_`i'_0) n_observed_D1(n_new_`i'_1) p(`p') binWidth(`binWidth') minB(`minB') maxB(`maxB') lB0(`lB0') uB0(`uB0') lB1(`lB1') uB1(`uB1') binFactor(`binFactor') gammaMean(`mean_gamma`i'') cfDensity(tilde_`i') deltaMin(`deltaMin') deltaStep(`deltaStep') deltaMax(`deltaMax')
		local delta`i' = r(deltaHat)
	
		qui: gammaF, bin(`bin') n_observed_D1(n_new_`i'_1) binWidth(`binWidth') lB1(`lB1') binFactor(`binFactor') gammaStar(`mean_gamma`i'') deltaStar(`delta`i'') cfDensity_D1(tilde_`i'_D1)
		local sd_gamma`i' = r(stdev)
		
		foreach y of varlist F_gamma f_gamma gamma_ {
			qui: rename `y' `y'_`i'
		}
		
	}
		
	qui {	

		clear
		set obs `numsamples'
		gen mean_gammaHat = .
		gen sd_gammaHat = .
		gen k=.
		
		forvalues j=1/`numsamples' {
		
			replace k = `j' in `j'
			replace mean_gammaHat = `mean_gamma`j'' in `j'
			replace sd_gammaHat = `sd_gamma`j'' in `j'
		}
		
	}
	
	sum mean_gammaHat
	return scalar se_mean_gamma = r(sd)
	
	sum sd_gammaHat
	return scalar se_sd_gamma = r(sd)

end

