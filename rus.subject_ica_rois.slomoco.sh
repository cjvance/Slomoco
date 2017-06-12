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

    mkdir -p /Exps/Analysis/Slomoco/Subject_ROI_Analysis_ICA/${stim_smooth}_${mc}/{zStat,Mask,Cluster,SubStat,Report,Text}
    mkdir -p /Exps/Analysis/Slomoco/Subject_ROI_Analysis_ICA/Report_All
    touch /Exps/Analysis/Slomoco/Subject_ROI_Analysis_ICA/${stim_smooth}_${mc}/{log_all.txt,log_report.txt,log_clust.txt}

} # End of setupDir


function movezStat() {
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

	echo -e "\nCalling movingzStat\n"

    3dcopy \
    	${CA_MASK}/${st_sm_mc}_${ic}_mask.nii.gz \
    	${ZSTAT}/${st_sm_mc}_${ic}_mask.nii.gz

} # End of movezStat


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
    	-1dindex 0 -1tindex 0 \
    	-savemask ${MASK}/${roimask}.nii.gz \
    	-dxyz=1 1.01 100 \
    	${ZSTAT}/${inputImg}.nii.gz

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
		-prefix ${CLUST}/${st_sm_mc}_${roi_num}_mask.nii.gz

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

    echo -e "\nCalling combineMaskStat for ${sub}_${sub_roi} with mask ${st_sm_mc}_${sub_roi}_mask"

    local input3d=$1
    local inputMask=$2
    local output3d=$3

    3dcalc \
    	-a ${SUBDATA}/${input3d}.nii.gz \
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

    echo "${ic_roi_list[*]}"

    printf "${st_sm_mc}\n" >> ${REPORT}/${rptFile}.txt
    printf "Subject\t" >> ${REPORT}/${rptFile}.txt

	for rpt_roi in ${ic_roi_list[*]}; do
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

    echo -e "\nCalling getSubStat for ${sub}_${sub_roi}"

    local input3d=$1
    local roi=$2

    3dclust \
    	-1Dformat \
    	-1dindex 0 \
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

    echo -e "\nCalling reportSubStat for ${sub}_${sub_roi}"

    local input1d=$1
    local rptFile=$2
    local clust_num=$3

	if [[ ${clust_num} = "0" ]]; then
	    printf "0\t0\t0" >> ${REPORT}/${rptFile}.txt
	else
		printf "$(awk '$1 !~ /#/ && NR>12 && OFS="\t" {print $1,$11,$13}' ${TEXT}/${input1d}.1D)" >> ${REPORT}/${rptFile}.txt
	fi

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

   	st_sm_mc=${stim_smooth}_${mc}

    BASE=/Exps/Analysis/Slomoco

    CA_MASK=${BASE}/Mean_ICs/Cluster_Analysis/${st_sm_mc}/Mask

   	RPT_ALL=${BASE}/Subject_ROI_Analysis_ICA/Report_All
   	ROI=${BASE}/Subject_ROI_Analysis_ICA/${st_sm_mc}
   	ZSTAT=${ROI}/zStat
   	MASK=${ROI}/Mask
   	CLUST=${ROI}/Cluster
   	REPORT=${ROI}/Report
   	SUBSTAT=${ROI}/SubStat
   	TEXT=${ROI}/Text



   	case ${stim_smooth} in
   		LRU )
			ic_roi_list=( IC1_R_MTG IC12_L_MFG IC15_R_MTG IC15_Precuneus IC22_L_MFG_sup IC22_Precuneus IC22_L_MFG_inf IC33_L_MFG IC33_Precuneus_ant IC33_Precuneus_post IC50_R_STG IC50_L_STG )
			ic_list=( IC1 IC12 IC15 IC22 IC33 IC50 )
			case ${mc} in
				nomc )
					mask_val_list=( 2 5 1 4 3 5 6 2 4 12 1 2 )
					sublist=( sub002 sub006 sub010 sub014 \
            				  sub018 sub022 sub026 sub030 \
            		 		  sub034 sub038 sub042 sub046 \
            				  sub050 sub054 sub058 sub062 \
            				  sub066 sub070 )
					;;

				slo )
					mask_val_list=( 2 4 1 6 2 6 5 2 4 0 2 1 )
					sublist=( sub003 sub007 sub011 sub015 \
            				  sub019 sub023 sub027 sub031 \
            				  sub035 sub039 sub043 sub047 \
            				  sub051 sub055 sub059 sub063 \
            				  sub067 sub071 )
					;;

				slo2 )
					mask_val_list=( 2 4 1 6 2 6 5 2 4 0 2 1 )
					sublist=( sub004 sub008 sub012 sub016 \
            				  sub020 sub024 sub028 sub032 \
            				  sub036 sub040 sub044 sub048 \
            				  sub052 sub056 sub060 sub064 \
            				  sub068 sub072 )
					;;

				volreg )
					mask_val_list=( 2 5 1 4 2 5 6 2 4 11 2 1 )
					sublist=( sub001 sub005 sub009 sub013 \
            				  sub017 sub021 sub025 sub029 \
            				  sub033 sub037 sub041 sub045 \
            				  sub049 sub053 sub057 sub061 \
            				  sub065 sub069 )

					;;
			esac
   			;;

   		LRU_NS )
			ic_roi_list=( IC8_R_MTG IC22_L_MFG IC22_Precuneus IC25_R_STG IC25_L_STG IC29_R_MTG )
			ic_list=( IC8 IC22 IC25 IC29 )
			case ${mc} in
				nomc )
					mask_val_list=( 1 2 5 2 1 3 )
					sublist=( sub002 sub006 sub010 sub014 \
            				  sub018 sub022 sub026 sub030 \
            		 		  sub034 sub038 sub042 sub046 \
            				  sub050 sub054 sub058 sub062 \
            				  sub066 sub070 )
					;;

				slo )
					mask_val_list=( 1 2 5 1 2 4 )
					sublist=( sub003 sub007 sub011 sub015 \
            				  sub019 sub023 sub027 sub031 \
            				  sub035 sub039 sub043 sub047 \
            				  sub051 sub055 sub059 sub063 \
            				  sub067 sub071 )
					;;

				slo2 )
					mask_val_list=( 1 2 5 1 2 4 )
					sublist=( sub004 sub008 sub012 sub016 \
            				  sub020 sub024 sub028 sub032 \
            				  sub036 sub040 sub044 sub048 \
            				  sub052 sub056 sub060 sub064 \
            				  sub068 sub072 )
					;;

				volreg )
					mask_val_list=( 1 2 6 1 2 3 )
					sublist=( sub001 sub005 sub009 sub013 \
            				  sub017 sub021 sub025 sub029 \
            				  sub033 sub037 sub041 sub045 \
            				  sub049 sub053 sub057 sub061 \
            				  sub065 sub069 )
					;;

			esac
			;;

		ULRU )
			ic_roi_list=( IC5_R_MTG IC5_Precuneus IC5_L_MFG IC25_L_MFG IC45_L_MFG_sup IC45_L_MFG_inf IC45_Precuneus )
			ic_list=( IC5 IC25 IC45 )
			case ${mc} in
				nomc )
					mask_val_list=( 1 4 5 4 4 5 10 )
					sublist=( sub002 sub006 sub010 sub014 \
            				  sub018 sub022 sub026 sub030 \
            		 		  sub034 sub038 sub042 sub046 \
            				  sub050 sub054 sub058 sub062 )
					;;

				slo )
					mask_val_list=( 1 4 0 4 4 5 7 )
					sublist=( sub003 sub007 sub011 sub015 \
            				  sub019 sub023 sub027 sub031 \
            				  sub035 sub039 sub043 sub047 \
            				  sub051 sub055 sub059 sub063 )
					;;

				slo2 )
					mask_val_list=( 1 4 0 4 4 5 7 )
					sublist=( sub004 sub008 sub012 sub016 \
            				  sub020 sub024 sub028 sub032 \
            				  sub036 sub040 sub044 sub048 \
            				  sub052 sub056 sub060 sub064 )
					;;

				volreg )
					mask_val_list=( 1 4 5 4 4 5 9 )
					sublist=( sub001 sub005 sub009 sub013 \
            				  sub017 sub021 sub025 sub029 \
            				  sub033 sub037 sub041 sub045 \
            				  sub049 sub053 sub057 sub061 )
					;;
			esac
			;;

		ULRU_NS )
			ic_roi_list=( IC26_R_MTG IC26_L_MFG IC37_R_STG_ant IC37_L_STG_ant IC37_L_STG_post IC37_R_STG_post IC45_Precuneus )
			ic_list=( IC26 IC37 IC45 )
			case ${mc} in
				nomc )
					mask_val_list=( 1 2 1 3 0 0 5 )
					sublist=( sub002 sub006 sub010 sub014 \
            				  sub018 sub022 sub026 sub030 \
            		 		  sub034 sub038 sub042 sub046 \
            				  sub050 sub054 sub058 sub062 )
					;;

				slo )
					mask_val_list=( 1 6 2 3 4 5 6 )
					sublist=( sub003 sub007 sub011 sub015 \
            				  sub019 sub023 sub027 sub031 \
            				  sub035 sub039 sub043 sub047 \
            				  sub051 sub055 sub059 sub063 )
					;;

				slo2 )
					mask_val_list=( 1 5 2 3 4 5 6 )
					sublist=( sub004 sub008 sub012 sub016 \
            				  sub020 sub024 sub028 sub032 \
            				  sub036 sub040 sub044 sub048 \
            				  sub052 sub056 sub060 sub064 )
					;;

				volreg )
					mask_val_list=( 1 4 1 3 0 0 6 )
					sublist=( sub001 sub005 sub009 sub013 \
            				  sub017 sub021 sub025 sub029 \
            				  sub033 sub037 sub041 sub045 \
            				  sub049 sub053 sub057 sub061 )
					;;
			esac
   	esac

    case ${stim_smooth} in
        "LRU"|"LRU_NS" )
            # sublist=( sub100 sub105 sub106 sub109 \
            #           sub116 sub117 sub145 sub158 \
            #           sub159 sub160 sub161 sub166 \
            #           sub169 sub173 sub181 sub215 \
            #           sub243 sub241 )
            SUBDATA=${BASE}/Individual_ICs/subICs_${stim_smooth}/lst_subj_ru_learn_${mc}
            ;;

        "ULRU"|"ULRU_NS" )
            # sublist=( sub111 sub120 sub121 sub124 \
            #           sub130 sub132 sub133 sub144 \
            #           sub163 sub164 sub168 sub171 \
            #           sub172 sub176 sub185 sub200 )
            SUBDATA=${BASE}/Individual_ICs/subICs_${stim_smooth}/lst_subj_ru_unlearn_${mc}
            ;;
    esac

	createReport ${st_sm_mc}_roi_analysis_report 2>&1 | tee -a ${ROI}/log_clust.txt

    for ic in ${ic_list[*]}; do
		# echo -e "\ncalling movezStat\n"
		movezStat 2>&1 | tee -a ${ROI}/log_clust.txt
		clusterStatImg ${st_sm_mc}_${ic}_mask ${st_sm_mc}_${ic}_clust_mask 2>&1 | tee -a ${ROI}/log_clust.txt
	done

	for (( list_num = 0; ${list_num} < ${#mask_val_list[*]}; list_num++ )); do
		roi=${ic_roi_list[${list_num}]}
		roi_num=${mask_val_list[${list_num}]}

		ic=$(echo "${roi}" | cut -f 1 -d "_")

		echo -e "\nThe current IC is ${ic}\n"

		if [[ ${roi_num} != "0"  ]]; then
			# clip=`expr ${roi} - 1`
			echo -e "\nThe ROI value for ${roi} within ${st_sm_mc} is ${roi_num}"
			# echo -e "The clip number is ${clip}\n"
			singleROIMask ${st_sm_mc}_${ic}_clust_mask ${roi} ${roi_num} 2>&1 | tee -a ${ROI}/log_clust.txt
		fi
	done

	for sub in ${sublist[*]}; do
		printf "${sub}\t" >> ${REPORT}/${st_sm_mc}_roi_analysis_report.txt
		for (( list_num = 0; list_num < ${#ic_roi_list[*]}; list_num++ )); do

			sub_roi=${ic_roi_list[list_num]}
			mask_val=${mask_val_list[list_num]}

			ic=$(echo "${sub_roi}" | cut -f 1 -d "_")

	    	combineMaskStat ${sub}_${ic}_s1 ${st_sm_mc}_${sub_roi}_mask ${sub}_${st_sm_mc}_${sub_roi} 2>&1 | tee -a ${ROI}/log_report.txt
	    	getSubStat ${sub}_${st_sm_mc}_${sub_roi} ${sub_roi} 2>&1 | tee -a ${ROI}/log_report.txt
	    	reportSubStat ${sub}_${st_sm_mc}_${sub_roi} ${st_sm_mc}_roi_analysis_report ${mask_val} 2>&1 | tee -a ${ROI}/log_report.txt
	    	printf "\t" >> ${REPORT}/${st_sm_mc}_roi_analysis_report.txt
		done
		printf "\n" >> ${REPORT}/${st_sm_mc}_roi_analysis_report.txt
	done
	cat ${REPORT}/${st_sm_mc}_roi_analysis_report.txt >> ${RPT_ALL}/report_${stim_smooth}.txt
	printf "\n\n" >> ${RPT_ALL}/report_${stim_smooth}.txt

} # End of Main

stim_smooth_list=( LRU LRU_NS ULRU ULRU_NS )
mc_list=( nomc slo slo2 volreg )

for stim_smooth in ${stim_smooth_list[*]}; do
	for mc in ${mc_list[*]}; do
		setupDir

		echo -e "\nCalling main for ${stim_smooth} ${mc}\n"

		Main ${stim_smooth} ${mc} 2>&1 | tee -a /Exps/Analysis/Slomoco/Subject_ROI_Analysis_ICA/${stim_smooth}_${mc}/log_all.txt
	done
done