#!/usr/bin/env bash

# Decide whether frequency data approximates a normal distribution via 68-95-99.7 bounds.
is_normally_distributed() {
	local freq_file="$1"
	local total_entries=0
	local numeric_values=true
	local _frequency value _remainder
	while read -r _frequency value _remainder; do
		total_entries=$((total_entries + 1))
		if [[ ! "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]; then
			numeric_values=false
		fi
	done < "$freq_file"

	# Need at least 10 entries to test for normal distribution reliably
	if ((total_entries < 10)); then
		return 1  # Not enough data, assume non-normal
	fi

	# analyze_data stores rows by descending frequency. Restore numeric or lexical
	# category order before measuring the distribution's shape.
	local sort_key=('-k2,2')
	if "$numeric_values"; then
		sort_key=('-k2,2n')
	fi

	local verdict
	verdict=$(LC_ALL=C sort "${sort_key[@]}" "$freq_file" | awk '
	{
		freq = $1
		value = NR - 1  # Convert to 0-based index for position
		for (i = 1; i <= freq; i++) {
			samples[++sample_count] = value
			sum += value
			if (sample_count == 1 || value < min) min = value
			if (sample_count == 1 || value > max) max = value
		}
	}
	END {
		if (sample_count < 10) {
			print "INSUFFICIENT_DATA"
			exit
		}

		# Calculate mean
		mean = sum / sample_count

		# Calculate standard deviation
		variance_sum = 0
		for (i = 1; i <= sample_count; i++) {
			variance_sum += (samples[i] - mean) * (samples[i] - mean)
		}
		stddev = sqrt(variance_sum / (sample_count - 1))

		if (stddev <= 0) {
			print "NO_VARIANCE"
			exit
		}

		# Count samples within standard deviations (68-95-99.7 rule), and
		# independently reject one-sided distributions via skewness.
		within_1sd = 0
		within_2sd = 0
		within_3sd = 0
		third_moment_sum = 0

		for (i = 1; i <= sample_count; i++) {
			deviation = samples[i] - mean
			z_score = deviation / stddev
			abs_z = (z_score < 0) ? -z_score : z_score
			third_moment_sum += deviation * deviation * deviation

			if (abs_z <= 1) within_1sd++
			if (abs_z <= 2) within_2sd++
			if (abs_z <= 3) within_3sd++
		}

		pct_1sd = within_1sd * 100 / sample_count
		pct_2sd = within_2sd * 100 / sample_count
		pct_3sd = within_3sd * 100 / sample_count
		skewness = (third_moment_sum / sample_count) / (stddev * stddev * stddev)
		abs_skewness = (skewness < 0) ? -skewness : skewness

		if (pct_1sd >= 55 && pct_1sd <= 80 &&
		    pct_2sd >= 85 && pct_2sd <= 99 &&
		    pct_3sd >= 95 && abs_skewness <= 0.5) {
			print "NORMAL"
		} else {
			print "NOT_NORMAL"
		}
	}')

	[[ "$verdict" == "NORMAL" ]]
}
