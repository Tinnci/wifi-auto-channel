#!/usr/bin/ucode

'use strict';

import {
	freq_to_channel, channel_to_freq, htmode_to_bw, get_oper_chwidth,
	find_channel_group, get_center_freq1, get_groups_for_bw,
	build_phy_info, is_dfs, is_available, group_available, group_has_dfs,
	channel_is_dfs,
	compute_utilization, score_survey_channel, score_channel_group,
	find_best_channel, find_best_non_dfs_channel
} from 'wifi-auto-channel.channel';

const mod = {
	freq_to_channel, channel_to_freq, htmode_to_bw, get_oper_chwidth,
	find_channel_group, get_center_freq1, get_groups_for_bw,
	build_phy_info, is_dfs, is_available, group_available, group_has_dfs,
	channel_is_dfs,
	compute_utilization, score_survey_channel, score_channel_group,
	find_best_channel, find_best_non_dfs_channel,
};

let passed = 0;
let failed = 0;
let errors = [];

function assert_eq(name, got, expected) {
	if (got == expected) {
		passed++;
	} else {
		failed++;
		push(errors, sprintf("FAIL: %s: got %J, expected %J", name, got, expected));
	}
}

function assert_true(name, val) {
	assert_eq(name, !!val, true);
}

function assert_false(name, val) {
	assert_eq(name, !!val, false);
}

function assert_near(name, got, expected, tolerance) {
	tolerance ??= 0.1;
	let diff = got - expected;
	if (diff < 0) diff = -diff;
	if (diff <= tolerance) {
		passed++;
	} else {
		failed++;
		push(errors, sprintf("FAIL: %s: got %.2f, expected %.2f (tolerance %.2f)", name, got, expected, tolerance));
	}
}

function make_phy_info(freq_list) {
	let freqs = [];
	for (let f in freq_list) {
		if (type(f) == "object")
			push(freqs, f);
		else
			push(freqs, { freq: f });
	}
	return mod.build_phy_info(freqs);
}

function make_survey_entry(freq, busy_pct, noise) {
	return {
		freq: freq,
		time: 1000,
		time_busy: busy_pct * 10,
		noise: noise ?? -100,
	};
}

printf("=== freq_to_channel ===\n");
assert_eq("5GHz ch36", mod.freq_to_channel(5180), 36);
assert_eq("5GHz ch60", mod.freq_to_channel(5300), 60);
assert_eq("5GHz ch100", mod.freq_to_channel(5500), 100);
assert_eq("5GHz ch149", mod.freq_to_channel(5745), 149);
assert_eq("2.4GHz ch1", mod.freq_to_channel(2412), 1);
assert_eq("2.4GHz ch6", mod.freq_to_channel(2437), 6);
assert_eq("2.4GHz ch13", mod.freq_to_channel(2472), 13);
assert_eq("invalid", mod.freq_to_channel(1000), 0);

printf("=== channel_to_freq ===\n");
assert_eq("ch36", mod.channel_to_freq(36), 5180);
assert_eq("ch60", mod.channel_to_freq(60), 5300);
assert_eq("ch100", mod.channel_to_freq(100), 5500);
assert_eq("ch1", mod.channel_to_freq(1), 2412);
assert_eq("ch6", mod.channel_to_freq(6), 2437);
assert_eq("roundtrip ch149", mod.channel_to_freq(mod.freq_to_channel(5745)), 5745);

printf("=== htmode_to_bw ===\n");
assert_eq("VHT160", mod.htmode_to_bw("VHT160"), 160);
assert_eq("HE160", mod.htmode_to_bw("HE160"), 160);
assert_eq("VHT80", mod.htmode_to_bw("VHT80"), 80);
assert_eq("HE80", mod.htmode_to_bw("HE80"), 80);
assert_eq("HT40", mod.htmode_to_bw("HT40"), 40);
assert_eq("VHT40", mod.htmode_to_bw("VHT40"), 40);
assert_eq("HT20", mod.htmode_to_bw("HT20"), 20);
assert_eq("EHT320", mod.htmode_to_bw("EHT320"), 20);
assert_eq("NOHT", mod.htmode_to_bw("NOHT"), 20);

printf("=== get_oper_chwidth ===\n");
assert_eq("160", mod.get_oper_chwidth(160), 2);
assert_eq("80", mod.get_oper_chwidth(80), 1);
assert_eq("40", mod.get_oper_chwidth(40), 0);
assert_eq("20", mod.get_oper_chwidth(20), 0);

printf("=== find_channel_group ===\n");
let g160 = mod.find_channel_group(5180, 160);
assert_true("ch36 in 160 group", g160);
assert_eq("ch36 160 center", g160?.center, 5250);
assert_eq("ch36 160 group size", length(g160?.freqs), 8);

let g160_2 = mod.find_channel_group(5300, 160);
assert_true("ch60 in 160 group", g160_2);
assert_eq("ch60 same group", g160_2?.center, 5250);

let g160_100 = mod.find_channel_group(5500, 160);
assert_true("ch100 in 160 group", g160_100);
assert_eq("ch100 160 center", g160_100?.center, 5570);

let g80 = mod.find_channel_group(5180, 80);
assert_true("ch36 in 80 group", g80);
assert_eq("ch36 80 center", g80?.center, 5210);
assert_eq("ch36 80 group size", length(g80?.freqs), 4);

let g80_52 = mod.find_channel_group(5260, 80);
assert_eq("ch52 80 center", g80_52?.center, 5290);

assert_eq("ch36 no 20 group", mod.find_channel_group(5180, 20), null);

printf("=== get_center_freq1 ===\n");
assert_eq("ch36 VHT160 center", mod.get_center_freq1(5180, 160), 5250);
assert_eq("ch100 VHT160 center", mod.get_center_freq1(5500, 160), 5570);
assert_eq("ch36 VHT80 center", mod.get_center_freq1(5180, 80), 5210);
assert_eq("ch52 VHT80 center", mod.get_center_freq1(5260, 80), 5290);
assert_eq("ch36 HT40 center", mod.get_center_freq1(5180, 40), 5190);
assert_eq("ch36 HT20 center", mod.get_center_freq1(5180, 20), 5180);

printf("=== build_phy_info + is_dfs + is_available ===\n");
let phy_de = make_phy_info([
	{ freq: 5180 }, { freq: 5200 }, { freq: 5220 }, { freq: 5240 },
	{ freq: 5260, radar: true }, { freq: 5280, radar: true },
	{ freq: 5300, radar: true }, { freq: 5320, radar: true },
	{ freq: 5500, radar: true }, { freq: 5520, radar: true },
	{ freq: 5700, disabled: true },
]);

assert_false("ch36 not DFS (DE)", mod.is_dfs(5180, phy_de));
assert_true("ch52 is DFS (DE)", mod.is_dfs(5260, phy_de));
assert_true("ch100 is DFS (DE)", mod.is_dfs(5500, phy_de));
assert_true("ch36 available", mod.is_available(5180, phy_de));
assert_false("ch140 disabled", mod.is_available(5700, phy_de));
assert_false("ch165 not in phy", mod.is_available(5825, phy_de));

let phy_us = make_phy_info([
	{ freq: 5180 }, { freq: 5200 }, { freq: 5220 }, { freq: 5240 },
	{ freq: 5745 }, { freq: 5765 }, { freq: 5785 }, { freq: 5805 },
]);
assert_false("ch36 not DFS (US-like)", mod.is_dfs(5180, phy_us));
assert_false("ch149 not DFS (US-like)", mod.is_dfs(5745, phy_us));
assert_false("ch52 not in US phy", mod.is_dfs(5260, phy_us));

printf("=== group_available / group_has_dfs ===\n");
let g80_36 = mod.find_channel_group(5180, 80);
assert_true("36-48 available (DE)", mod.group_available(g80_36, phy_de));
assert_false("36-48 no DFS (DE)", mod.group_has_dfs(g80_36, phy_de));

let g80_dfs = mod.find_channel_group(5260, 80);
assert_true("52-64 available (DE)", mod.group_available(g80_dfs, phy_de));
assert_true("52-64 has DFS (DE)", mod.group_has_dfs(g80_dfs, phy_de));

let g80_149 = mod.find_channel_group(5745, 80);
assert_true("149-161 available (US)", mod.group_available(g80_149, phy_us));
assert_false("149-161 no DFS (US)", mod.group_has_dfs(g80_149, phy_us));

assert_false("52-64 not available (US)", mod.group_available(g80_dfs, phy_us));

printf("=== compute_utilization ===\n");
assert_near("50%% util",
	mod.compute_utilization(
		{ time: 1000, time_busy: 100 },
		{ time: 2000, time_busy: 600 }),
	50.0);

assert_near("0%% util",
	mod.compute_utilization(
		{ time: 1000, time_busy: 100 },
		{ time: 2000, time_busy: 100 }),
	0.0);

assert_near("100%% util",
	mod.compute_utilization(
		{ time: 0, time_busy: 0 },
		{ time: 1000, time_busy: 1000 }),
	100.0);

assert_eq("zero dt",
	mod.compute_utilization(
		{ time: 1000, time_busy: 0 },
		{ time: 1000, time_busy: 500 }),
	0);

printf("=== score_survey_channel ===\n");
let phy_simple = make_phy_info([
	{ freq: 5180 }, { freq: 5260, radar: true },
]);

let clean = make_survey_entry(5180, 0, -100);
let busy = make_survey_entry(5180, 70, -100);
let noisy = make_survey_entry(5180, 0, -80);
let dfs_clean = make_survey_entry(5260, 0, -100);

assert_near("clean non-DFS", mod.score_survey_channel(5180, clean, 5300, phy_simple), 100.0);
assert_near("clean non-DFS current", mod.score_survey_channel(5180, clean, 5180, phy_simple), 105.0);
assert_near("busy channel", mod.score_survey_channel(5180, busy, 5300, phy_simple), 30.0);
assert_near("noisy channel", mod.score_survey_channel(5180, noisy, 5300, phy_simple), 80.0);
assert_near("clean DFS", mod.score_survey_channel(5260, dfs_clean, 5300, phy_simple), 90.0);
assert_near("null survey", mod.score_survey_channel(5180, null, 5300, phy_simple), 100.0);

printf("=== score_channel_group ===\n");
let phy_full = make_phy_info([
	{ freq: 5180 }, { freq: 5200 }, { freq: 5220 }, { freq: 5240 },
	{ freq: 5260, radar: true }, { freq: 5280, radar: true },
	{ freq: 5300, radar: true }, { freq: 5320, radar: true },
]);
let survey_clean = {};
for (let f in [5180, 5200, 5220, 5240, 5260, 5280, 5300, 5320])
	survey_clean[f] = make_survey_entry(f, 0, -100);

let cfg_dfs_yes = { dfs_allowed: 1 };
let cfg_dfs_no = { dfs_allowed: 0 };

let grp_nodfs = mod.find_channel_group(5180, 80);
let grp_dfs = mod.find_channel_group(5260, 80);

let s1 = mod.score_channel_group(grp_nodfs, survey_clean, 5300, phy_full, cfg_dfs_yes);
assert_true("non-DFS group scores positive", s1 > 0);

let s2 = mod.score_channel_group(grp_dfs, survey_clean, 5300, phy_full, cfg_dfs_yes);
assert_true("DFS group scores positive when allowed", s2 > 0);
assert_true("DFS group scores lower than non-DFS", s2 < s1);

let s3 = mod.score_channel_group(grp_dfs, survey_clean, 5300, phy_full, cfg_dfs_no);
assert_eq("DFS group rejected when not allowed", s3, -1);

printf("=== find_best_channel ===\n");
let survey_congested = {};
for (let f in [5180, 5200, 5220, 5240])
	survey_congested[f] = make_survey_entry(f, 80, -95);
for (let f in [5260, 5280, 5300, 5320])
	survey_congested[f] = make_survey_entry(f, 5, -100);

let best80 = mod.find_best_channel(5180, 80, survey_congested, phy_full, cfg_dfs_yes, []);
assert_true("finds alternative", best80);
assert_eq("picks DFS group (cleaner)", best80?.center_freq1, 5290);

let best80_nodfs = mod.find_best_channel(5180, 80, survey_congested, phy_full, cfg_dfs_no, []);
assert_true("finds alternative without DFS", best80_nodfs);
assert_eq("stays on non-DFS", best80_nodfs?.center_freq1, 5210);

let survey_all_clean = {};
for (let f in [5180, 5200, 5220, 5240, 5260, 5280, 5300, 5320])
	survey_all_clean[f] = make_survey_entry(f, 2, -100);

let best_equal = mod.find_best_channel(5180, 80, survey_all_clean, phy_full, cfg_dfs_yes, []);
assert_true("finds channel when all equal", best_equal);
assert_eq("prefers non-DFS when equal", best_equal?.center_freq1, 5210);

let best_avoided = mod.find_best_channel(5260, 80, survey_all_clean, phy_full, cfg_dfs_yes, [5180]);
assert_true("finds channel with avoided", best_avoided);
assert_eq("avoids ch36 group", best_avoided?.center_freq1, 5290);

let phy_limited = make_phy_info([
	{ freq: 5180 }, { freq: 5200 }, { freq: 5220 }, { freq: 5240 },
]);
let best_limited = mod.find_best_channel(5180, 80, survey_all_clean, phy_limited, cfg_dfs_yes, []);
assert_true("works with limited phy", best_limited);
assert_eq("only option", best_limited?.center_freq1, 5210);

let best_ht20 = mod.find_best_channel(5180, 20, survey_congested, phy_full, cfg_dfs_yes, []);
assert_true("HT20 finds channel", best_ht20);
assert_true("HT20 picks clean freq", best_ht20.score > 50);

printf("=== channel_is_dfs ===\n");
assert_false("ch36 80MHz not DFS", mod.channel_is_dfs(5180, 80, phy_full));
assert_true("ch52 80MHz is DFS", mod.channel_is_dfs(5260, 80, phy_full));
assert_true("ch52 20MHz is DFS", mod.channel_is_dfs(5260, 20, phy_full));
assert_false("ch36 20MHz not DFS", mod.channel_is_dfs(5180, 20, phy_full));

printf("=== find_best_non_dfs_channel ===\n");
let best_nd = mod.find_best_non_dfs_channel(5260, 80, survey_all_clean, phy_full, cfg_dfs_yes, []);
assert_true("finds non-DFS alternative", best_nd);
assert_eq("picks 36-48 group", best_nd?.center_freq1, 5210);
assert_false("result group has no DFS", mod.group_has_dfs(best_nd?.group, phy_full));

let best_nd_congested = mod.find_best_non_dfs_channel(5260, 80, survey_congested, phy_full, cfg_dfs_yes, []);
assert_true("finds non-DFS even when congested", best_nd_congested);
assert_eq("still picks 36-48 (only non-DFS option)", best_nd_congested?.center_freq1, 5210);
assert_true("congested non-DFS scores lower",
	best_nd_congested.score < best_nd.score);

let phy_dfs_only = make_phy_info([
	{ freq: 5260, radar: true }, { freq: 5280, radar: true },
	{ freq: 5300, radar: true }, { freq: 5320, radar: true },
]);
let best_nd_none = mod.find_best_non_dfs_channel(5260, 80, survey_all_clean, phy_dfs_only, cfg_dfs_yes, []);
assert_eq("no non-DFS available returns null", best_nd_none, null);

let best_nd_avoided = mod.find_best_non_dfs_channel(5260, 80, survey_all_clean, phy_full, cfg_dfs_yes, [5180]);
assert_true("avoided still returns group", best_nd_avoided);
assert_true("avoided penalty applied", best_nd_avoided.score < best_nd.score);

let best_nd_20 = mod.find_best_non_dfs_channel(5260, 20, survey_all_clean, phy_full, cfg_dfs_yes, []);
assert_true("20MHz finds non-DFS freq", best_nd_20);
assert_false("20MHz result not DFS", mod.is_dfs(best_nd_20?.freq, phy_full));

printf("\n=== Results ===\n");
printf("Passed: %d\n", passed);
printf("Failed: %d\n", failed);

if (failed > 0) {
	printf("\nFailures:\n");
	for (let e in errors)
		printf("  %s\n", e);
	exit(1);
}

printf("All tests passed.\n");
