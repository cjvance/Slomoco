#!/bin/bash


function setupDir() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    mkdir -p /Exps/Analysis/Slomoco/Subject_ROI_Analysis_GLM/${mc}_${condition}_${smooth}_${stim}/{tStat,Mask,Cluster,SubStat,Report,Text}
    mkdir -p /Exps/Analysis/Slomoco/Subject_ROI_Analysis_GLM/Report_All
    touch /Exps/Analysis/Slomoco/Subject_ROI_Analysis_GLM/${mc}_${condition}_${smooth}_${stim}/{log_all.txt,log_report.txt,log_clust.txt}

} # End of setupDir


function movetStat() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

	echo -e "\nCalling movingtStat\n"

    3dcopy \
    	${ANOVA}/Ttest/Run1/${mc}_${condition}_${smooth}_${stim}_0.20_ttest_uncor.sent.nii.gz \
    	${TSTAT}/${mc}_${condition}_${smooth}_${stim}_tstat.nii.gz

} # End of movetStat


function clusterStatImg() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling clusterStatImg\n"

    local inputImg=$1
    local roimask=$2

    3dclust \
    	-1Dformat -nosum \
    	-1dindex 0 -1tindex 1 \
    	-savemask ${MASK}/${roimask}.nii.gz \
    	-dxyz=1 1.01 100 \
    	${TSTAT}/${inputImg}.nii.gz

} # End of clusterStatImg


function singleROIMask() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling singleROIMask\n"

    local inputImg=$1
    local roi_num=$2
    local thresh=$3

	3dmerge \
		-2thresh ${thresh} 100 -1clip ${thresh} \
		-1dindex 0 -1tindex 0 \
		-prefix ${CLUST}/${inputImg}_trim_${roi_num}_TEMP.nii.gz \
		${MASK}/${inputImg}.nii.gz

	3dcalc \
		-a ${CLUST}/${inputImg}_trim_${roi_num}_TEMP.nii.gz \
		-expr 'step(a)' \
		-prefix ${CLUST}/${inputImg}_trim_${roi_num}.nii.gz

	rm ${CLUST}/${inputImg}_trim_${roi_num}_TEMP.nii.gz

} # End of singleROIMask


function combineMaskStat() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling combineMaskStat for ${sub}_${sub_roi} with mask ${mcss}\n"

    local input3d=$1
    local inputMask=$2
    local output3d=$3

    3dcalc \
    	-a ${GLM_STAT}/${input3d}.nii.gz \
    	-b ${CLUST}/${inputMask}.nii.gz \
    	-expr 'a*b' \
    	-prefix ${SUBSTAT}/${output3d}.nii.gz

} # End of combineMaskStat


function createReport() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling createReport\n"

    local rptFile=$1

    echo "${roinum_list[*]}"

    printf "${mcss}\n" >> ${REPORT}/${rptFile}.txt
    printf "Subject\t" >> ${REPORT}/${rptFile}.txt

	for rpt_roi in ${roinum_list[*]}; do
		printf "${rpt_roi}_Volume\t${rpt_roi}_tMean\t${rpt_roi}_tMax\t" >> ${REPORT}/${rptFile}.txt
	done

	printf "\n" >> ${REPORT}/${rptFile}.txt

} # End of createReport


function getSubStat() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling getSubStat for ${sub}_${sub_roi}\n"

    local input3d=$1
    local roi=$2

    3dclust \
    	-1Dformat \
    	-1dindex 5 \
    	-1tindex 0 \
    	-orient RPI \
    	0 2 ${SUBSTAT}/${input3d}.nii.gz > ${TEXT}/${input3d}.1D

} # End of getSubStat


function reportSubStat() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    echo -e "\nCalling reportSubStat for ${sub}_${sub_roi}\n"

    local input1d=$1
    local rptFile=$2

    printf "$(awk '$1 !~ /#/ && NR>12 && OFS="\t" {print $1,$11,$13}' ${TEXT}/${input1d}.1D)" >> ${REPORT}/${rptFile}.txt

} # End of reportSubStat



function Main() {
    #------------------------------------------------------------------------
    #
    #  Purpose:
    #
    #
    #    Input:
    #
    #   Output:
    #
    #------------------------------------------------------------------------

    BASE=/Exps/Analysis/Slomoco

    ANOVA=${BASE}/ANOVA/${mc}_${condition}_${smooth}_${stim}
    GLM=${BASE}/GLM/${mc}_${condition}_${smooth}_${stim}

   	RPT_ALL=${BASE}/Subject_ROI_Analysis_GLM/Report_All
   	ROI=${BASE}/Subject_ROI_Analysis_GLM/${mc}_${condition}_${smooth}_${stim}
   	TSTAT=${ROI}/tStat
   	MASK=${ROI}/Mask
   	CLUST=${ROI}/Cluster
   	REPORT=${ROI}/Report
   	SUBSTAT=${ROI}/SubStat
   	TEXT=${ROI}/Text

   	mc_co_sm=${mc}_${condition}_${smooth}
   	mcss=${mc}_${condition}_${smooth}_${stim}

    if [[ ${stim} == "learn" ]]; then
    	roi_list=( 1 2 3 )
    	roinum_list=( Bi_Precuneus L_STG R_STG )
    elif [[ ${stim} == "unlearn" ]]; then
    	roinum_list=( Bi_Precuneus L_STG R_STG Bi_Thalamus L_MFG R_MTG )
    	case ${mc_co_sm} in
    		nomc_nocovar_smooth )
    			roi_list=( 1 2 3 4 5 6 )
    			;;

    		nomc_nocovar_nosmooth )
				roi_list=( 1 2 3 7 5 8 )
				;;

    		slo_nocovar_smooth )
				roi_list=( 1 3 5 2 8 7 )
				;;

			slo_nocovar_nosmooth )
				roi_list=( 1 3 2 8 9 7 )
				;;

			slo_covar_smooth )
				roi_list=( 1 2 3 7 9 6 )
				;;

			slo_covar_nosmooth )
				roi_list=( 5 3 2 9 10 7 )
				;;

    		slo2_nocovar_smooth )
				roi_list=( 1 3 5 2 8 7 )
				;;

			slo2_nocovar_nosmooth )
				roi_list=( 1 3 2 9 8 7 )
				;;

			slo2_covar_smooth )
				roi_list=( 1 2 3 7 9 6 )
				;;

			slo2_covar_nosmooth )
				roi_list=( 7 2 1 9 10 8 )
				;;

			volreg_nocovar_smooth )
				roi_list=( 1 2 3 5 6 7 )
				;;

			volreg_nocovar_nosmooth )
				roi_list=( 1 2 3 7 5 10 )
				;;

			volreg_covar_smooth )
				roi_list=( 1 2 3 4 6 5 )
				;;

			volreg_covar_nosmooth )
				roi_list=( 2 3 4 9 8 7 )
				;;
    	esac
    fi

    case ${stim} in
        "learn" )
            sublist=( sub100 sub105 sub106 sub109
                      sub116 sub117 sub145 sub158
                      sub159 sub160 sub161 sub166
                      sub169 sub173 sub181 sub215
                      sub243 sub241 )
            ;;

        "unlearn" )
            sublist=( sub111 sub120 sub121 sub124
                      sub130 sub132 sub133 sub144
                      sub163 sub164 sub168 sub171
                      sub172 sub176 sub185 sub200 )
            ;;
    esac

    movetStat 2>&1 | tee -a ${ROI}/log_clust.txt
    clusterStatImg ${mcss}_tstat ${mcss}_clust_mask 2>&1 | tee -a ${ROI}/log_clust.txt
    createReport ${mcss}_roi_analysis_report 2>&1 | tee -a ${ROI}/log_clust.txt

	for (( list_num = 0; ${list_num} < ${#roi_list[*]}; list_num++ )); do
		roi=${roi_list[${list_num}]}
		roi_num=${roinum_list[${list_num}]}
		# clip=`expr ${roi} - 1`

		echo -e "\nThe ${roi_num} ROI value for ${mc_co_sm} is ${roi}"
		# echo -e "The clip number is ${clip}\n"

		singleROIMask ${mcss}_clust_mask ${roi_num} ${roi} 2>&1 | tee -a ${ROI}/log_clust.txt
	done

	for sub in ${sublist[*]}; do
		printf "${sub}\t" >> ${REPORT}/${mcss}_roi_analysis_report.txt
		for sub_roi in ${roinum_list[*]}; do

	    	GLM_STAT=${GLM}/${sub}/Run1/Stats

	    	combineMaskStat run1_${sub}_${mcss}_0sec.stats ${mcss}_clust_mask_trim_${sub_roi} ${sub}_${mcss}_${sub_roi} 2>&1 | tee -a ${ROI}/log_report.txt
	    	getSubStat ${sub}_${mcss}_${sub_roi} ${sub_roi} 2>&1 | tee -a ${ROI}/log_report.txt
	    	reportSubStat ${sub}_${mcss}_${sub_roi} ${mcss}_roi_analysis_report 2>&1 | tee -a ${ROI}/log_report.txt
	    	printf "\t" >> ${REPORT}/${mcss}_roi_analysis_report.txt
		done
		printf "\n" >> ${REPORT}/${mcss}_roi_analysis_report.txt
	done
	cat ${REPORT}/${mcss}_roi_analysis_report.txt >> ${RPT_ALL}/report_${stim}.txt
	printf "\n\n" >> ${RPT_ALL}/report_${stim}.txt

} # End of Main

mc_list=( nomc slo slo2 volreg )
smooth_list=( smooth nosmooth )
stim_list=( learn unlearn )

for mc in ${mc_list[*]}; do

	case ${mc} in
		"nomc" )
			condition_list=( nocovar )
			;;

		"slo"|"slo2"|"volreg" )
			condition_list=( covar nocovar )
			;;
	esac

	for condition in ${condition_list[*]}; do

		for smooth in ${smooth_list[*]}; do

			for stim in ${stim_list[*]}; do
				setupDir

				echo -e "\nCalling main ${mc} ${condition} ${smooth} ${stim}\n"

				Main ${mc} ${condition} ${smooth} ${stim} 2>&1 | tee -a /Exps/Analysis/Slomoco/Subject_ROI_Analysis_GLM/${mc}_${condition}_${smooth}_${stim}/log_all.txt

			done

		done

	done

done