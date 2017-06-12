#!/bin/bash

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

				echo -e "\nCalling /usr/local/Utilities/Russian/rus.glm.slomoco.sh ${mc} ${condition} ${smooth} ${stim}\n"
				sudo /usr/local/Utilities/Russian/rus.glm.slomoco.sh ${mc} ${condition} ${smooth} ${stim}

			done

		done

	done

done