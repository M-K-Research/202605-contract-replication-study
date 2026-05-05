
*==============================================================================*
* 01_03_02_tables_density.do
* Creates table with price effects estimates from density analysis (Table B3)
*==============================================================================*


* I. Create LaTeX table

	use processed_data/density_analysis.dta, clear

	local varList "all1 service0 service1 pc4_complex1  pc4_complex2  pc4_complex3  pc4_complex4"

	forvalues i=1/7 {
		
		local x: word `i' of `varList'
		
		qui: sum mean_gamma_`x'
		local b1_`i'num = r(mean)
		local b1_`i' : di %6.4f r(mean)
		qui: sum se_mean_gamma_`x'
		local b2_`i'num = r(mean)
		local b2_`i' : di %6.4f r(mean)
		qui: sum sd_gamma_`x'
		local b3_`i'num = r(mean)
		local b3_`i' : di %6.4f r(mean)
		qui: sum se_sd_gamma_`x'
		local b4_`i'num = r(mean)
		local b4_`i' : di %6.4f r(mean)
	}


	file open priceFxTab using results/tables/tabB3.tex, replace write

	file write priceFxTab "\begin{tabular}{l|c|cc|cccc}" _n
	file write priceFxTab "\toprule" _n
	file write priceFxTab "\multirow{4}{*}{Estimate / Sample} & \multirow{2}{*}{All} & \multirow{2}{*}{Goods} & \multirow{2}{*}{Services} & \multicolumn{4}{c}{Complexity} \\" _n
	file write priceFxTab " & & & & Q1 & Q2 & Q3 & Q4 \\" _n
	file write priceFxTab " & & & & & & & \\" _n
	file write priceFxTab " & (1) & (2) & (3) & (4) & (5) & (6) & (7) \\" _n
	file write priceFxTab " \midrule" _n
	file write priceFxTab " & & & & & & \\" _n 
	file write priceFxTab "Mean $(\mu_\gamma)$ & `b1_1' & `b1_2' & `b1_3' & `b1_4' & `b1_5' & `b1_6' & `b1_7' \\" _n
	file write priceFxTab " & (`b2_1') & (`b2_2') & (`b2_3') & (`b2_4') & (`b2_5') & (`b2_6') & (`b2_7') \\" _n
	file write priceFxTab " & & & & & & \\" _n 
	file write priceFxTab "Standard & `b3_1' & `b3_2' & `b3_3' & `b3_4' & `b3_5' & `b3_6' & `b3_7' \\" _n
	file write priceFxTab "Deviation $(\sigma_\gamma)$& (`b4_1') & (`b4_2') & (`b4_3') & (`b4_4') & (`b4_5') & (`b4_6') & (`b4_7') \\" _n
	file write priceFxTab " & & & & & & \\" _n 
	file write priceFxTab " \bottomrule" _n
	file write priceFxTab "\end{tabular}"
	file close priceFxTab


* II. Program to display Table B3 as Stata output

	* Results are constant variables saved in dataset, so need to reshape and reformat

	keep mean_gamma_* se_mean_gamma_* sd_gamma_* se_sd_gamma_*
	duplicates drop
	gen i=1
	reshape long mean_gamma_ se_mean_gamma_ sd_gamma_ se_sd_gamma_, i(i) j(j) string
	rename m x_mean
	rename sd x_sd
	rename se_m x_sem
	rename se_s x_ses
	drop i
	rename j i
	reshape long x_, i(i) j(j) string
	format x_ %6.4f
	reshape wide x_, i(j) j(i) string


	* Sort and rename estimates

	gen i=1 if j=="mean"
	replace i=2 if j=="sem"
	replace i=3 if j=="sd"
	replace i=4 if j=="ses"
	sort i
	drop i

	replace j = "Mean" if j=="mean"
	replace j = "(s.e. of mean)" if j=="sem"
	replace j = "Std. Dev." if j=="sd"
	replace j = "(s.e. of s.d.)" if j=="ses"
	rename j Estimate


	* Rename subsamples

	rename x_all1 All
	rename x_service0 Goods
	rename x_service1 Services
	rename x_pc4_complex1 CompQ1
	rename x_pc4_complex2 CompQ2
	rename x_pc4_complex3 CompQ3
	rename x_pc4_complex4 CompQ4
	order Estimate All Goods Services CompQ1 CompQ2 CompQ3 CompQ4


	* Add parentheses to standard errors

	tostring *, replace format(%6.4f) force
	foreach x of varlist All Goods Services Comp* {
		replace `x' = "(" + `x' + ")" if Estimate!="Mean" & Estimate!="Std. Dev."
		replace `x' = `x' + " " if Estimate=="Mean" | Estimate=="Std. Dev."
	}


	* Save estimates as dataset 

	save processed_data/temp/tabB3.dta, replace


	* Program to print Table B3
		
	capture program drop tabB3
		program define tabB3
		qui: use processed_data/temp/tabB3.dta, clear
		display " "
		display " "
		display "************************************"
		display "Table B.3: Estimated Price Effect"
		display "************************************"
		list , noobs nocompress

	end
