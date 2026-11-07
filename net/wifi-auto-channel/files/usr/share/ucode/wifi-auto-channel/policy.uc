// AX5 vacancy and measurement guards for wifi-auto-channel.
'use strict';

export function vacant_ready(state, clients, now, required) {
	if (clients == null || clients != 0) {
		state.vacant_since = null;
		state.last_observed = now;
		return false;
	}
	if (state.last_observed == null || now < state.last_observed ||
	    now - state.last_observed > 60)
		state.vacant_since = null;
	state.last_observed = now;
	if (state.vacant_since == null)
		state.vacant_since = now;
	return now - state.vacant_since >= required;
};

export function valid_sample(sample) {
	return sample && sample.time > 0 && sample.time_busy != null &&
		sample.time_busy >= 0 && sample.time_busy <= sample.time;
};

export function usable_survey(survey, frequencies) {
	let result = {};
	let saturated = 0;
	for (let frequency in frequencies) {
		let sample = survey[frequency];
		if (!valid_sample(sample))
			return null;
		result[frequency] = sample;
		if (sample.time_busy * 100 / sample.time >= 98)
			saturated++;
	}
	if (!length(frequencies) || saturated == length(frequencies))
		return null;
	return result;
};
