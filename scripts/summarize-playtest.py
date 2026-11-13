"""Summarize recorded external first sessions; blanks are unknown, never invented failures."""
import argparse
import csv
import json
import statistics
from pathlib import Path
EXCLUDED={11969424328,11984313673}
def summarize(rows):
    players=[]
    seen=set()
    for row in rows:
        if row['is_test'] not in ('0','1'): raise ValueError('is_test must be 0 or 1')
        if row['is_test']=='1' or (row['user_id'] and int(row['user_id']) in EXCLUDED): continue
        code=row['participant_code'].strip()
        if not code or code in seen: raise ValueError('Expected unique participant_code for each first session')
        seen.add(code)
        for field in ('second_shift_started','returned_d1','returned_d7'):
            if row[field] not in ('','0','1'): raise ValueError(field+' must be blank, 0 or 1')
        for field in ('pickup_seconds','delivery_seconds','session_seconds'):
            if field!='session_seconds' and row[field]=='never': continue
            if row[field] and (not float(row[field])>=0 or float(row[field])==float('inf')): raise ValueError('Invalid '+field)
        players.append(row)
    def ratio(field,predicate):
        known=[r for r in players if r[field]!='']
        return {'success':sum(predicate(r[field]) for r in known),'observed':len(known),'unknown':len(players)-len(known)}
    picked=[r for r in players if r['pickup_seconds'] not in ('','never')]
    repeat_known=[r for r in picked if r['second_shift_started']!='']
    durations=[float(r['session_seconds']) for r in players if r['session_seconds']]
    return {'externalFirstSessions':len(players),
        'sessionSeconds':{'mean':statistics.mean(durations) if durations else None,
                          'median':statistics.median(durations) if durations else None,
                          'observed':len(durations),'unknown':len(players)-len(durations)},
        'pickupWithin45':ratio('pickup_seconds',lambda v:v!='never' and float(v)<=45),
        'deliveryWithin90':ratio('delivery_seconds',lambda v:v!='never' and float(v)<=90),
        'secondShiftAmongPickups':{'success':sum(r['second_shift_started']=='1' for r in repeat_known),'observed':len(repeat_known)},
        'd1':ratio('returned_d1',lambda v:v=='1'),'d7':ratio('returned_d7',lambda v:v=='1')}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('csv',type=Path)
    args=parser.parse_args()
    with args.csv.open(newline='') as source: report=summarize(list(csv.DictReader(source)))
    print(json.dumps(report,ensure_ascii=False,indent=2))
