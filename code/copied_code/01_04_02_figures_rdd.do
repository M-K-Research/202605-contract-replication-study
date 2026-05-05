
*==============================================================================*
* 01_04_02_figures_rdd.do
* Creates figures with RDD results:
* 	- Main RDD Plots: Figures 2,3,4,A5,A6
*	- Heterogeneus RDD Plots: A9,A10,A11,A12,A13,A14,A15,A16
*	- Coefficient Plot: Figure 5
*==============================================================================*

* I. Preliminaries

	* Open and rename key variables
	use processed_data/analysisCGW.dta, clear
	gen price = amount_expected
	gen pub = fbo_preaward

	* Gen dollar bins and restrict sample	
	gen bin = 3*ceil((price-25)/3) + 25
	keep if bin>10 & bin<=40
	replace bin = bin - 3/2		/* Move half a bin for visual purpuses */
	sort bin
	egen j=seq(), by(bin)



* II. Main RDD figures: 2, 3, 4, A5, and A6

	* List of dependent variables
	rename distance_firm_pop dist
	gen month9 = signeddate_month == 9
	local yvars "pub noffers smallbus foreignfirm dist overruns_any delays_any month9 setaside sap service delays overruns_rel ninmods"

	* List of labels
	local lab_pub "Posted on FedBizOpps"
	local lab_noffers "Number of offers"
	local lab_smallbus "Small business"
	local lab_foreignfirm "Foreign contractor"
	local lab_dist "Log distance between contractor and office"
	local lab_overruns_any "Any cost overruns"
	local lab_delays_any "Any delays"
	local lab_month9 "Last month FY"
	local lab_setaside "Set-aside award"
	local lab_sap "Used simplified acquisition procedures"
	local lab_service "Service"
	local lab_delays "Delays (days)"
	local lab_overruns_rel "Cost-overruns (Share of Award Value)"
	local lab_ninmods "Number of modifications"

	* List of figure numbers
	local nfig_pub "2a"
	local nfig_noffers "2b"
	local nfig_smallbus "3a"
	local nfig_foreignfirm "3b"
	local nfig_dist "3c"
	local nfig_overruns_any "4a"
	local nfig_delays_any "4b"
	local nfig_month9 "A5a"
	local nfig_setaside "A5b"
	local nfig_sap "A5c"
	local nfig_service "A5d"
	local nfig_delays "A6a"
	local nfig_overruns_rel "A6b"
	local nfig_ninmods "A6c"

	* Create figures

	foreach y of local yvars {
		
		egen m`y' = mean(`y'), by(bin)
		
		gr tw (scatter m`y' bin if j==1) ///
		(lfit `y' price if bin<25, lcolor("$color3") lpattern(dash) lwidth(thin)) ///
		(lfit `y' price if bin>25, lcolor("$color3") lpattern(dash) lwidth(thin)) ///
		(qfit `y' price if bin<25, lcolor("$color2") lpattern(dash) lwidth(thin)) ///
		(qfit `y' price if bin>25, lcolor("$color2") lpattern(dash) lwidth(thin)), ///
		xline(25, lpattern(dash) lcolor(gs11)) ///
		xtick(10(5)40) xlabel(10(5)40) ///
		xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) ///
		legend(off) ytitle("`lab_`y''", margin(0 4 0 0))
		
		gr export results/figures/fig`nfig_`y''.pdf, replace
		
	}



* III. Heterogeneity figures: A9, A10, A11, A12, A13, A14, A15, A16

	* Heterogeneity variables
	gen army = agency=="Army"
	gen navy = agency=="Navy"
	gen airf = agency=="AirForce"
	local t_army "Army"
	local t_navy "Navy"
	local t_airf "Air Force"
	rename service serv
	local t_good "Goods"
	local t_serv "Services"
	local hetvars "army navy airf good serv"

	* List of dependent variables
	local yvars "pub noffers foreignfirm overruns_any"

	* List of figure numbers
	local nfig_pub_army = "A9a"
	local nfig_pub_navy = "A9b"
	local nfig_pub_airf = "A9c"
	local nfig_noffers_army = "A10a"
	local nfig_noffers_navy = "A10b"
	local nfig_noffers_airf = "A10c"
	local nfig_foreignfirm_army = "A11a"
	local nfig_foreignfirm_navy = "A11b" 
	local nfig_foreignfirm_airf = "A11c" 
	local nfig_overruns_any_army = "A12a"
	local nfig_overruns_any_navy = "A12b" 
	local nfig_overruns_any_airf = "A12c"
	local nfig_pub_good = "A13a"
	local nfig_pub_serv = "A13b"
	local nfig_noffers_good = "A14a"
	local nfig_noffers_serv = "A14b"
	local nfig_foreignfirm_good = "A15a"
	local nfig_foreignfirm_serv = "A15b"
	local nfig_overruns_any_good = "A16a"
	local nfig_overruns_any_serv = "A16b"

	* Create and save sub-figures

	drop j

	foreach x of local hetvars {
		
		preserve
		
			keep if `x'==1
			sort bin
			egen j=seq(), by(bin)

			foreach y of local yvars {
				
				egen m`y'_`x' = mean(`y'), by(bin)
				
				gr tw (scatter m`y'_`x' bin if j==1) ///
				(lfit `y' price if bin<25, lcolor("$color3") lpattern(dash) lwidth(thin)) ///
				(lfit `y' price if bin>25, lcolor("$color3") lpattern(dash) lwidth(thin)) ///
				(qfit `y' price if bin<25, lcolor("$color2") lpattern(dash) lwidth(thin)) ///
				(qfit `y' price if bin>25, lcolor("$color2") lpattern(dash) lwidth(thin)), ///
				xline(25, lpattern(dash) lcolor(gs11)) ///
				xtick(10(5)40) xlabel(10(5)40) ///
				xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) ///
				legend(off) ytitle("`lab_`y''", margin(0 4 0 0)) title("`t_`x''")
				
				gr save processed_data/temp/fig`nfig_`y'_`x''.gph, replace
			
			}
			
		restore

	}

	* Combine sub-figures

	local j=9

	foreach y of local yvars {
		gr combine processed_data/temp/fig`nfig_`y'_army'.gph processed_data/temp/fig`nfig_`y'_navy'.gph processed_data/temp/fig`nfig_`y'_airf'.gph, ycommon
		gr export results/figures/figA`j'.pdf, replace
		local j = `j'+1
		
	}

	foreach y of local yvars {
		gr combine processed_data/temp/fig`nfig_`y'_good'.gph processed_data/temp/fig`nfig_`y'_serv'.gph, ycommon
		gr export results/figures/figA`j'.pdf, replace
		local j = `j'+1
		
	}





* IV. Heterogeneity by complexity: Figure 5 (plot estimates obtained in 03_03_tables_rdd.do)

	* Figure 5a)
	use processed_data/temp/coefs_fig5_overruns_any.dta, clear
	gr tw  (rcap ub lb q, color(gray)) (scatter b q, mcolor(black)), yline(0, lcolor(gray) lpattern(shortdash)) legend(off) ytitle("Any Overruns", margin(0 4 0 0)) xtitle("Quartile of complexity", margin(0 0 0 2))
	gr export results/figures/fig5a.pdf, replace

	* Figure 5b)
	use processed_data/temp/coefs_fig5_delays_any.dta, clear
	gr tw  (rcap ub lb q, color(gray)) (scatter b q, mcolor(black)), yline(0, lcolor(gray) lpattern(shortdash)) legend(off) ytitle("Any Delays", margin(0 4 0 0)) xtitle("Quartile of complexity", margin(0 0 0 2))
	gr export results/figures/fig5b.pdf, replace

