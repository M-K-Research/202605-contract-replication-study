
*==============================================================================*
* 01_04_01_figures_density.do
* Creates figures based on density analysis (Figs. 1, A3, A4)
*==============================================================================*


* I. Figure 1

	* Compute mean gamma for all subsamples

	use processed_data/density_analysis.dta, clear

	local varList "all1 service0 service1 pc4_complex1  pc4_complex2  pc4_complex3  pc4_complex4"

	forvalues i=1/7 {
				
		local x: word `i' of `varList'
		
		qui: sum mean_gamma_`x'
		local b1_`i'num = r(mean)
		local b1_`i' : di %6.4f r(mean)

	}


	* Shift bins for visualization and fit local polynomial smoothing

	foreach x of local varList {

		replace gamma_`x' = gamma_`x' - 0.005

		qui: lpoly F_gamma_`x'  gamma_`x' if gamma_`x'>-0.4 & gamma_`x'<=0.4, bwidth(0.02) nograph gen(F_`x') at(gamma_`x')

	}


	* Create Figure 1a) Full Distribution

	gr tw (connected F_gamma_all1  gamma_all1 if mod(_n,2)==1, msize(tiny) mcolor(gs13) lcolor(none) xaxis(1 2)) (line F_all1 gamma_all1, lcolor("$color1")) if gamma_all1>-0.4 & gamma_all<=0.4, xline(0, lcolor(gs13)) xline(-`b1_1num', lcolor("$color1") lpattern(shortdash)) ytitle("CDF of Price Effect, F({&gamma})", margin(0 4 0 0)) xtitle("Price Effect, {&gamma}", margin(0 0 0 2) axis(1)) legend(off) xlabel(-0.4(0.1)0.4, axis(1)) xlabel(-`b1_1num' "E[{&gamma}] = `b1_1'", axis(2) notick) xscale(lstyle(none) axis(2)) xtitle("", axis(2))
		
	graph export results/figures/fig1a.pdf, replace
		
		
	* Create Figure 1b) Good vs Service

	gr tw (line F_all1 gamma_all1 if gamma_all1>-0.3 & gamma_all1<=0.1, lcolor(gs13)) (line F_service0 gamma_service0  if gamma_service0>-0.3 & gamma_service0<=0.1) (line F_service1 gamma_service1  if gamma_service1>-0.3 & gamma_service1<=0.1), xline(0, lcolor(gs13)) xline(-`b1_1num', lcolor(gs13) lpattern(shortdash)) xline(-`b1_2num', lcolor("$color2") lpattern(shortdash)) xline(-`b1_3num', lcolor("$color3") lpattern(shortdash)) ytitle("CDF of Price Effect, F({&gamma})", margin(0 4 0 0)) xtitle("Price Effect, {&gamma}", margin(0 0 0 2)) xlabel(-0.3(0.1)0.1) legend(order(1 "All contracts" 2 "Products" 3 "Services") symxsize(*.5) position(11) ring(0) cols(1) rows(3) region(lcolor(none) fcolor(none)))

	graph export results/figures/fig1b.pdf, replace
		

	* Create Figure 1c) Quartile of Complexity
		
	gr tw (line F_pc4_complex1  gamma_pc4_complex1 if gamma_pc4_complex1 >-0.3 & gamma_pc4_complex1 <=0.1, lcolor("$color4")) (line F_pc4_complex2  gamma_pc4_complex2 if gamma_pc4_complex2 >-0.3 & gamma_pc4_complex2 <=0.1) (line F_pc4_complex3 gamma_pc4_complex3 if gamma_pc4_complex3 >-0.3 & gamma_pc4_complex3 <=0.1) (line F_pc4_complex4  gamma_pc4_complex4 if gamma_pc4_complex4 >-0.3 & gamma_pc4_complex4 <=0.1, lcolor("$color1")), xline(0, lcolor(gs13)) xline(-`b1_4num', lcolor("$color4") lpattern(shortdash)) xline(-`b1_5num', lcolor("$color2") lpattern(shortdash)) xline(-`b1_6num', lcolor("$color3") lpattern(shortdash)) xline(-`b1_7num', lcolor("$color1") lpattern(shortdash)) ytitle("CDF of Price Effect, F({&gamma})", margin(0 4 0 0)) xtitle("Price Effect, {&gamma}", margin(0 0 0 2)) xlabel(-0.3(0.1)0.1) legend(order(1 "Complexity Q1" 2 "Complexity Q2" 3 "Complexity Q3" 4 "Complexity Q4") symxsize(*.5) position(11) ring(0) cols(1) rows(5) region(lcolor(none) fcolor(none)))

	graph export results/figures/fig1c.pdf, replace



* II. Figures A3 and A4


	* Recover uncentered dollar bins

	gen binDollars = exp(bin/1000+log(25000))/1000
	gen bin_shifted = bin + `b1_1'*1000
	replace bin_shifted = exp(bin_shifted/1000+log(25000))/1000

					
	* Generate net-of-round-numbers data

	gen bin0 = bin==0
	local roundNumList 1 5 10
	rename (ns_all1 n_all1) (ns_all1_  n_all1_)

	foreach x of local roundNumList {
		
		gen d_`x' = 0
		
		forvalues i=1/60 {
		
			local y = 10*ceil((log(`i'*`x'*1000)-log(25000))*1000/10)
			replace d_`x' = 1 if bin==`y' 
						
		}
	}

	foreach v in _ _D0 _D1 {

		gen diff`v' = ns_all1`v' - n_all1`v'

		gen ns_noRoundNum`v' = n_all1`v'
		reg diff`v' d_* bin0 if bin<=0
		foreach x of local roundNumList {
			replace ns_noRoundNum`v' = ns_noRoundNum`v' + _b[d_`x']*d_`x'	if bin<=0
		}
		qui: sum ns_noRoundNum`v' if bin<=0
		local n1=r(sum)
		qui: sum ns_all1`v' if bin<=0
		local n2=r(sum)
		replace ns_noRoundNum`v' = ns_noRoundNum`v'*`n2'/`n1' if bin<=0
		
		reg diff`v' d_* if bin>0
		foreach x of local roundNumList {
			replace ns_noRoundNum`v' = ns_noRoundNum`v' + _b[d_`x']*d_`x'	if bin>0
		}
		qui: sum ns_noRoundNum`v' if bin>0
		local n1=r(sum)
		qui: sum ns_all1`v' if bin>0
		local n2=r(sum)
		replace ns_noRoundNum`v' = ns_noRoundNum`v'*`n2'/`n1' if bin>0
		
	}

	rename (ns_all1_  n_all1_) (ns_all1 n_all1)


	* Generate net-of price effects and net-of-bunching

	gen ns_noPriceFx = ns_all1_D0 + n_tilde_all1_D1
	gen ns_noBunching = n_tilde_all1_D0 + ns_all1_D1


	* Shift bins for visual

	replace binD = binD-0.125


	* Mean corrected frequencies

	gen groupid=ceil(_n/2)
	egen obsid=seq(), by(groupid)
	egen binWide=mean(binD), by(groupid)
	egen ns2_noRoundNum_D0 = mean(ns_noRoundNum_D0), by(groupid)
	egen ns2_noRoundNum_D1 = mean(ns_noRoundNum_D1), by(groupid)
	egen ns2_noRoundNum_ = mean(ns_noRoundNum_), by(groupid)
	replace binWide = binD if binD>20 & binD<=30
	replace obsid=1 if binD>20 & binD<=30
	replace ns2_noRoundNum_D0 = ns_noRoundNum_D0 if binD>20 & binD<=30
	replace ns2_noRoundNum_D1 = ns_noRoundNum_D1 if binD>20 & binD<=30
	replace ns2_noRoundNum_ = ns_noRoundNum_ if binD>20 & binD<=30


	* Create Figure A3a)

	gr tw (connected ns2_noRoundNum_D0 binWide if obsid==1, msize(vsmall) mcolor(gs14) lcolor(gs14)) (line ns_all1_D0 binD, lcolor("$color1") lwidth(medthick)) (line n_tilde_all1_D0 binD, lpattern(dash) lcolor(none)) if binD>12.5 & binD<37.5, xline(25, lcolor(gs13) lpattern(dash)) xlabel(15(5)35) ytitle("Number of contracts", margin(0 4 0 0)) xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) legend(order(2 "Smoothed Data") symxsize(*.5) position(1) ring(0) cols(1) rows(2) region(lcolor(none) fcolor(none))) ylabel(0(250)1000)
	graph export results/figures/figA3a.pdf, replace


	* Create Figure A3b)

	gr tw (connected ns2_noRoundNum_D1 binWide if obsid==1 & binD>12.5 & binD<37.5, msize(vsmall) mcolor(gs14) lcolor(gs14)) (line ns_all1_D1 binD if binD>12.5 & binD<37.5, lcolor("$color1") lwidth(medthick)) (line n_tilde_all1_D1 binD if binD>12.5 & binD<37.5, lpattern(dash) lcolor(none)) (line ns_all1_D1 bin_shifted if bin_shifted>12.5 & bin_shifted<=37.5, lcolor("$color2") lpattern(shortdash) lwidth(medthick)) , xline(25, lcolor(gs13) lpattern(dash)) xlabel(15(5)35) ytitle("Number of contracts", margin(0 4 0 0)) xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) legend(order(2 "(Smoothed) Data" 4 "Recentered") symxsize(*.5) position(1) ring(0) cols(1) rows(3) region(lcolor(none) fcolor(none))) ylabel(0(200)600)
	graph export results/figures/figA3b.pdf, replace


	* Create Figure A3c)

	lpoly ns_all1_D1 bin_shifted, bwidth(1) nograph at(binD) gen(n_shifted_D1)
	gen n_shifted = ns_all1_D0 + n_shifted_D1
		
	gr tw (connected ns2_noRoundNum_ binWide if obsid==1, msize(vsmall) mcolor(gs14) lcolor(gs14)) (line ns_all1 binD, lcolor("$color1") lwidth(medthick)) (line n_shifted binD, lpattern(dash) lcolor("$color2") lwidth(medthick)) (line n_tilde_all1 binD, lpattern(shortdash) lcolor("$color3") lwidth(medthick)) if binD>12.5 & binD<37.5 , xline(25, lcolor(gs13) lpattern(dash)) xlabel(15(5)35) ytitle("Number of contracts", margin(0 4 0 0)) xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) legend(order(2 "(Smoothed) Data" 3 "Recentered price effect" 4 "Ex-ante prices") symxsize(*.5) position(1) ring(0) cols(1) rows(3) region(lcolor(none) fcolor(none))) ylabel(0(250)1100)
	graph export results/figures/figA3c.pdf, replace


	* Create Figure A4a)

	gr tw (connected ns2_noRoundNum_D0 binWide if obsid==1, msize(vsmall) mcolor(gs14) lcolor(gs14)) (line ns_all1_D0 binD, lcolor("$color1") lwidth(medthick)) (line n_tilde_all1_D0 binD, lcolor("$color2") lpattern(dash) lwidth(medthick)) if binD>12.5 & binD<37.5, xline(25, lcolor(gs13) lpattern(dash)) xlabel(15(5)35) ytitle("Number of contracts", margin(0 4 0 0)) xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) legend(order(2 "(Smoothed) Data" 3 "No bunching") symxsize(*.5) position(1) ring(0) cols(1) rows(2) region(lcolor(none) fcolor(none))) ylabel(0(250)1000)
	graph export results/figures/figA4a.pdf, replace


	* Create Figure A4b)

	gr tw (connected ns2_noRoundNum_D1 binWide if obsid==1 & binD>12.5 & binD<37.5, msize(vsmall) mcolor(gs14) lcolor(gs14)) (line ns_all1_D1 binD if binD>12.5 & binD<37.5, lcolor(gs14)) (line n_tilde_all1_D1 binD if binD>12.5 & binD<37.5, lpattern(dash) lcolor("$color2") lwidth(medthick)) (line ns_all1_D1 bin_shifted if bin_shifted>12.5 & bin_shifted<=37.5, lcolor("$color1") lpattern(shortdash) lwidth(medthick)) , xline(25, lcolor(gs13) lpattern(dash)) xlabel(15(5)35) ytitle("Number of contracts", margin(0 4 0 0)) xtitle("Award amount ({c $|}K)", margin(0 0 0 2)) legend(order(2 "(Smoothed) Data" 4 "Recentered" 3 "No price effects") symxsize(*.5) position(1) ring(0) cols(1) rows(3) region(lcolor(none) fcolor(none))) ylabel(0(200)600)
	graph export results/figures/figA4b.pdf, replace
