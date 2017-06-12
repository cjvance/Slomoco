#!/bin/bash


function SetupDir() {
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

    mkdir -p /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/${stim_smooth}_${mc}/{Mean,Clusterize,Mask,Report,Text}
    mkdir -p /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/Report_All
    touch /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/${stim_smooth}_${mc}/{log_all.txt,log_clusterized.txt,log_mask.txt}
    touch /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/Report_All/report_all.txt

} # End of SetupDir


function MoveImg() {
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

    echo -e "\n\nMoving IC Mean Image Files for ${stim_smooth}_${mc}_${ic}\n"

    3dcopy \
        ${IC_IMG}/${stim_smooth}_${mc}_${ic}_s1_mean.nii.gz \
        ${MEAN}/${stim_smooth}_${mc}_${ic}.nii.gz

    # 3drefit \
    #     -space MNI \
    #     # -substatpar 0 fizt \
    #     -prefix ${MEAN}/${stim_smooth}_${mc}_${ic}_mni.nii.gz \
    #     ${IC_IMG}/${stim_smooth}_${mc}_${ic}_s1_mean.nii.gz

} # End of MoveImg


function getClusterStats() {
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

    echo -e "\n\nClusterizing Mean IC Images for ${stim_smooth}_${mc}_${ic}\n"

    echo "The threshold is ${thresh}"

    printf "${ic}\t${stim_smooth}\t${mc}\t${thresh}\n" > ${REPORT}/${rptFile}.txt
    printf "Cluster\tVolume\tZmean\tMax\tX\tY\tZ\tROI\n" >> ${REPORT}/${rptFile}.txt

    3dclust \
        -orient RAI \
        -1Dformat \
        -1dindex 0 \
        -1tindex 0 \
        -prefix ${CLUST}/${imgFile}_${thresh}.nii.gz \
        -1thresh ${thresh} 0 100 ${MEAN}/${imgFile}.nii.gz > ${REPORT}/${imgFile}.1D

    printf "$(awk '$1 !~ /#/ && NR>11 && OFS="\t" {print $1,$11,$13,$14,$15,$16}' ${REPORT}/${imgFile}.1D)" >> ${REPORT}/clust_trim_${ic}.txt

    line_num=$( cat ${REPORT}/clust_trim_${ic}.txt | wc -l )
    cat -n ${REPORT}/clust_trim_${ic}.txt > ${REPORT}/clusters_${ic}.txt

    for (( l = 1; l <= ${line_num}+1 ; l++ )); do

        # touch ${REPORT}/temp.txt
        # touch ${REPORT}/roi.txt

        head -${l} ${REPORT}/clusters_${ic}.txt | tail -1 > ${REPORT}/temp.txt
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

} # End of getClusterStats



function clusterThreshImg() {
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

    local inputImg=$1
    local roimask=$2

    3dclust \
        -1Dformat -nosum \
        -1dindex 0 -1tindex 1 \
        -savemask ${MASK}/${roimask}.nii.gz \
        -dxyz=1 1.01 100 \
        ${CLUST}/${inputImg}.nii.gz

} # End of clusterThreshImg



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

    echo -e "Calling Main for ${stim_smooth}_${mc}"

    case ${stim_smooth} in
    	"LRU" )
    		ic_list=( IC1 IC12 IC15 IC22 IC33 IC50 )
    		;;

    	"LRU_NS" )
			ic_list=( IC8 IC22 IC25 IC29 IC33 )
			;;

    	"ULRU" )
			ic_list=( IC5 IC8 IC25 IC45 )
			;;

		"ULRU_NS" )
			ic_list=( IC11 IC25 IC26 IC37 IC45 )
			;;
	esac

	BASE=/Exps/Analysis/Slomoco/Mean_ICs
	IC_IMG=${BASE}/IC_Images
	CA=${BASE}/Cluster_Analysis

    RPT_ALL=${BASE}/Cluster_Analysis/Report_All
	MEAN=${CA}/${stim_smooth}_${mc}/Mean
    CLUST=${CA}/${stim_smooth}_${mc}/Clusterize
	MASK=${CA}/${stim_smooth}_${mc}/Mask
	REPORT=${CA}/${stim_smooth}_${mc}/Report
	TEXT=${CA}/${stim_smooth}_${mc}/Text


	for (( iter = 0; iter < ${#ic_list[*]}; iter++ )); do
        for ic in ${ic_list[iter]}; do
		    echo -e "\n\n${ic}"

        case ${plvl} in
            0.20 )
                thresh=1.282
                ;;
            0.10 )
                thresh=1.645
                ;;
            0.05 )
                thresh=1.96
                ;;
        esac

            MoveImg

            statImg=${stim_smooth}_${mc}_${ic}
            clustImg=${stim_smooth}_${mc}_${ic}_${thresh}
            maskImg=${stim_smooth}_${mc}_${ic}_mask
            rptFile=${stim_smooth}_${mc}_${ic}

            getClusterStats ${statImg} ${rptFile} ${plvl} 2>&1 | tee -a /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/${stim_smooth}_${mc}/log_clusterized.txt
            clusterThreshImg ${clustImg} ${maskImg} 2>&1 | tee -a /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/${stim_smooth}_${mc}/log_mask.txt
        done
	done

} # End of Main

plvl=$1
# stim_smooth_list=( LRU LRU_NS ULRU ULRU_NS )
# mc_list=( nomc slo slo2 volreg )

stim_smooth_list=( LRU )
mc_list=( volreg )

for stim_smooth in ${stim_smooth_list[*]}; do
	for mc in ${mc_list[*]}; do
        SetupDir

		echo -e "\nCalling Main for ${mc} ${stim_smooth}\n"

		Main ${stim_smooth} ${mc} ${plvl} 2>&1 | tee -a /Exps/Analysis/Slomoco/Mean_ICs/Cluster_Analysis/${stim_smooth}_${mc}/log_all.txt

	done
done

