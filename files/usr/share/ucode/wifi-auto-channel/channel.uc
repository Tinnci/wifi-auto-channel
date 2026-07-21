'use strict';

const CHANNEL_GROUPS_160 = [
	{ freqs: [5180, 5200, 5220, 5240, 5260, 5280, 5300, 5320], center: 5250 },
	{ freqs: [5500, 5520, 5540, 5560, 5580, 5600, 5620, 5640], center: 5570 },
];

const CHANNEL_GROUPS_80 = [
	{ freqs: [5180, 5200, 5220, 5240], center: 5210 },
	{ freqs: [5260, 5280, 5300, 5320], center: 5290 },
	{ freqs: [5500, 5520, 5540, 5560], center: 5530 },
	{ freqs: [5580, 5600, 5620, 5640], center: 5610 },
	{ freqs: [5660, 5680, 5700, 5720], center: 5690 },
	{ freqs: [5745, 5765, 5785, 5805], center: 5775 },
];

const CHANNEL_GROUPS_40 = [
	{ freqs: [5180, 5200], center: 5190 },
	{ freqs: [5220, 5240], center: 5230 },
	{ freqs: [5260, 5280], center: 5270 },
	{ freqs: [5300, 5320], center: 5310 },
	{ freqs: [5500, 5520], center: 5510 },
	{ freqs: [5540, 5560], center: 5550 },
	{ freqs: [5580, 5600], center: 5590 },
	{ freqs: [5620, 5640], center: 5630 },
	{ freqs: [5660, 5680], center: 5670 },
	{ freqs: [5700, 5720], center: 5710 },
	{ freqs: [5745, 5765], center: 5755 },
	{ freqs: [5785, 5805], center: 5795 },
	{ freqs: [2412, 2432], center: 2422 },
	{ freqs: [2437, 2457], center: 2447 },
	{ freqs: [2462, 2472], center: 2467 },
];

export function freq_to_channel(freq) {
	if (freq >= 2412 && freq <= 2484)
		return (freq - 2407) / 5;
	if (freq >= 5180 && freq <= 5885)
		return (freq - 5000) / 5;
	if (freq >= 5955)
		return (freq - 5950) / 5;
	return 0;
};

export function channel_to_freq(ch) {
	if (ch >= 1 && ch <= 14)
		return 2407 + ch * 5;
	if (ch >= 36 && ch <= 177)
		return 5000 + ch * 5;
	return 0;
};

export function get_oper_chwidth(bw) {
	if (bw >= 160) return 2;
	if (bw >= 80) return 1;
	return 0;
};

export function htmode_to_bw(htmode) {
	if (match(htmode, /160/)) return 160;
	if (match(htmode, /80/)) return 80;
	if (match(htmode, /40/)) return 40;
	return 20;
};

export function get_groups_for_bw(bw) {
	if (bw >= 160) return CHANNEL_GROUPS_160;
	if (bw >= 80) return CHANNEL_GROUPS_80;
	if (bw >= 40) return CHANNEL_GROUPS_40;
	return null;
};

export function find_channel_group(freq, bw) {
	let groups = get_groups_for_bw(bw);
	if (!groups) return null;

	for (let g in groups) {
		if (index(g.freqs, freq) >= 0)
			return g;
	}
	return null;
};

export function get_center_freq1(freq, bw) {
	let g = find_channel_group(freq, bw);
	if (g) return g.center;
	return freq;
};

export function build_phy_info(available_freqs) {
	let info = {
		freqs: {},
	};

	for (let f in available_freqs) {
		info.freqs[f.freq] = {
			freq: f.freq,
			dfs: f.radar ?? false,
			disabled: f.disabled ?? false,
			max_power: f.max_power ?? 0,
			no_ir: f.no_ir ?? false,
		};
	}

	return info;
};

export function is_dfs(freq, phy_info) {
	return phy_info?.freqs?.[freq]?.dfs ?? false;
};

export function is_available(freq, phy_info) {
	let f = phy_info?.freqs?.[freq];
	return f && !f.disabled;
};

export function group_available(group, phy_info) {
	for (let freq in group.freqs) {
		if (!is_available(freq, phy_info))
			return false;
	}
	return true;
};

export function group_has_dfs(group, phy_info) {
	for (let freq in group.freqs) {
		if (is_dfs(freq, phy_info))
			return true;
	}
	return false;
};

export function compute_utilization(prev, curr) {
	let dt = curr.time - prev.time;
	if (dt <= 0) return 0;
	let db = curr.time_busy - prev.time_busy;
	return (db * 100) / dt;
};

export function score_survey_channel(freq, survey_entry, current_freq, phy_info) {
	let busy_pct = 0;
	if (survey_entry && survey_entry.time > 0)
		busy_pct = (survey_entry.time_busy * 100) / survey_entry.time;

	let noise = survey_entry?.noise ?? -100;
	let score = 100.0 - busy_pct;

	if (noise > -90)
		score -= (noise + 90) * 2;

	if (is_dfs(freq, phy_info))
		score -= 10;

	if (freq == current_freq)
		score += 5;

	if (score < 0) score = 0;
	return score;
};

export function score_channel_group(group, survey, current_freq, phy_info, config) {
	if (!group_available(group, phy_info))
		return -1;

	if (group_has_dfs(group, phy_info) && !config.dfs_allowed)
		return -1;

	let total_score = 0;
	for (let freq in group.freqs)
		total_score += score_survey_channel(freq, survey[freq], current_freq, phy_info);

	return total_score / length(group.freqs);
};

export function find_best_channel(current_freq, bw, survey, phy_info, config, avoided) {
	let groups = get_groups_for_bw(bw);

	if (!groups) {
		let best = null;
		for (let freq_str in keys(survey)) {
			let freq = +freq_str;
			if (!is_available(freq, phy_info)) continue;
			if (!config.dfs_allowed && is_dfs(freq, phy_info)) continue;
			let s = score_survey_channel(freq, survey[freq], current_freq, phy_info);
			if (index(avoided, freq) >= 0)
				s -= 20;
			if (!best || s > best.score)
				best = { freq, score: s };
		}
		return best;
	}

	let best_group = null;
	let best_score = -1;

	for (let g in groups) {
		let s = score_channel_group(g, survey, current_freq, phy_info, config);
		if (s < 0) continue;

		if (index(avoided, g.freqs[0]) >= 0)
			s -= 20;

		if (s > best_score) {
			best_score = s;
			best_group = g;
		}
	}

	if (!best_group) return null;

	let best_primary = best_group.freqs[0];
	let best_primary_score = -1;
	for (let freq in best_group.freqs) {
		let s = score_survey_channel(freq, survey[freq], current_freq, phy_info);
		if (s > best_primary_score) {
			best_primary_score = s;
			best_primary = freq;
		}
	}

	return {
		freq: best_primary,
		center_freq1: best_group.center,
		score: best_score,
		group: best_group,
	}
};
