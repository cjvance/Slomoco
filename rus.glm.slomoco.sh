#!/bin/bash
#================================================================================
#    Program Name: rus.glm.nomc.sh
#          Author: Chris Vance
#            Date: 2/11/16
#
#     Description: Performs a general linear model on the russian single subject
#                  data
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


function setup_dir() {
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

    echo -e "\nSetting up Directory Structure\n"
    mkdir -p /Exps/Analysis/Slomoco/GLM/${mc}_${condition}_${smooth}_${stim}/${sub}/${RUN}/{1D,Images,Stats,Mask,Fitts,Errts}
    mkdir -p /Exps/Analysis/Slomoco/GLM/${mc}_${condition}_${smooth}_${stim}/TTEST/{Results,${sub}/${RUN}}
    touch ${GLM}/{log_mask.txt,log_motion.txt,log_convolve.txt,log_plot.txt,log_bucket.txt,log_alphacor.txt}

} # End of setup_dir


function regress_masking() {
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

    echo -e "\nComputing automask for regression\n"

    input4d=$1
    fullmask=fullmask_${input4d}

    3dAutomask \
        -prefix ${MASK}/${fullmask}.nii.gz \
        ${FUNC}/${input4d}.nii.gz

    # echo -e "\n============================ Variable Names for regress_masking  ============================\n"
    # echo "Input: ${input4d}"
    # echo "Output: ${fullmask}"
    # echo "${FUNC}/${input4d}.nii.gz"
    # echo "${MASK}/${fullmask}.nii.gz"

} # End of regress_masking


function regress_motion() {
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

    echo -e "\nregress_motion has been called\n"

    input1d=$1
    output1d=$2

    1d_tool.py \
        -infile ${ACCESS}/${input1d}.1D \
        -select_rows {0..$} -set_nruns 1 \
        -demean \
        -write ${ID}/motion.${output1d}_demean.1D

    1d_tool.py \
        -infile ${ACCESS}/${input1d}.1D \
        -select_rows {0..$} -set_nruns 1 \
        -derivative -demean \
        -write ${ID}/motion.${output1d}_deriv.1D

    1dplot \
        -jpeg ${IMAGES}/motion.${output1d}_demean \
        ${ID}/motion.${output1d}_demean.1D

    1dplot \
        -jpeg ${IMAGES}/motion.${output1d}_deriv \
        ${ID}/motion.${output1d}_deriv.1D

    # echo -e "\n============================ Variable Names for regress_motion  ============================\n"
    # echo "Input: ${input1d}.1D"
    # echo "Output: ${output1d}.1D"
    # echo "motion.${output1d}_demean.1D"
    # echo "motion.${output1d}_deriv.1D"
    # echo "motion.${output1d}_demean.jpg"
    # echo "motion.${output1d}_demean.jpg"

} # End of regress_motion


function regress_convolve_nocovar() {
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

    echo -e "\nregress_convolve_nocovar has been called\n"

    delay=$1
    input4d=$2
    model="WAV(18.0,${delay},4,6,0.2,2)"

    output4d=${3}_${delay}sec
    fullmask=fullmask_${input4d}

    input1d=( cue_stim.1D    tone_block.1D    sent_block.1D )

    3dDeconvolve \
        -input ${FUNC}/${input4d}.nii.gz \
        -polort A \
        -mask ${MASK}/${fullmask}.nii.gz \
        -local_times \
        -num_stimts 2 \
            -censor ${STIM}/censor.${input1d[0]} \
        -stim_times 1 ${STIM}/stim.${input1d[1]} "${model}" \
            -stim_label 1 Tone \
        -stim_times 2 ${STIM}/stim.${input1d[2]} "${model}" \
            -stim_label 2 Sent \
        -xout \
            -x1D ${ID}/${output4d}.xmat.1D \
            -xjpeg ${IMAGES}/${output4d}.xmat.jpg \
        -jobs 12 \
        -fout -tout \
        -errts ${ERRTS}/${output4d}.errts.nii.gz \
        -fitts ${FITTS}/${output4d}.fitts.nii.gz \
        -bucket ${STATS}/${output4d}.stats.nii.gz

    # echo -e "\n============================ Variable Names for regress_convolve_nocovar  ============================\n"
    # echo "${delay}"
    # echo "Input: ${input4d}"
    # echo "Output: ${output4d}"
    # echo "${FUNC}/${input4d}.nii.gz"
    # echo "${MASK}/${fullmask}.nii.gz"
    # echo "${STIM}/censor.${input1d[0]}"
    # echo "${STIM}/stim.${input1d[1]} "${model}""
    # echo "${STIM}/stim.${input1d[2]} "${model}""
    # echo "${ID}/${output4d}.xmat.1D"
    # echo "${IMAGES}/${output4d}.xmat.jpg"
    # echo "${ERRTS}/${output4d}.errts.nii.gz"
    # echo "${FITTS}/${output4d}.fitts.nii.gz"
    # echo "${STATS}/${output4d}.stats.nii.gz"

} # End of regress_convolve_nocovar


function regress_convolve_covar() {
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

    echo -e "\nregress_convolve has been called\n"  # This is will display a message in the terminal which will help to keep
                                                    # track of what function is being run.
    delay=$1
    input4d=$2
    model="WAV(18.0,${delay},4,6,0.2,2)"                # <= The modified Cox Special, values are in seconds
                                                        #    WAV(duration, delay, rise-time, fall-time, undershoot, recovery)
    output4d=${3}_${delay}sec                           # <= run#_sub0##_tshift_volreg_despike_mni_7mm_214tr_#sec_##learnable
    fullmask=fullmask_${input4d}                        # <= run#_sub0##_tshift_volreg_despike_mni_7mm_214tr_fullmask
    input1d=( cue_stim.1D    tone_block.1D    sent_block.1D \
              "${runsub}_${mc}_demean.1D[0]" "${runsub}_${mc}_demean.1D[1]" \
              "${runsub}_${mc}_demean.1D[2]" "${runsub}_${mc}_demean.1D[3]" \
              "${runsub}_${mc}_demean.1D[4]" "${runsub}_${mc}_demean.1D[5]" \
              "${runsub}_${mc}_deriv.1D[0]"  "${runsub}_${mc}_deriv.1D[1]" \
              "${runsub}_${mc}_deriv.1D[2]"  "${runsub}_${mc}_deriv.1D[3]" \
              "${runsub}_${mc}_deriv.1D[4]"  "${runsub}_${mc}_deriv.1D[5]" )

    3dDeconvolve \
        -input ${FUNC}/${input4d}.nii.gz \
        -polort A \
        -mask ${MASK}/${fullmask}.nii.gz \
        -local_times \
        -num_stimts 14 \
            -censor ${STIM}/censor.${input1d[0]} \
        -stim_times 1 ${STIM}/stim.${input1d[1]} "${model}" \
            -stim_label 1 Tone \
        -stim_times 2 ${STIM}/stim.${input1d[2]} "${model}" \
            -stim_label 2 Sent \
        -stim_file 3 ${ID}/motion.${input1d[3]} \
            -stim_base 3 \
            -stim_label 3 roll_demean    \
        -stim_file 4 ${ID}/motion.${input1d[4]} \
            -stim_base 4 \
            -stim_label 4 pitch_demean  \
        -stim_file 5 ${ID}/motion.${input1d[5]} \
            -stim_base 5 \
            -stim_label 5 yaw_demean     \
        -stim_file 6 ${ID}/motion.${input1d[6]} \
            -stim_base 6 \
            -stim_label 6 dS_demean      \
        -stim_file 7 ${ID}/motion.${input1d[7]} \
            -stim_base 7 \
            -stim_label 7 dL_demean      \
        -stim_file 8 ${ID}/motion.${input1d[8]} \
            -stim_base 8 \
            -stim_label 8 dP_demean      \
        -stim_file 9 ${ID}/motion.${input1d[9]} \
            -stim_base 9 \
            -stim_label 9 roll_deriv     \
        -stim_file 10 ${ID}/motion.${input1d[10]} \
            -stim_base 10 \
            -stim_label 10 pitch_deriv \
        -stim_file 11 ${ID}/motion.${input1d[11]} \
            -stim_base 11 \
            -stim_label 11 yaw_deriv   \
        -stim_file 12 ${ID}/motion.${input1d[12]} \
            -stim_base 12 \
            -stim_label 12 dS_deriv    \
        -stim_file 13 ${ID}/motion.${input1d[13]} \
            -stim_base 13 \
            -stim_label 13 dL_deriv    \
        -stim_file 14 ${ID}/motion.${input1d[14]} \
            -stim_base 14 \
            -stim_label 14 dP_deriv    \
        -xout \
            -x1D ${ID}/${output4d}.xmat.1D \
            -xjpeg ${IMAGES}/${output4d}.xmat.jpg \
        -jobs 12 \
        -fout -tout \
        -errts ${ERRTS}/${output4d}.errts.nii.gz \
        -fitts ${FITTS}/${output4d}.fitts.nii.gz \
        -bucket ${STATS}/${output4d}.stats.nii.gz

    # echo -e "\n============================ Variable Names for regress_convolve_covar  ============================\n"
    # echo "${delay}"
    # echo "Input: ${input4d}"
    # echo "Output: ${output4d}"
    # echo "${FUNC}/${input4d}.nii.gz"
    # echo "${MASK}/${fullmask}.nii.gz"
    # echo "${STIM}/censor.${input1d[0]}"
    # echo "${STIM}/stim.${input1d[1]} "${model}""
    # echo "${STIM}/stim.${input1d[2]} "${model}""
    # echo "${ID}/motion.${input1D[3]}"
    # echo "${ID}/motion.${input1D[14]}"
    # echo "${ID}/${output4d}.xmat.1D"
    # echo "${IMAGES}/${output4d}.xmat.jpg"
    # echo "${ERRTS}/${output4d}.errts.nii.gz"
    # echo "${FITTS}/${output4d}.fitts.nii.gz"
    # echo "${STATS}/${output4d}.stats.nii.gz"

} # End of regress_convolve_nocovar



function regress_plot_nocovar() {
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

    echo -e "\nregress_plot_nocovar has been called\n"

    delay=${1}
    input4d=${2}_${delay}sec

    1dcat \
        ${ID}/${input4d}.xmat.1D'[4]' \
        > ${FITTS}/ideal.${input4d}.tone_block.1D

    1dcat \
        ${ID}/${input4d}.xmat.1D'[5]' \
        > ${FITTS}/ideal.${input4d}.sent_block.1D

    1dplot \
        -sepscl \
        -censor_RGB red \
        -censor ${STIM}/censor.cue_stim.1D \
        -ynames baseline polort1 polort2 polort3 \
                tone_block sent_block \
        -jpeg ${IMAGES}/${input4d}.Regressors-All \
        ${ID}/${input4d}.xmat.1D'[0..$]'

    1dplot \
        -censor_RGB green \
        -censor ${STIM}/censor.cue_stim.1D \
        -ynames tone_block sent_block \
        -jpeg ${IMAGES}/${input4d}.Regressors-Stim \
        ${ID}/${input4d}.xmat.1D'[4,5]'

    # echo -e "\n============================ Variable Names for regress_plot_nocovar  ============================\n"
    # echo "${delay}"
    # echo "Input: ${input4d}"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${FITTS}/ideal.${input4d}.tone_block.1D"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${FITTS}/ideal.${input4d}.sent_block.1D"
    # echo "${IMAGES}/${input4d}.Regressors-All"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${STIM}/censor.cue_stim.1D"
    # echo "${IMAGES}/${input4d}.Regressors-Stim"
    # echo "${ID}/${input4d}.xmat.1D"

} # End of regress_plot_nocovar


function regress_plot_covar() {
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

    echo -e "\nregress_plot_covar has been called\n"

    delay=${1}
    input4d=${2}_${delay}sec

    1dcat \
        ${ID}/${input4d}.xmat.1D'[4]' \
        > ${FITTS}/ideal.${input4d}.tone_block.1D

    1dcat \
        ${ID}/${input4d}.xmat.1D'[5]' \
        > ${FITTS}/ideal.${input4d}.sent_block.1D

    1dplot \
        -sepscl \
        -censor_RGB red \
        -censor ${STIM}/censor.cue_stim.1D \
        -ynames baseline polort1 polort2 \
                polort3 tone_block sent_block \
                roll_demean pitch_demean yaw_demean \
                dS_demean dL_demean dP_demean \
                roll_deriv pitch_deriv yaw_deriv \
                dS_deriv dL_deriv dP_deriv \
        -jpeg ${IMAGES}/${input4d}.Regressors-All \
        ${ID}/${input4d}.xmat.1D'[0..$]'

    1dplot \
        -censor_RGB green \
        -censor ${STIM}/censor.cue_stim.1D \
        -ynames tone_block sent_block \
        -jpeg ${IMAGES}/${input4d}.Regressors-Stim \
        ${ID}/${input4d}.xmat.1D'[4,5]'

    # echo -e "\n============================ Variable Names for regress_plot_covar  ============================\n"
    # echo "${delay}"
    # echo "Input: ${input4d}"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${FITTS}/ideal.${input4d}.tone_block.1D"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${FITTS}/ideal.${input4d}.sent_block.1D"
    # echo "${IMAGES}/${input4d}.Regressors-All"
    # echo "${ID}/${input4d}.xmat.1D"
    # echo "${STIM}/censor.cue_stim.1D"
    # echo "${IMAGES}/${input4d}.Regressors-Stim"
    # echo "${ID}/${input4d}.xmat.1D"

} # End of regress_plot_covar


function regress_alphcor() {
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

    echo -e "\nregress_alphcor has been called\n"

    prev=$(pwd); cd ${STATS}
    for delay in 0; do
        fullmask=fullmask_${1}
        input4d=${2}_${delay}sec

        fwhmx=$(3dFWHMx \
                -dset ${ERRTS}/${input4d}.errts.nii.gz \
                -mask ${MASK}/${fullmask}.nii.gz \
                -combine -detrend)

        echo "-fwhm is ${fwhmx}"

        3dClustSim \
            -fwhm "${fwhmx}" \
            -both \
            -NN 123 \
            -pthr 0.05 0.01 \
            -nxyz 91 109 91 \
            -dxyz 2.0 2.0 2.0 \
            -mask ${MASK}/${fullmask}.nii.gz \
            -prefix ${STATS}/ClustSim.${condition}

        sudo chmod -R a+rwx ${STATS}/ClustSim.*

        3drefit \
            -atrstring AFNI_CLUSTSIM_MASK file:ClustSim.${condition}.mask \
            -atrstring AFNI_CLUSTSIM_NN1  file:ClustSim.${condition}.NN1_1sided.niml \
            -atrstring AFNI_CLUSTSIM_NN2  file:ClustSim.${condition}.NN2_1sided.niml \
            -atrstring AFNI_CLUSTSIM_NN3  file:ClustSim.${condition}.NN3_1sided.niml \
            ${input4d}.stats.nii.gz

        rm ClustSim.${condition}.*

        # echo -e "\n============================ Variable Names for regress_alphcor  ============================\n"
        # echo "${fullmask}"
        # echo "Input: ${input4d}"
        # echo "${ERRTS}/${input4d}.errts.nii.gz"
        # echo "${MASK}/${fullmask}.nii.gz"
        # echo "${STATS}/ClustSim.${condition}"

    done
    cd ${prev}

} # End of regress_alphcor



function group_bucket_stats() {
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

    echo -e "\ngroup_bucket_stats has been called\n"

    delay=$1
    input3d=${2}_${delay}sec.stats
    output3d=${2}_${delay}sec

    3dBucket \
        -prefix ${TTEST}/${output3d}_ToneStats.nii.gz \
        -fbuc ${STATS}/${input3d}.nii.gz'[1-3]'

    3dBucket \
        -prefix ${TTEST}/${output3d}_SentStats.nii.gz \
        -fbuc ${STATS}/${input3d}.nii.gz'[4-6]'

    # echo -e "\n============================ Variable Names for group_bucket_stats  ============================\n"
    # echo "${delay}"
    # echo "Input: ${input3d}"
    # echo "Output: ${output3d}"
    # echo "${TTEST}/${output3d}_ToneStats.nii.gz"
    # echo "${STATS}/${input3d}.nii.gz"
    # echo "${TTEST}/${output3d}_SentStats.nii.gz"
    # echo "${STATS}/${input3d}.nii.gz"

} # End of group_bucket_stats



function help_message() {
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

    echo "-----------------------------------------------------------------------"
    echo "+                 +++ No arguments provided! +++                      +"
    echo "+                                                                     +"
    echo "+             This program requires at least 3 arguments.             +"
    echo "+                                                                     +"
    echo "+       NOTE: [words] in square brackets represent possible input.    +"
    echo "+             See below for available options.                        +"
    echo "+                                                                     +"
    echo "-----------------------------------------------------------------------"
    echo "   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "   +                Experimental condition                       +"
    echo "   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "   +                                                             +"
    echo "   +           [NoMC] or [Slo] or [Slo2] or [Volreg]             +"
    echo "   +                   [Covar] or [NoCovar]                      +"
    echo "   +                  [Smooth] or [NoSmooth]                     +"
    echo "   +                                                             +"
    echo "   +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "-----------------------------------------------------------------------"
    echo "+                Example command-line execution:                      +"
    echo "+                                                                     +"
    echo "+                 bash rus.glm.nomc.sh nocovar                        +"
    echo "+                                                                     +"
    echo "+                  +++ Please try again +++                           +"
    echo "-----------------------------------------------------------------------"

    exit 1

} # End of help_message


function test_main() {
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

    input4d=${subImage4D}

    input1D=( cue_stim.1D \
              listen_block.1D \
              control_block.1D \
              response_block.1D )

    echo "============================ Begin Testing============================"
    echo "mc = ${mc}"
    echo "condition = ${condition}"
    echo "smooth = ${smooth}"
    echo "stim = ${stim}"
    echo "Subject = ${sub} "
    echo "runsub = ${runsub}"
    echo "subImage4D = ${subImage4D}"
    echo "outImage4D = ${outImage4D}"
    echo "RUN = ${RUN} "
    echo -e "\n============================ File Names ============================\n"
    echo "censor.${input1D[0]}"
    echo "stim.${input1D[1]} "
    echo "stim.${input1D[2]}"
    echo "stim.${input1D[3]} "
    echo -e "\n============================ Path Names  ============================\n"
    echo "Func dir = ${FUNC}"
    echo "GLM dir = ${GLM}"
    echo "STIM dir = ${STIM}"
    echo "ID dir = ${ID}"

    for delay in 0; do

        output4d=${outImage4D}_${delay}sec
        model="WAV(18.2,${delay},4,6,0.2,2)"

        echo -e "\n============================ Variable Names  ============================\n"
        echo "delay = ${delay}"
        echo "model = ${model}"
        echo "input4d = ${input4d}"
        echo "output4d = ${output4d}"

    done

    echo -e "\n================================ End Testing ================================"
    echo -e "\n********************* Hooray For Test Driven Development **********************\n"

    exit 1

} # End of test



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

    echo -e "\nMain has been called\n"

    mc=$1
    condition=$2
    smooth=$3
    stim=$4

    case ${stim} in
        "learn" )
            sublist=( sub100 sub105 sub106 sub109
                      sub116 sub117 sub145 sub158
                      sub159 sub160 sub161 sub166
                      sub169 sub173 sub181 sub215
                      sub243 sub241 )
            # sublist=( sub100 )
            ;;

        "unlearn" )
            sublist=( sub111 sub120 sub121 sub124
                      sub130 sub132 sub133 sub144
                      sub163 sub164 sub168 sub171
                      sub172 sub176 sub185 sub200 )
            # sublist=( sub111 )
            ;;

        "test" )
            sublist=( sub100 sub111 )
            ;;

        * )
            help_message
            ;;
    esac

    for sub in ${sublist[*]}; do
    	for r in {1..4}; do

    		BASE=/Exps/Analysis/Slomoco/GLM/${mc}_${condition}_${smooth}_${stim}
            STIM=/Exps/Analysis/Slomoco/GLM/STIM

    		runsub=run${r}_${sub}
            outImage4D=${runsub}_${mc}_${condition}_${smooth}_${stim}

            case ${smooth} in
                "smooth" )
                    DATA=/Exps/Data/Russian
                    subImage4D=${runsub}_176tr_${mc}_despike_mni_6mm
                    ;;

                "nosmooth" )
                    DATA=/Exps/Data/Russian_NoSmooth
                    subImage4D=${runsub}_176tr_${mc}_despike_mni
                    ;;

                * )
                    help_message
                    ;;
            esac

    		RUN=Run${r}
    		FUNC=${DATA}/${sub}/Func/${RUN}
    		FUNC2=${DATA}/${sub}/Func/${RUN}/DataQuality
    		ACCESS=${DATA}/${sub}/Access

            GLM=${BASE}/${sub}/${RUN}
            ID=${GLM}/1D
            MASK=${GLM}/Mask
            IMAGES=${GLM}/Images
            STATS=${GLM}/Stats
            FITTS=${GLM}/Fitts
            ERRTS=${GLM}/Errts

            TTEST=${BASE}/TTEST/${sub}/${RUN}

            setup_dir
            sudo chmod -R a+rwx ${BASE}
            sudo chmod -R a+rwx ${TTEST}

            if [[ ${mc} = "test" ]]; then
                test_main
            fi

            case ${mc} in
                "slo" )
                    regress_motion ${runsub}_176tr.mocoafni ${runsub}_${mc} 2>&1 | tee -a ${GLM}/log_motion.txt
                    ;;

                "slo2" )
                    regress_motion ${runsub}_176tr.mocoafni2 ${runsub}_${mc} 2>&1 | tee -a ${GLM}/log_motion.txt
                    ;;

                "volreg" )
                    regress_motion ${runsub}_176tr_dfile ${runsub}_${mc} 2>&1 | tee -a ${GLM}/log_motion.txt
                    ;;
            esac

            regress_masking ${subImage4D} ${outImage4D} 2>&1 | tee -a ${GLM}/log_mask.txt

            for delay in 0; do
                case ${condition} in
                    "covar" )
                        regress_convolve_covar ${delay} ${subImage4D} ${outImage4D} 2>&1 | tee -a ${GLM}/log_convolve.txt
                        regress_plot_covar ${delay} ${outImage4D} 2>&1 | tee -a ${GLM}/log_plot.txt
                        ;;

                    "nocovar" )
                        regress_convolve_nocovar ${delay} ${subImage4D} ${outImage4D} 2>&1 | tee -a ${GLM}/log_convolve.txt
                        regress_plot_nocovar ${delay} ${outImage4D} 2>&1 | tee -a ${GLM}/log_plot.txt
                        ;;
                esac
            	group_bucket_stats ${delay} ${outImage4D} 2>&1 | tee -a ${GLM}/log_bucket.txt
            done
            regress_alphcor ${subImage4D} ${outImage4D} 2>&1 | tee -a ${GLM}/log_alphacor.txt
    	done
	done

} # End of main


#================================================================================
#                              START OF MAIN
#================================================================================

mc=$1
condition=$2
smooth=$3
stim=$4

touch /Exps/Analysis/Slomoco/GLM/${mc}_${condition}_${smooth}_${stim}.txt

main ${mc} ${condition} ${smooth} ${stim} 2>&1 | sudo tee -a /Exps/Analysis/Slomoco/GLM/${mc}_${condition}_${smooth}_${stim}.txt

#================================================================================
#                              END OF MAIN
#================================================================================