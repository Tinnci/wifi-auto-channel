# wifi-auto-channel — AX5 vacancy-aware fork

This fork adapts [dbankmann/wifi-auto-channel](https://github.com/dbankmann/wifi-auto-channel) at commit `ea358afc34284cacb58bb400435b7c06e5b278dd` for the Redmi AX5 JDCloud experimental router.

## AX5 profile

- Only 2.4 GHz 20 MHz AP radios are eligible. Radios with a station uplink are excluded.
- Default enabled radio is `radio1`. `radio0` is disabled in this controller.
- Poll every 30 seconds. Require five minutes of observed zero clients across all AP interfaces before evaluating congestion. Missing client state resets the wait.
- Check congestion every five minutes after vacancy. Require three high-utilization samples, a 30-point score improvement and a one-hour cooldown.
- Candidate channels are 1, 6 and 11. Current regulatory permissions still apply.
- Wait for a bounded passive scan to complete, then check client presence again before switching.
- Defer changes on missing/invalid measurements or uniformly saturated candidate surveys.
- Validate CSA completion. On failed verification, request rollback and enter cooldown.

The service runs under procd. Configuration is `/etc/config/wifi-auto-channel`, and diagnostics appear in `logread -e wifi-auto-channel`.

Tested on the live AX5 with ath11k/NSS using 115 upstream channel tests and 26 additional vacancy/survey tests. The initial five-minute vacancy transition was observed. Long-term optimization performance and client continuity through CSA remain unmeasured. Approximately 99% busy survey readings on this AX5 are still under investigation. The controller defers changing channels when all candidates report saturation.

The OpenWrt package build runs both ucode test suites using the host ucode dependency. Packaging tests can also be run with `python3 -m unittest discover -s net/wifi-auto-channel/tests -v`.

## Upstream project description

OpenWrt picks a WiFi channel once at boot and never changes it. If neighbors start congesting your channel weeks later, you're stuck until you reboot. Enterprise APs from Ubiquiti or Cisco have proprietary auto-channel features, but there's nothing in the open-source WiFi stack -- no `acs_recalc` in hostapd, no periodic re-evaluation, nothing. This package fills that gap.

## What it does

Monitors channel utilization via nl80211 survey data (actual neighbor interference, not your own traffic) and switches to a cleaner channel using CSA when congestion is sustained. Clients follow the CSA seamlessly -- no disconnects.

- Queries phy capabilities at startup -- DFS status, available channels, supported widths are all detected from the hardware, not hardcoded
- Works with any mac80211-based driver (ath10k, mt76, ath11k, ...)
- Supports VHT20/40/80/160 and HE20/40/80/160
- Flap prevention via cooldown timers and avoided-channel tracking
- Stores hourly utilization history in `/tmp` (7 days)

## Install

Add to your OpenWrt `feeds.conf`:

```
src-git wifi_auto_channel https://github.com/Tinnci/wifi-auto-channel.git
```

```bash
./scripts/feeds update wifi_auto_channel
./scripts/feeds install wifi-auto-channel
```

Then enable `wifi-auto-channel` in `make menuconfig` under Network -> Wireless and build.

## Configuration

```
config global 'global'
	option enabled '1'
	option log_level '1'

config radio 'radio0'
	option enabled '0'

config radio 'radio1'
	option enabled '1'
	option check_interval '300'
	option idle_seconds '300'
	option channels '1 6 11'
	option util_threshold '50'
	option sustained_count '3'
	option improvement_threshold '30'
	option cooldown '3600'
	option dfs_allowed '0'
	option prefer_non_dfs '0'
```

The defaults are conservative: 3 checks at 5-minute intervals (15 minutes of sustained >50% utilization) before evaluating, and a 1-hour cooldown between switches. DFS channels require a higher improvement score since CSA to DFS triggers a 60-second CAC.

With `prefer_non_dfs` enabled, the daemon proactively moves off a DFS channel whenever a non-DFS alternative scores within `non_dfs_margin` points of the current channel, regardless of congestion (still subject to the cooldown). This is useful in multi-AP roaming setups: clients cannot actively probe on DFS channels, which breaks 802.11k/v-based steering (usteer, DAWN) and slows down roaming. DFS channels are then only used when the non-DFS spectrum is significantly more congested.

## Tests

```bash
scp net/wifi-auto-channel/tests/test_channel.uc root@router:/tmp/
ssh root@router ucode /tmp/test_channel.uc
```

102 tests covering channel math, scoring, DFS detection across different regulatory domains, and best-channel selection.

## Tested on

- Netgear R7800 (QCA9984/ath10k, VHT160, OpenWrt 25.12)
- MediaTek mt76 AP (HE80, OpenWrt 25.12)
