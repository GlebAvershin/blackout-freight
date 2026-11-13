"""Summarize external first sessions without treating missing observations as failures."""

import argparse
import csv
import json
import math
import statistics
from pathlib import Path

EXCLUDED = {11969424328, 11984313673}
MINIMUM_COHORT = 15
FIELDS = (
    'participant_code', 'user_id', 'is_test', 'pickup_seconds',
    'delivery_seconds', 'second_shift_started', 'session_seconds',
    'returned_d1', 'returned_d7',
)


def count_outcomes(outcomes):
    return {
        'success': outcomes.count(True),
        'observed': len(outcomes) - outcomes.count(None),
        'unknown': outcomes.count(None),
    }


def threshold_status(minimum, maximum, target, cohort_size):
    if cohort_size < MINIMUM_COHORT or maximum is None:
        return 'insufficient_data'
    if minimum is not None and minimum >= target:
        return 'met'
    if maximum < target:
        return 'below'
    return 'inconclusive'


def summarize(rows):
    players = []
    seen_codes = set()
    seen_users = set()
    for line, row in enumerate(rows, start=2):
        if any(row.get(field) is None for field in FIELDS):
            raise ValueError(f'Line {line}: missing column value; use an empty cell for unknown')
        entry_channel = (row.get('entry_channel') or '').strip()
        row = {field: row[field].strip() for field in FIELDS}
        if row['is_test'] not in ('0', '1'):
            raise ValueError(f'Line {line}: is_test must be 0 or 1')
        if row['is_test'] == '1':
            continue
        if row['user_id'] and (not row['user_id'].isascii() or not row['user_id'].isdigit()):
            raise ValueError(f'Line {line}: user_id must be a positive integer or blank')
        user_id = int(row['user_id']) if row['user_id'] else None
        if user_id == 0:
            raise ValueError(f'Line {line}: user_id must be a positive integer or blank')
        if user_id in EXCLUDED:
            continue
        code = row['participant_code']
        if not code or code in seen_codes:
            raise ValueError(f'Line {line}: expected a unique participant_code')
        if user_id in seen_users:
            raise ValueError(f'Line {line}: duplicate user_id in first-session observations')
        seen_codes.add(code)
        if user_id is not None:
            seen_users.add(user_id)

        for field in ('second_shift_started', 'returned_d1', 'returned_d7'):
            if row[field] not in ('', '0', '1'):
                raise ValueError(f'Line {line}: {field} must be blank, 0 or 1')
        for field in ('pickup_seconds', 'delivery_seconds', 'session_seconds'):
            value = row[field]
            if value == 'never' and field != 'session_seconds':
                row[field] = math.inf
            elif not value:
                row[field] = None
            else:
                try:
                    seconds = float(value)
                except ValueError:
                    raise ValueError(f'Line {line}: invalid {field}') from None
                if not math.isfinite(seconds) or seconds < 0:
                    raise ValueError(f'Line {line}: invalid {field}')
                row[field] = seconds
        players.append({**row, 'entry_channel': entry_channel})

    channels = {}
    unknown_channel = []
    for player in players:
        channel = player['entry_channel']
        if channel:
            channels.setdefault(channel, []).append(player)
        else:
            unknown_channel.append(player)

    report = session_metrics(players)
    report['byEntryChannel'] = {
        channel: session_metrics(channels[channel], include_thresholds=False)
        for channel in sorted(channels)
    }
    report['unknownEntryChannel'] = session_metrics(unknown_channel, include_thresholds=False)
    return report


def session_metrics(players, *, include_thresholds=True):
    def within(field, limit):
        return count_outcomes([
            None if row[field] is None else row[field] <= limit for row in players
        ])

    def binary(field, group):
        return count_outcomes([
            None if row[field] == '' else row[field] == '1' for row in group
        ])

    picked = [row for row in players if row['pickup_seconds'] not in (None, math.inf)]
    unknown_pickup = [row for row in players if row['pickup_seconds'] is None]
    durations = [row['session_seconds'] for row in players if row['session_seconds'] is not None]
    pickup = within('pickup_seconds', 45)
    delivery = within('delivery_seconds', 90)
    repeat = binary('second_shift_started', picked)
    report = {
        'externalFirstSessions': len(players),
        'sessionSeconds': {
            'mean': statistics.mean(durations) if durations else None,
            'median': statistics.median(durations) if durations else None,
            'observed': len(durations),
            'unknown': len(players) - len(durations),
        },
        'pickupWithin45': pickup,
        'deliveryWithin90': delivery,
        'secondShiftAmongPickups': {**repeat, 'unknownPickup': len(unknown_pickup)},
        'd1': binary('returned_d1', players),
        'd7': binary('returned_d7', players),
    }
    if not include_thresholds:
        return report

    # Unknown pickup only affects a bound if including that player could move it.
    possible_repeat_failures = sum(row['second_shift_started'] != '1' for row in unknown_pickup)
    possible_repeat_successes = sum(row['second_shift_started'] != '0' for row in unknown_pickup)
    repeat_minimum = len(picked) + possible_repeat_failures
    repeat_maximum = len(picked) + possible_repeat_successes
    worst_repeat_rate = repeat['success'] / repeat_minimum if repeat_minimum else None
    if repeat_maximum:
        best_repeat_rate = (repeat['success'] + repeat['unknown'] + possible_repeat_successes) / repeat_maximum
    else:
        best_repeat_rate = 0 if possible_repeat_failures else None

    def cohort_threshold(counts, target):
        if not players:
            return 'insufficient_data'
        return threshold_status(
            counts['success'] / len(players),
            (counts['success'] + counts['unknown']) / len(players),
            target,
            len(players),
        )
    report['workingThresholds'] = {
        'minimumExternalFirstSessions': MINIMUM_COHORT,
        'pickupWithin45': cohort_threshold(pickup, 0.7),
        'deliveryWithin90': cohort_threshold(delivery, 0.5),
        'secondShiftAmongPickups': threshold_status(worst_repeat_rate, best_repeat_rate, 0.3, len(players)),
    }
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv', type=Path)
    args = parser.parse_args()
    try:
        with args.csv.open(encoding='utf-8-sig', newline='') as source:
            reader = csv.DictReader(source, strict=True)
            missing = set(FIELDS) - set(reader.fieldnames or [])
            if missing:
                raise ValueError('Missing columns: ' + ', '.join(sorted(missing)))
            report = summarize(reader)
    except (OSError, ValueError, csv.Error) as error:
        parser.error(str(error))
    print(json.dumps(report, ensure_ascii=False, indent=2))
