#!/bin/bash

#================================================================================
#    Program Name: rus.slomoco.group.sh
#          Author: Chris Vance
#            Date: 6/30/16
#
#     Description: Takes single subject GLMs and analyzes subject groups
#     This was the script used, not rus_slo.grp.sh
#
#
#
#    Deficiencies:
#
#
#
#
#
#================================================================================
#                            FUNCTION DEFINITIONS
#================================================================================


function SetupDir() {
    #------------------------------------------------------------------------
    #
    #  Purpose: To set up the directory structure within the ANOVA Directory required to run this script
    #           and create the log files associated with different functions
    #
    #    Input: None
    #
    #   Output: All directories and log.txt files
    #
    #------------------------------------------------------------------------

    echo -e "\nSetting up Directory Structure\n"

    mkdir -p /Exps/Analysis/Slomoco/ANOVA/${mc}_${condition}_${smooth}_${stim}/{Combo,Mask,Mean,Merge,Report,tTest,Text}/{Run1,Run2,Run3,Run4}
    mkdir -p /Exps/Analysis/Slomoco/ANOVA/{Report_All,tTest_Images}/{Run1,Run2,Run3,Run4}
    touch /Exps/Analysis/Slomoco/ANOVA/${mc}_${condition}_${smooth}_${stim}/{log_all.txt,log_report.txt,log_mask.txt,log_merge.txt,log_ttest.txt}

} # End of SetupDir


function groupImageStats() {
    #------------------------------------------------------------------------
    #
    #  Purpose: To create files with only the tstat and coef sub-bricks from the sent stimuli so analysis can
    #           can begin on just these two sub-bricks. The output creates a list of subject stat files that
    #           are analyzed as a group in subsequent functions.
    #
    #    Input: imgFile=${STATS}/${runsub}_${cond}_0sec.stats.nii.gz
    #           outImage=${COMBO}/${runsub}_${cond}_0sec.stats.nii.gz
    #           brik=[4-5]
    #
    #   Output: outImage=${COMBO}/${runsub}_${cond}_0sec.stats.nii.gz is echoed into the subStatsImgList for later
    #           analyses. The ttestInputList is also populated with the combined images.
    #
    #------------------------------------------------------------------------

    # echo -e "\nCalling groupImageStats\n"

    local imgFile=$1
    local outImage=$2
    local brik=$3

    3dbucket \
    	-prefix ${outImage}.nii.gz \
    	${imgFile}.nii.gz${brik}

    local copyImage=$(basename ${outImage})

    # 3dcopy \
    #     ${outImage}.nii.gz \
    #     ${GTTEST}/${copyImage}.nii.gz

    echo ${outImage}.nii.gz

} # End of groupImageStats


function computeImageMean() {
    #------------------------------------------------------------------------
    #
    #  Purpose: To create seperate mean images from the individual subject tstat and coef images created in groupImageStats.
    #           The mean images for the tstat sub-brick and coef sub-brick are created seperately based on the input given.
    #           The image means are calculated from the subStatsBrikList which is populated by all of the choosen sub-bricks
    #           from the individual subject images.
    #
    #    Input: brik=( Coef Tstat )
    #           outImage=${MEAN}/${cond}_0sec_Mean_{Coef,Tstat}.sent.nii.gz
    #
    #   Output: The output of this function is an image with a single sub-brick containing the group mean of either the tstat
    #           or the coef. The output of this function is stored as the variable grpMean{Tstat,Coef} which later populate
    #           the list grpMeanList
    #
    #------------------------------------------------------------------------

    # echo -e "\nCalling computeImageMean\n"

    local brik=$1
    local outImage=$2

    subStatsBrikList=subStats${brik}List # this causes different lists to be created based on the input brik but they will be refered to by the same variable
    subStatsBrikList=()

    if [[ ${brik} == "Coef" ]]; then
        subStatsBrikList+=( `echo ${subStatsImgList[*]/%.gz/.gz[0]}` )
    else
        subStatsBrikList+=( `echo ${subStatsImgList[*]/%.gz/.gz[1]}` )
    fi

    # The if statement above creates either a subStatsTstatList or a subStatCoefList depending on the input brik. The regular expression stuff replaces the
    # ending of the input file from .gz to .gz[0] or .gz[1] depending on the input (Coef=[0] and Tstat=[1]).

    3dMean \
        -verbose \
        -prefix ${outImage}.nii.gz \
        ${subStatsBrikList[*]}

    echo ${outImage}.nii.gz

} # End of computeImageMean


function meanImageStats() {
    #------------------------------------------------------------------------
    #
    #  Purpose: To take the mean Coef image and mean Tstat image and put them together into a single mean stat image. The stat
    #           image is created from a list containing a tstat image and a coef image. If the statpar for the tstat image
    #           needs to be changed, the 3drefit command can be utilized.
    #
    #    Input: outImage=${MEAN}/${cond}_0sec_Group_StatsMean.sent.nii.gz
    #           grpMeanList=( ${cond}_0sec_Mean_Coef.sent.nii.gz ${cond}_0sec_Mean_Tstat.sent.nii.gz )
    #
    #   Output: The output of this function is echoed into the variable grpStatsMean which is used in many of the subsequent
    #           analysis steps. This function also outputs a text file containing the information retrieved with 3dinfo. This
    #           text file is used to capture the "statpar" for sub-brick 1 (Tstat) to be used in later analysis steps.
    #
    #------------------------------------------------------------------------

    # echo -e "\nCalling meanImageStats\n"

    local outImage=$1

    3dbucket \
        -prefix ${MEAN}/${outImage}.nii.gz \
        ${grpMeanList[*]} # grpMeanList contains the seperate Coef and Tstat images

    3dinfo -verb ${MEAN}/${outImage}.nii.gz > ${TEXT}/${outImage}.info.txt
    # This line captures everything from 3dinfo and puts it into a text file for later

    # 3drefit \
    #     -substatpar 1 fitt ${statpar} \
    #     ${outImage}.nii.gz

    # 3dinfo -verb ${outImage}.nii.gz > ${outImage}.refit.info.txt

    echo ${MEAN}/${outImage}

} # End of meanImageStats


function subNoNeg() {
    #------------------------------------------------------------------------
    #
    #  Purpose: This function takes each individual subject and and gets rid of all the negative activation on a subject to subject basis.
    #           Even though this function was called in Main, the output was not used because, for Slomoco, we are looking
    #           at both positive and negative activation. This function is also meant to prepare the individual subjects to
    #           eventually be run through the mean image to obtain the individual subject stats.
    #
    #    Input: imgFile=${COMBO}/${runsub}_{cond}_0sec.sent.nii.gz
    #           outImageNoNeg=${MERGE}/${runsub}_${cond}_0sec_noNeg.sent.nii.gz
    #
    #   Output: The output of this function (outImageNoNeg) is an individual subject image with no negative activation. In
    #           other group analyses, this image would be used to determine each subject's activation in the context of the
    #           the whole group. In this anaylsis, we did not use these images because we want positive and negative activation.
    #
    #------------------------------------------------------------------------

    # echo -e "\nCalling subNoNeg\n"

    local imgFile=$1
    local outImageNoNeg=$2

    # echo ${imgFile}

    3dmerge \
        -1noneg \
        -1dindex 0 \
        -1tindex 1 \
        -prefix ${outImageNoNeg}.nii.gz \
        ${imgFile}

    # echo "${outImageNoNeg}.nii.gz"

} # End of subNoNeg


# function statMask() {
#     #------------------------------------------------------------------------
#     #
#     #  Purpose:
#     #
#     #
#     #    Input:
#     #
#     #   Output:
#     #
#     #------------------------------------------------------------------------

#     # echo -e "\nCalling statMask\n"

#     local imgFile=$1
#     local outMaskImg=$2
#     local cluster=$3
#     local plvl=$4

#     fittCMD="fitt_p2t(${plvl}000,${statpar})"

#     echo "The ccalc experssion is ${fittCMD}"

#     thresh=$(ccalc -expr ${fittCMD})

#     echo "The threshold is ${thresh}"

#     3dmerge \
#         -1tindex 1 \
#         -dxyz=1 \
#         -1clust_order 1.01 ${cluster} \
#         -1thresh ${thresh} \
#         -prefix ${MASK}/${outMaskImg}.nii.gz \
#         ${imgFile}.nii.gz

#     # echo ${MASK}/${outMaskImg}

# } # End of statMask

function statMask_noCor() {
    #------------------------------------------------------------------------
    #
    #  Purpose: To create a mask from the Coef and Tstat images created in the function meanImageStats. The group meaned data, consisting of two sub-bricks (Coef and Tstat),
    #           is thresholded with a numeric t-value determined using the afni format fitt_p2t input into the ccalc command. A group statistical mask is subsequently created
    #           by thresholding the group meaned image with the calulated threshold and no correction value.
    #
    #    Input: imgFile=${MEAN}/${cond}_0sec_Group_StatsMean.sent.nii.gz
    #           outMaskImg=${MASK}/${cond}_0sec_Group_StatsMean_${plvl}_uncor_mask.sent.nii.gz
    #           plvl=0.20 (for this analysis, all thresholding was done with a p-value of 0.20 but that can be modified)
    #
    #   Output: Mistakenly, the output of this function was initially a statistical dataset instead of a mask dataset. The script was ran again with the addition of the -1clust
    #           flag within the afni command 3dmerge to ensure that the the results were identical when the -mask file in 3dttest++ is a statistical dataset vs. a mask dataset.
    #           The results do not change when the output of this function is a mask or a statistical dataset.
    #
    #------------------------------------------------------------------------

    # echo -e "\nCalling statMask\n"

    local imgFile=$1
    local outMaskImg=$2
    local plvl=$3

    fittCMD="fitt_p2t(${plvl}000,${statpar})"

    echo "The ccalc experssion is ${fittCMD}"

    thresh=$(ccalc -expr ${fittCMD})

    echo "The threshold is ${thresh}"

    # I found that the output of this function does not produce a mask file and instead creates a statistical file that seems to work in the place of a statistical mask
    # with the 3dttest++ command. The -1clust 1 2 flag was added to ensure the results were the same, even with the output of this function as a statistical file.

    3dmerge \
        -1tindex 1 \
        -1clust 1 2 \
        -dxyz=1 \
        -1thresh ${thresh} \
        -prefix ${MASK}/${outMaskImg}.nii.gz \
        ${imgFile}.nii.gz

    # echo ${MASK}/${outMaskImg}

} # End of statMask_noCor

function oneSample_tTest() {
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

    # echo -e "\nCalling oneSample_tTest\n"

    local maskFile=$1
    local outImage=$2

    local copyImage=$(basename ${outImage})

    echo "${ttestInputList[*]}"
    # echo "${maskFile}.nii.gz"
    # echo "${outImage}.nii.gz"

    3dttest++ \
        -setA ${ttestInputList[*]} \
        -mask ${maskFile}.nii.gz \
        -prefix ${outImage}.nii.gz

    3dcopy \
        ${outImage}.nii.gz \
        ${TIMG}/${copyImage}.nii.gz

} # End of oneSample_tTest


function getClusterStats_tTest() {
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

    local imgFile=$1
    local rptFile=$2
    local plvl=$3


    fittCMD="fitt_p2t(${plvl}000,${statpar})"
    echo "The ccalc experssion is ${fittCMD}"
    thresh=$(ccalc -expr ${fittCMD})
    echo "The threshold is ${thresh}"

    printf "${cond}\t${RUN}\t${thresh}\n" > ${REPORT}/${rptFile}.txt
    printf "Cluster\tVolume\tTmean\tMax\tX\tY\tZ\tROI\n" >> ${REPORT}/${rptFile}.txt

    3dclust \
        -1Dformat \
        -1dindex 0 \
        -1tindex 1 \
        -orient RAI \
        -1thresh ${thresh} 0 100 ${TTEST}/${imgFile}.nii.gz > ${REPORT}/${imgFile}.1D

    printf "$(awk '$1 !~ /#/ && NR>11 && OFS="\t" {print $1,$11,$13,$14,$15,$16}' ${REPORT}/${imgFile}.1D)" > ${REPORT}/clust_trim.txt

    line_num=$( cat ${REPORT}/clust_trim.txt | wc -l )
    cat -n ${REPORT}/clust_trim.txt > ${REPORT}/clusters.txt

    for (( l = 1; l <= ${line_num}+1 ; l++ )); do

        # touch ${REPORT}/temp.txt
        # touch ${REPORT}/roi.txt

        head -${l} ${REPORT}/clusters.txt | tail -1 > ${REPORT}/temp.txt
        x=$(awk 'FS="\t" {print $5}' ${REPORT}/temp.txt)
        y=$(awk 'FS="\t" {print $6}' ${REPORT}/temp.txt)
        z=$(awk 'FS="\t" {print $7}' ${REPORT}/temp.txt)
        echo "${x} and ${y} and ${z}"

        whereami ${x} ${y} ${z} -tab -atlas CA_ML_18_MNIA -space MNI | grep "0.0" | sed 's/---.*//' | cut -f 3 > ${REPORT}/roi.txt

        paste -d "\t" ${REPORT}/temp.txt ${REPORT}/roi.txt >> ${REPORT}/${rptFile}.txt

        rm ${REPORT}/temp.txt
        rm ${REPORT}/roi.txt
    done

    cp ${REPORT}/${rptFile}.txt ${RPT_ALL}/${rptFile}.txt

    cat ${RPT_ALL}/${rptFile}.txt >> ${RPT_ALL}/report_all.txt
    printf "\n\n" >> ${RPT_ALL}/report_all.txt

} # End of getClusterStats_tTest



function main() {
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

    echo "${mc}"
    echo "${condition}"
    echo "${smooth}"
    echo "${stim}"

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

        "test" )
            sublist=( sub100 sub111 )
            ;;

        * )
            help_message
            ;;
    esac

    cond=${mc}_${condition}_${smooth}_${stim}

    for r in {1..4}; do
    	subStatsImgList=()
        ttestInputList=()
    	for sub in ${sublist[*]}; do
    		RUN=Run${r}
            runsub=run${r}_${sub}
    		echo -e "\n${RUN}"
    		echo -e "${sub}"

            BASE=/Exps/Analysis/Slomoco

            GLM=${BASE}/GLM/${mc}_${condition}_${smooth}_${stim}
            STATS=${GLM}/${sub}/${RUN}/Stats
            GTTEST=${GLM}/TTEST/${sub}/${RUN}

            RPT_ALL=${BASE}/ANOVA/Report_All/${RUN}
            TIMG=${BASE}/ANOVA/tTest_Images/${RUN}
            ANOVA=${BASE}/ANOVA/${mc}_${condition}_${smooth}_${stim}
            COMBO=${ANOVA}/Combo/${RUN}
            MASK=${ANOVA}/Mask/${RUN}
            MEAN=${ANOVA}/Mean/${RUN}
            MERGE=${ANOVA}/Merge/${RUN}
            REPORT=${ANOVA}/Report/${RUN}
            TTEST=${ANOVA}/tTest/${RUN}
            TEXT=${ANOVA}/Text/${RUN}

    		subStatsImgList+=( `groupImageStats ${STATS}/${runsub}_${cond}_0sec.stats ${COMBO}/${runsub}_${cond}_0sec.sent [4-5]` )

            ttestInputList+=(${COMBO}/${runsub}_${cond}_0sec.sent.nii.gz)

    	done

        echo "${subStatsImgList[*]}"

        grpMeanCoef=$(computeImageMean Coef ${MEAN}/${cond}_0sec_Mean_Coef.sent)
        grpMeanTstat=$(computeImageMean Tstat ${MEAN}/${cond}_0sec_Mean_Tstat.sent)
        # echo -e "\nThe grpMeanStuff is ${grpMeanCoef}\n"
        # echo -e "\nThe grpMeanStuff is ${grpMeanTstat}\n"
        # BasegrpMeanCoef=$(basename ${grpMeanCoef})
        # BasegrpMeanTstat=$(basename ${grpMeanTstat})
        # echo -e "\nThe Basename stuff is ${BasegrpMeanCoef}\n"
        # echo -e "\nThe Basename stuff is ${BasegrpMeanTstat}\n"

        grpMeanList=()
        grpMeanList+=(${grpMeanCoef} ${grpMeanTstat})
        # echo -e "\nThe grpMeanList is"
        # echo "${grpMeanList[*]}"

        grpStatsMean=$(meanImageStats ${cond}_0sec_Group_StatsMean.sent)
        grpStatsMeanBase=$(basename ${grpStatsMean})
        statpar=$(awk '$3 ~ /fitt/ && NR>18 {print $6}' ${TEXT}/${grpStatsMeanBase}.info.txt)
        echo -e "\nstatpar is ${statpar}"
        echo -e "grpStatsMean is ${grpStatsMean}\n"

        for subImg in ${subStatsImgList[*]}; do
            noNeg=$(basename ${subImg} .sent.nii.gz)
            noNegImg=${noNeg}_noNeg.sent
            # echo "${MERGE}/${noNegImg}"
            # echo "${subImg}"

            subNoNeg ${subImg} ${MERGE}/${noNegImg} 2>&1 | tee -a ${ANOVA}/log_merge.txt
        done

        if [[ ${smooth} == "smooth" ]]; then
            fwhm_num=6
        else
            fwhm_num=0
        fi

        # 3dClustSim -fwhm ${fwhm_num} -nodec -pthr 0.20 0.10 0.05 0.01 -nxyz 91 109 91 -dxyz 2.0 2.0 2.0 > ${TEXT}/clust_sim.sent.txt

        # for plvl in {0.10,0.05,0.01}; do

        #     outMask=$(basename ${grpStatsMean} .sent)
        #     outStatMask=${outMask}_${plvl}_cor_mask.sent

        #     case ${plvl} in
        #         # "0.20" )
        #         #     clust=$(awk '$1 ~ /0.200000/ && NR>7 && NR<12 {print $3}' ${TEXT}/clust_sim.sent.txt)
        #         #     ;;
        #         "0.10" )
        #             clust=$(awk '$1 ~ /0.100000/ && NR>7 && NR<12 {print $3}' ${TEXT}/clust_sim.sent.txt)
        #             ;;
        #         "0.05" )
        #             clust=$(awk '$1 ~ /0.050000/ && NR>7 && NR<12 {print $3}' ${TEXT}/clust_sim.sent.txt)
        #             ;;
        #         "0.01" )
        #             clust=$(awk '$1 ~ /0.010000/ && NR>7 && NR<12 {print $3}' ${TEXT}/clust_sim.sent.txt)
        #             ;;
        #     esac

        #     echo -e "\nThe cluster threshold is ${clust}\n"

        #     echo -e "\nThe mask will be named ${outStatMask}\n"

        #     statMask ${grpStatsMean} ${outStatMask} ${clust} ${plvl} 2>&1 | tee -a ${ANOVA}/log_mask.txt

        #     # echo -e "\nThe inputMask will be ${MASK}/${outStatMask}\n"

        #     oneSample_tTest ${MASK}/${outStatMask} ${TTEST}/${cond}_${plvl}_ttest_cor.sent 2>&1 | tee -a ${ANOVA}/log_ttest.txt
        #     # echo -e "\nThe ttestInputList is"
        #     # echo "${ttestInputList[*]}"
        # done

        for plvl in 0.20; do

            outMask=$(basename ${grpStatsMean} .sent)
            outStatMask=${outMask}_${plvl}_uncor_mask.sent

            statMask_noCor ${grpStatsMean} ${outStatMask} ${plvl} 2>&1 | tee -a ${ANOVA}/log_mask.txt

            oneSample_tTest ${MASK}/${outStatMask} ${TTEST}/${cond}_${plvl}_ttest_uncor.sent 2>&1 | tee -a ${ANOVA}/log_ttest.txt

        done

        for plvl in 0.20; do
            for correction in uncor; do
                tstatImg=${cond}_${plvl}_ttest_${correction}.sent
                outTable=${cond}_${plvl}_table.sent
                getClusterStats_tTest ${tstatImg} ${outTable} ${plvl} 2>&1 | tee -a ${ANOVA}/log_report.txt
            done
        done
    done

} # End of main

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
                SetupDir

				echo -e "\nCalling main ${mc} ${condition} ${smooth} ${stim}\n"

				main ${mc} ${condition} ${smooth} ${stim} 2>&1 | tee -a /Exps/Analysis/Slomoco/ANOVA/${mc}_${condition}_${smooth}_${stim}/log_all.txt

			done

		done

	done

done

# mc_list=( nomc slo slo2 volreg )
# smooth_list=( smooth nosmooth )
# stim_list=( learn unlearn )
#
# for mc in ${mc_list[*]}; do
#
# 		case ${mc} in
# 		"nomc" )
# 			condition_list=( nocovar )
# 			;;
#
# 		"slo"|"slo2"|"volreg" )
# 			condition_list=( covar nocovar )
# 			;;
# 	esac
#
# 	for condition in ${condition_list[*]}; do
#
# 		for smooth in ${smooth_list[*]}; do
#
# 			for stim in ${stim_list[*]}; do
#
# 				echo -e "\nCalling main ${mc} ${condition} ${smooth} ${stim}\n"
# 				main ${mc} ${condition} ${smooth} ${stim}
#
# 			done
#
# 		done
#
# 	done
#
# done
#
#     whereami \
#         -coord_file ${REPORT}/${imgFile}.1D[13,14,15] \
#         -tab \
#         -atlas CA_ML_18_MNIA \
#         -space MNI > ${REPORT}/${imgFile}_whereami.txt
#
#     cat ${REPORT}/${imgFile}_whereami.txt | grep "0.0" | awk '$1,$2 ~ /[:alpha:]/ && FS="\t" && OFS=" " {print $3,$4,$5,$6,$7,$8}' | sed 's/---//' | sed 's/[0-9].*//' >> ${REPORT}/wai_trim.txt
#
#     paste -d "\t" ${REPORT}/clust_trim.txt ${REPORT}/wai_trim.txt >> ${REPORT}/${rptFile}.txt