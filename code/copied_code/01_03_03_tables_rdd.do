
*==============================================================================*
* 01_03_03_tables_rdd.do
* Creates tables with RDD results:
* 	Tables 1, 2, B4, and the coefficients plotted in Figure 5
*==============================================================================*

* I. Data preparation

	* Open data, rename key variables and select sample
	use processed_data/analysisCGW.dta, clear
	gen price = amount_expected
	gen pub = fbo_preaward
	keep if price>10 & price<=40

	* List of dependent variables and labels
	local yVarList "noffers oneoffer distance_firm_pop foreignfirm  new_firmofficepop smallbus overruns_any overruns_rel delays_any delays nmods"	
	local lbe_noffers "Number of offers"
	local lbe_oneoffer "One offer"
	local lbe_distance_firm_pop "Log distance firm-office"
	local lbe_foreignfirm "Foreign firm"
	local lbe_new_firmofficepop "New firm"
	local lbe_smallbus "Small business"
	local lbe_overruns_any "Any cost-overrun"
	local lbe_overruns_rel "Cost-overruns (relative dollars)"
	local lbe_delays_any "Any delay"
	local lbe_delays "Delays (days)"
	local lbe_nmods    "Number of modifications"


	* Define round number dummies
	gen rnum5 = ((int(price/5)*5) == price) if price != .
	gen rnum10 = ((int(price/10)*10) == price) if price != .
		
	* Quartiles of complexity
	xtile pc4_complex = mean4_overruns_rel , n(4)
		
			
	* Prep for bunching correction bounds

		* Merge with bunching shares (to compute bounds)

		gen logAmount = log(1000*price) - log(25000)
		gen bin = 0.01*ceil(logAmount/0.01)
		replace bin = round(bin*1000,1)
		merge m:1 bin using processed_data/bunching.dta
		drop if _merge ==2
		drop _m
		rename bin binLogs
		foreach zVar of varlist excessB* {
			replace `zVar' = . if pub==1
		}

		* Identify top and bottom shares of outcome variables

		levelsof binLogs if missing(excessB_all1)==0, local(bins)
		local n : word count `bins'
		
		foreach y of local yVarList {

			sort binLogs pub `y' awdnbr
			egen obs_id=seq() if binLogs>=-50 & binLogs<=0, by(binLogs pub)

			gen top_`y' = 0
			gen bottom_`y' = 0

			forvalues i=1/`n' {
				
				local b : word `i' of `bins'
				qui: sum excessB_all1 if binLogs==`b' & pub==0
				local crit`i' = r(mean)
				qui: count if missing(`y')==0 & binLogs==`b' & pub==0
				local nobs`i' = r(N)
				local n_chop_low`i' = ceil(`crit`i''*`nobs`i'')
				local n_chop_high`i' = `nobs`i'' - `n_chop_low`i''
				replace bottom_`y' = 1 if obs_id<=`n_chop_low`i'' & bin==`b' & pub==0
				replace top_`y' = 1 if obs_id>`n_chop_high`i'' & bin==`b' & pub==0

			}
			
			drop obs_id
			
		}	
				

	* Merge with price effect correction and create key correction variables			
	rename binLogs bin
	merge m:1 bin using processed_data/priceFxCorrectionInput.dta
	rename bin binLogs
	drop if _m==2
	gen alpha0 = (logAmount<=0)*(1-pi_D) + (1-F_gamma)*pi_D
	gen alpha1 = (logAmount>0)*(1-pi_D) + F_gamma*pi_D
	gen beta0 = alpha0*logAmount + rho1*pi_D
	gen beta1 = alpha1*logAmount + rho2*pi_D

	* Back to dollar bins
	gen bin = 2.5*ceil(price/2.5)
	replace bin = bin - 2.5/2
	sort bin
	egen j=seq(), by(bin)
		
	* Variables for regression	
	local bcrit = 25
	local ccrit = `bcrit' + 0.000001
	gen above = bin>`bcrit'
	gen x = (price-`bcrit')
	gen above_x = above*x

	* Round number correction
	foreach y of local yVarList {
		qui: reg `y' rnum5 rnum10
		replace `y' = `y' - _b[rnum5]*rnum5 - _b[rnum10]*rnum10
	}

	* Donut hole indicators (windows = +- 0.5, 1, 1.5, 2, 2.5, 3 K$)
	forvalues dh =1/6 {
		gen dhsample_`dh' = 1
		replace dhsample_`dh' = 0 if abs(x)<=`dh'/4
		
	}



* II. Table 1: RDD estimates

	* Loop over dependent variables and compute estimates

	foreach y of local yVarList {

		* OLS

		reg `y' above x above_x
		local t_ols_`y' : di %6.4f _b[above]
		local se_ols_`y' : di %6.4f _se[above]	
		
		
		* CCT (2014)
		
		rdrobust `y' price, c(`ccrit') kernel(uniform) h(5 5)
		local t_cct_`y' : di %6.4f e(tau_cl)
		local se_cct_`y' : di %6.4f e(se_tau_cl) 

		
		* Price effect correction (see paper for details)
		
		reg `y' alpha0 alpha1 beta0 beta1, nocons
		local t_corr_`y' = _b[alpha1] - _b[alpha0]
		local t_corr_`y' : di %6.4f `t_corr_`y''
		
		
		* Bounds accounting for manipulation (based on Gerard, Rokkanen, Rothe)
		
		reg `y' above x above_x if bottom_`y'==0
		local t_ols_low_`y' : di %6.4f _b[above]
		reg `y' above x above_x `controls' if top_`y'==0
		local t_ols_high_`y' : di %6.4f _b[above]
		
		
		* Price effect correction + manipulation bounds
		
		reg `y' alpha0 alpha1 beta0 beta1 if bottom_`y'==0, nocons
		local t_corr_low_`y' = _b[alpha1] - _b[alpha0]
		local t_corr_low_`y' : di %6.4f `t_corr_low_`y''
		reg `y' alpha0 alpha1 beta0 beta1 if top_`y'==0, nocons
		local t_corr_high_`y' = _b[alpha1] - _b[alpha0]
		local t_corr_high_`y' : di %6.4f `t_corr_high_`y''
		
	}
	
	
	* Create LaTeX table

	file open RDDcorrTab using results/tables/tab1.tex, replace write

	file write RDDcorrTab "\begin{tabular}{l|ccccc}" _n
	file write RDDcorrTab "\toprule" _n
	file write RDDcorrTab " \multirow{3}{*}{Dependent Variable} & \multirow{2}{*}{OLS} & \multirow{2}{*}{CCT} & Price Effect & Manipulation & Price Effect + \\" _n
	file write RDDcorrTab " & & & Adjustment & Bounds & Manip. Bounds \\" _n
	file write RDDcorrTab " & (1) & (2) & (3) & (4) & (5) \\" _n
	file write RDDcorrTab " \midrule" _n
	file write RDDcorrTab " & & & & & \\" _n 
	
	foreach y of local yVarList {
		
			file write RDDcorrTab "`lbe_`y'' & `t_ols_`y'' & `t_cct_`y'' & \multirow{2}{*}{`t_corr_`y''} & \multirow{2}{*}{[ `t_ols_low_`y'' , `t_ols_high_`y'' ]} & \multirow{2}{*}{[ `t_corr_low_`y'' , `t_corr_high_`y'' ]} \\" _n
			file write RDDcorrTab " & (`se_ols_`y'') & (`se_cct_`y'') & & & \\" _n
			file write RDDcorrTab " & & & & & \\" _n
		
	}
	
	file write RDDcorrTab " \bottomrule" _n
	file write RDDcorrTab "\end{tabular}"
	file close RDDcorrTab
	
	
	* Create dataset with results
	
	preserve 
	
		* Initialize dataset and variables

		clear
		local nobs : word count `yVarList'
		set obs `nobs'
		gen y = ""
		gen tau_ols = .
		gen se_ols = .
		gen tau_cct = .
		gen se_cct = .
		gen tau_corr = .
		gen tau_ols_low = .
		gen tau_ols_high = .
		gen tau_corr_low = .
		gen tau_corr_high = .

		
		* Fill with estimates
		
		local j=1
		
		foreach y of local yVarList {
		
			replace y = "`lbe_`y''" in `j'
			replace tau_ols       = `t_ols_`y'' in `j'
			replace se_ols        = `se_ols_`y'' in `j'
			replace tau_cct       = `t_cct_`y'' in `j'
			replace se_cct        = `se_cct_`y'' in `j'
			replace tau_corr      = `t_corr_`y'' in `j'
			replace tau_ols_low   = `t_ols_low_`y'' in `j'
			replace tau_ols_high  = `t_ols_high_`y'' in `j'
			replace tau_corr_low  = `t_corr_low_`y'' in `j'
			replace tau_corr_high = `t_corr_high_`y'' in `j'
			
			local j = `j'+1
		
		}
	
	
		* Standard errors as new obs
	
		egen i=seq()
		expand 2
		sort i
		egen j=seq(), by(i)
		replace y = "" if j==2
		replace tau_ols = se_ols if j==2
		replace tau_cct = se_cct if j==2
		replace tau_corr      = . if j==2
		replace tau_ols_low   = . if j==2
		replace tau_ols_high  = . if j==2
		replace tau_corr_low  = . if j==2
		replace tau_corr_high = . if j==2
		drop se_*
		
		* Format string
		
		tostring tau_*, replace format(%6.4f) force
		
		
		* Add parentheses and brackets
		
		replace tau_ols = tau_ols + " " if j==1
		replace tau_ols = "(" + tau_ols + ")" if j==2
		replace tau_cct = tau_cct + " " if j==1
		replace tau_cct = "(" + tau_cct + ")" if j==2
		replace tau_corr = "" if j==2
		gen tau_bounds = "[" + tau_ols_low + "," + tau_ols_high + "]" if j==1
		gen tau_corr_bounds = "[" + tau_corr_low + "," + tau_corr_high + "]" if j==1
		
		
		* Final formatting and save table as data
		
		keep y tau_ols tau_cct tau_corr tau_bounds tau_corr_bounds
		rename y DependentVariable 
		rename tau_ols OLS 
		rename tau_cct CCT
		rename tau_corr PriceEffectAdj
		rename tau_bounds ManipulationBounds
		rename tau_corr_bounds PriceEffectAdjAndBounds
		
		save processed_data/temp/tab1.dta, replace
		
	restore 
	
	
	* Program to display Table 1 as Stata output
	
	capture program drop tab1
	program define tab1
		qui: use processed_data/temp/tab1.dta, clear
		display " "
		display " "
		display "******************************************************************"
		display "Table 1: Reduced-form RDD Estimates and Corrections"
		display "******************************************************************"
		display " "
		list , sep(100) noobs nocompress ab(100) ds
		display " "
		display "******************************************************************"
	end

	

* III. Table 2: IV estimates with firm fixed-effects
	
	* Firm fixed effects
	egen long duns_coded = group(duns)

	* Placeholder for sample dummy
	gen d_sample = .

	* Labels
	label var overruns_any "Any Cost Overrun"
	label var delays_any "Any Delay"
	label var noffers "Number of Offers"
	label var pub "Estimate (S.E.)"

	* Start loop over 3 dependent variables 
	
	local j=1
	
	foreach y of varlist overruns_any delays_any noffers {

		* Round number correction
		qui: reg `y' rnum5 rnum10
		replace `y' = `y' - _b[rnum5]*rnum5 - _b[rnum10]*rnum10
		
		* Save sample with firm fixed effects to keep constant across columns
		qui reghdfe `y' i.signeddate_fy , absorb(duns_coded)
		replace d_sample = e(sample) ==1
		
		* IV regression with no fixed effects 
		ivreg2 `y' x above_x (pub  = above ) if d_sample==1
		local iv_`j' : di %6.3f _b[pub]
		local se_`j' : di %6.3f _se[pub]
		local N_`j' : di %6.0fc e(N)
		eststo iv_`y'
		
		* IV regression with fixed effects 
		ivreghdfe `y' x above_x o.duns_coded (pub  = above ) if d_sample==1, absorb(duns_coded)
		local iv_fe_`j' : di %6.3f _b[pub]
		local se_fe_`j' : di %6.3f _se[pub]
		local N_fe_`j' : di %6.0fc e(N)
		eststo iv_fe_`y'
		
		local j = `j'+1

	}

	
	* Create LaTeX table
	
	file open RDDfeTab using results/tables/tab2.tex, replace write

	file write RDDfeTab "\begin{tabular}{lcccccc} \hline \hline" _n
	file write RDDfeTab "  & \\[-5pt]" _n
	file write RDDfeTab "  & \multicolumn{2}{c}{Any Cost Overrun}  & \multicolumn{2}{c}{Any Delay}  & \multicolumn{2}{c}{Number of Offers} \\[5pt] " _n
	file write RDDfeTab "   & (1) & (2) & (3) & (4) & (5) & (6) \\\hline" _n
	file write RDDfeTab " &  &  &  &  &  & \\" _n
	file write RDDfeTab "Estimate & `iv_1' & `iv_fe_1' & `iv_2' & `iv_fe_2' &  `iv_3' & `iv_fe_3' \\" _n
	file write RDDfeTab "S. E. & (`se_1') & (`se_fe_1') & (`se_2') & (`se_fe_2') & (`se_3') & (`se_fe_3') \\" _n
	file write RDDfeTab " &  &  &  &  &  &  \\" _n
	file write RDDfeTab "`lab_`fe_var'' Fixed Effects? & No & Yes & No & Yes & No & Yes \\" _n
	file write RDDfeTab "Number of Observations & `N_1' & `N_fe_1' & `N_2' & `N_fe_2' & `N_3' & `N_fe_3' \\ \hline" _n
	file write RDDfeTab "\end{tabular}" _n
	file close RDDfeTab

	
	* Program to display Table 2 as Stata output
		
	capture program drop tab2
		program define tab2
		display " "
		display " "
		display "******************************************************************"
		display "Table 2: IV-RD Estimates Controlling for Firm Fixed-Effects"
		display "******************************************************************"
			esttab iv_overruns_any iv_fe_overruns_any iv_delays_any iv_fe_delays_any iv_noffers iv_fe_noffers, keep(pub) se nostar b(3) indicate(Firm Fixed Effects = duns_coded)  varwidth(20)  modelwidth(20) label

	end
	
	

* IV. Heterogeneous effects on performance by complexity 
* 	(no table generated, but save coefficients for Figure 5)


	* Complexity quartile dummies (and interaction with discontinuity)
	
	forvalues q = 1/4 {
		gen pc_`q' = pc4_complex == `q'
		gen a_`q' = (above == 1 & pc_`q' == 1)
	}
	
	
	* Loop over two performance variables
	
	foreach y of varlist overruns_any delays_any {
	
		* Estimate RD
		
		reg `y' x  above_x pc_* a_*
	
	
		* Save estimates as dataset
			
		preserve
		
			clear
			set obs 4
			egen q=seq()
			gen b = .
			gen se = .
			gen ub = .
			gen lb = .
			forvalues q = 1/4 {
				replace b = _b[a_`q'] if q==`q'	
				replace se = _se[a_`q'] if q==`q'	
			}
			replace ub = b + 1.96*se
			replace lb = b - 1.96*se
			
			save processed_data/temp/coefs_fig5_`y'.dta, replace
			
		restore

	}
	


* V. Table B4: Donut RDDs

	
	* Estimation
	
	gen dhsample_0 = 1
	
	local yVarList "noffers distance_firm_pop smallbus overruns_any delays_any nmods"
	
	foreach y of local yVarList {
			
		forvalues dh = 0/6 {
			
			reg `y' above x above_x if dhsample_`dh' == 1
		 	local t_ols_`y'_`dh' : di %6.4f _b[above]
			local se_ols_`y'_`dh' : di %6.4f _se[above]
		
		}
	
	}
	
	
	* Create LaTeX table

	file open RDDtabDH using results/tables/tabB4.tex, replace write

	file write RDDtabDH "\begin{tabular}{l|ccccccc}" _n
	file write RDDtabDH "\toprule" _n
	file write RDDtabDH " \multirow{3}{*}{Dependent Variable} & \multirow{2}{*}{OLS} &  &  & & & & \\" _n
	file write RDDtabDH " & & 1K & 2K & 3K & 4K & 5K & 6K \\" _n
	file write RDDtabDH " & (1) & (2) & (3) & (4) & (5) & (6) & (7) \\" _n
	file write RDDtabDH " \midrule" _n
	file write RDDtabDH " & & & & & & & \\" _n 
	
	foreach y of local yVarList {
		
		file write RDDtabDH "`lbe_`y'' & `t_ols_`y'_0' & `t_ols_`y'_1' & `t_ols_`y'_2' & `t_ols_`y'_3'  & `t_ols_`y'_4' & `t_ols_`y'_5' & `t_ols_`y'_6' \\" _n
		file write RDDtabDH " & (`se_ols_`y'_0') & (`se_ols_`y'_1') & (`se_ols_`y'_2') & (`se_ols_`y'_3') & (`se_ols_`y'_4') & (`se_ols_`y'_5') & (`se_ols_`y'_6') \\" _n
		file write RDDtabDH " & & & & & & & \\" _n
		
	}
	
	file write RDDtabDH " \bottomrule" _n
	file write RDDtabDH "\end{tabular}"
	file close RDDtabDH
	
	
	* Create dataset with estimates
	
	preserve
	
		* Initialize dataset and variables

		clear
		local nobs : word count `yVarList'
		set obs `nobs'
		gen y = ""
		forvalues dh = 0/6 {
			gen b_`dh' = .
			gen se_`dh' = .
		}
		
		
		* Fill with estimates
		
		local j=1
		foreach y of local yVarList {
			replace y = "`lbe_`y''" in `j'
			forvalues dh = 0/6 {
				replace b_`dh'  = `t_ols_`y'_`dh'' in `j'
				replace se_`dh' = `se_ols_`y'_`dh'' in `j'
			}
			local j = `j'+1
		}
	
	
		* Standard errors as new obs
	
		egen i=seq()
		expand 2
		sort i
		egen j=seq(), by(i)
		replace y = "" if j==2
		forvalues dh = 0/6 {
			replace b_`dh' = se_`dh' if j==2
		}
		drop se_*
		
		
		* Format string 
		
		tostring b_*, replace format(%6.4f) force
		
		
		* Add parentheses to s.e.
		
		forvalues dh = 0/6 {
			replace b_`dh' = b_`dh' + " " if j==1
			replace b_`dh' = "(" + b_`dh' + ")" if j==2
		}
		
		
		* Final formatting and save table as data
		
		keep y b_*
		rename y DependentVariable 
		rename b_0 Baseline
		rename b_1 Donut500 
		rename b_2 Donut1000 
		rename b_3 Donut1500 
		rename b_4 Donut2000 
		rename b_5 Donut2500
		rename b_6 Donut3000
		
		save processed_data/temp/tabB4.dta, replace
		
	restore 
	
	
	* Program to display Table B.4 as Stata output
	
	capture program drop tabB4
	program define tabB4
		qui: use processed_data/temp/tabB4.dta, clear
		display " "
		display " "
		display "******************************************************************"
		display "Table B.4: Baseline and Donut-RD specifications"
		display "******************************************************************"
		display " "
		list , sep(100) noobs nocompress ab(100) ds
		display " "
		display "******************************************************************"
	end
	
