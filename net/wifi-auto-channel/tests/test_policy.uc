'use strict';
import { vacant_ready, valid_sample, usable_survey } from 'wifi-auto-channel.policy';
let passed = 0;
function check(value, message) {
	if (!value) die(message + '\n');
	passed++;
}
let state = {};
check(!vacant_ready(state, 0, 1000, 300), 'initial observation must wait');
for (let now = 1030; now < 1300; now += 30)
	check(!vacant_ready(state, 0, now, 300), 'vacancy interval incomplete');
check(vacant_ready(state, 0, 1300, 300), 'five minute vacancy eligible');
check(!vacant_ready(state, 1, 1330, 300), 'connected client blocks optimization');
check(!vacant_ready(state, 0, 1360, 300), 'vacancy restarts after client');
check(!vacant_ready(state, null, 1390, 300), 'unknown client state blocks optimization');
check(!vacant_ready(state, 0, 1420, 300), 'vacancy restarts after missing status');
check(!vacant_ready(state, 0, 1800, 300), 'missed observations restart vacancy');
check(!vacant_ready(state, 0, 1200, 300), 'clock reversal restarts vacancy');
check(valid_sample({time:100, time_busy:50}), 'valid sample');
check(!valid_sample({time:0, time_busy:0}), 'zero sample rejected');
check(!valid_sample({time:100, time_busy:-1}), 'negative busy rejected');
check(!valid_sample({time:100, time_busy:101}), 'busy beyond total rejected');
check(!valid_sample({time:100}), 'missing busy rejected');
let survey = {
	"2412": {time:100, time_busy:99},
	"2437": {time:100, time_busy:100},
	"2462": {time:100, time_busy:98},
};
let frequencies = [2412, 2437, 2462];
check(usable_survey(survey, frequencies) == null, 'uniform saturation blocks changes');
survey[2437].time_busy = 40;
check(length(keys(usable_survey(survey, frequencies))) == 3, 'distinct valid candidate data accepted');
delete survey[2462];
check(usable_survey(survey, frequencies) == null, 'missing candidate blocks changes');
check(usable_survey({}, []) == null, 'empty candidates rejected');
printf('Vacancy and survey policy tests passed: %d\n', passed);
