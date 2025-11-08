# Field Test Plan - Background Data Collection

## Test Objective
Verify that accelerometer data is collected continuously in the background under all usage scenarios, and that data transfer to iPhone works reliably.

---

## Test Environment Setup

### Prerequisites
- [ ] Watch fully charged (>80%)
- [ ] iPhone paired and within Bluetooth range (unless testing out-of-range)
- [ ] Watch app installed and permissions granted
- [ ] iPhone app installed
- [ ] Clear all existing data before starting test suite

### Data Collection Tools
- Console app (Mac) for real-time logs
- Python scripts for data validation (see validation section)
- Spreadsheet for tracking test results (see Test Matrix below)

---

## Test Categories

### Category 1: Basic Operation Tests
**Goal**: Verify core functionality works as expected

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| B001 | Start/Stop Collection | 1. Tap Start<br>2. Wait 1 minute<br>3. Tap Stop | Data collected, no gaps | ⬜ | |
| B002 | Short Collection (30s) | 1. Start<br>2. Wait 30s<br>3. Stop | ~300 data points (10Hz) | ⬜ | |
| B003 | Medium Collection (10m) | 1. Start<br>2. Wait 10 minutes<br>3. Stop | ~6000 data points | ⬜ | |
| B004 | Long Collection (3h) | 1. Start<br>2. Wait 3 hours<br>3. Stop | ~108,000 data points, no gaps | ⬜ | |
| B005 | Transfer to iPhone | 1. Collect data<br>2. Stop<br>3. Tap "Send to iPhone" | File appears on iPhone with all data | ⬜ | |
| B006 | Clear Data | 1. Collect data<br>2. Clear Data<br>3. Check filesystem | All CSV files deleted, counter reset | ⬜ | |

### Category 2: Background Collection Tests
**Goal**: Verify data collection continues when app is backgrounded

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| BG001 | App Backgrounded (Screen Off) | 1. Start collection<br>2. Lower wrist (screen off)<br>3. Wait 5 minutes<br>4. Raise wrist, Stop | Continuous data, no gaps | ⬜ | |
| BG002 | App Backgrounded (Home) | 1. Start collection<br>2. Press digital crown (go home)<br>3. Wait 5 minutes<br>4. Open app, Stop | Continuous data, no gaps | ⬜ | |
| BG003 | Switch to Another App | 1. Start collection<br>2. Switch to Messages/Clock<br>3. Wait 5 minutes<br>4. Return to app, Stop | Continuous data, no gaps | ⬜ | |
| BG004 | During Phone Call | 1. Start collection<br>2. Make/receive phone call<br>3. Talk for 5 minutes<br>4. End call, Stop collection | Continuous data, no gaps | ⬜ | |
| BG005 | Multiple Background Cycles | 1. Start collection<br>2. Background/foreground 5x<br>3. Wait 10 minutes total<br>4. Stop | Continuous data, no gaps | ⬜ | |

### Category 3: Workout Integration Tests
**Goal**: Verify collection continues during workouts

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|---|--------|-------|
| W001 | During Outdoor Walk | 1. Start collection<br>2. Start Workout (Walk)<br>3. Walk 15 minutes<br>4. End workout<br>5. Stop collection | Continuous data during entire period | ⬜ | |
| W002 | During Outdoor Run | 1. Start collection<br>2. Start Workout (Run)<br>3. Run 15 minutes<br>4. End workout<br>5. Stop collection | Continuous data during entire period | ⬜ | |
| W003 | During Indoor Exercise | 1. Start collection<br>2. Start Workout (Indoor)<br>3. Exercise 15 minutes<br>4. End workout<br>5. Stop collection | Continuous data during entire period | ⬜ | |
| W004 | Start Workout First | 1. Start Workout<br>2. Start collection<br>3. Exercise 15 minutes<br>4. Stop collection<br>5. End workout | Continuous data collection | ⬜ | |
| W005 | Multiple Workouts | 1. Start collection<br>2. Workout 1 (10m)<br>3. Rest (5m)<br>4. Workout 2 (10m)<br>5. Stop collection | Continuous data through all periods | ⬜ | |

### Category 4: Extended Runtime Tests
**Goal**: Verify session restarts and recovery work correctly

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| ER001 | Session Expiration (~4h) | 1. Start collection<br>2. Leave running for 4+ hours<br>3. Stop | Multiple part files, all continuous | ⬜ | Check logs for session restart |
| ER002 | Overnight Collection | 1. Start before bed<br>2. Sleep 8 hours<br>3. Stop in morning | Data collected throughout night | ⬜ | Battery impact? |
| ER003 | 24-Hour Collection | 1. Start collection<br>2. Normal daily activities<br>3. Stop after 24h | Multiple session files, continuous data | ⬜ | Battery survives? |

### Category 5: Transfer Edge Cases
**Goal**: Verify file transfer works under various conditions

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| T001 | Transfer While iPhone App Closed | 1. Force quit iPhone app<br>2. Collect data on watch<br>3. Send to iPhone | File transfers successfully | ⬜ | |
| T002 | Transfer While iPhone App Open | 1. Open iPhone app<br>2. Collect data on watch<br>3. Send to iPhone | File appears in iPhone app | ⬜ | |
| T003 | Transfer Multiple Files | 1. Collect session 1<br>2. Collect session 2<br>3. Don't clear between<br>4. Send to iPhone | Both files transfer | ⬜ | |
| T004 | Transfer Large File (>1MB) | 1. Collect for 2+ hours<br>2. Send to iPhone | Large file transfers completely | ⬜ | Check file size |
| T005 | Transfer at Edge of Range | 1. Collect data<br>2. Walk to edge of BT range<br>3. Send to iPhone | Transfer completes or fails gracefully | ⬜ | |
| T006 | Re-transfer Same File | 1. Transfer file once<br>2. Don't clear<br>3. Transfer again | File re-transfers (overwrites) | ⬜ | |

### Category 6: App Lifecycle Tests
**Goal**: Verify persistence and recovery across app lifecycle events

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| L001 | Force Quit During Collection | 1. Start collection<br>2. Force quit app<br>3. Wait 2 minutes<br>4. Reopen app | Collection resumes automatically | ⬜ | Check for data gap |
| L002 | Watch Restart During Collection | 1. Start collection<br>2. Restart watch<br>3. Wait for boot<br>4. Open app | Collection resumes automatically | ⬜ | |
| L003 | Low Battery Behavior | 1. Start collection at ~10% battery<br>2. Let battery drain<br>3. Check data | Graceful handling, data saved | ⬜ | |
| L004 | watchOS Update | 1. Start collection<br>2. Install watchOS update<br>3. Reopen after update | Collection stopped, data preserved | ⬜ | |

### Category 7: Error Handling Tests
**Goal**: Verify app handles error conditions gracefully

| Test ID | Test Case | Steps | Expected Result | Status | Notes |
|---------|-----------|-------|-----------------|--------|-------|
| E001 | No iPhone Paired | 1. Unpair iPhone<br>2. Collect data<br>3. Send to iPhone | Shows helpful error message | ⬜ | |
| E002 | iPhone Out of Range | 1. Collect data<br>2. Leave iPhone behind<br>3. Send to iPhone | Queues transfer or shows error | ⬜ | |
| E003 | Disk Full | 1. Fill watch storage<br>2. Start collection | Shows error or stops gracefully | ⬜ | Hard to test |
| E004 | Multiple Rapid Start/Stop | 1. Tap Start/Stop 10x rapidly | App remains stable | ⬜ | |

---

## Test Matrix (Permutation Testing)

**Use this matrix to test combinations of conditions:**

| Condition Variables | Values to Test |
|---------------------|----------------|
| **Collection Duration** | 30s, 5m, 30m, 2h, 8h, 24h |
| **App State** | Foreground, Background (screen off), Background (home), Background (other app) |
| **Watch State** | Active use, Wrist down, Charging |
| **iPhone State** | App open, App closed, Out of range, Airplane mode |
| **Concurrent Activity** | None, Workout, Phone call, Music playing, Navigation |
| **Session Events** | None, Session expiration, App quit, Watch restart |

**Recommended High-Priority Permutations:**
1. ✅ Long duration (3h) + Background + Workout running
2. ✅ Medium duration (30m) + Background + iPhone out of range
3. ✅ Long duration (8h) + Multiple background/foreground cycles
4. ✅ Session expiration + Workout + Background
5. ✅ Multiple short sessions + Transfer with iPhone app closed

---

## Data Validation

### Python Validation Scripts

Create `validate_data.py` in the project root:

```python
import pandas as pd
import sys
from datetime import datetime, timedelta

def validate_csv(filepath):
    """Validate accelerometer data CSV file"""
    print(f"\n{'='*60}")
    print(f"Validating: {filepath}")
    print(f"{'='*60}\n")

    # Load data
    df = pd.read_csv(filepath)

    # Basic stats
    print(f"Total rows: {len(df):,}")
    print(f"Time range: {df['Timestamp'].min():.2f} to {df['Timestamp'].max():.2f}")
    print(f"Duration: {(df['Timestamp'].max() - df['Timestamp'].min()):.2f} seconds")
    print(f"         = {(df['Timestamp'].max() - df['Timestamp'].min())/60:.2f} minutes")
    print(f"         = {(df['Timestamp'].max() - df['Timestamp'].min())/3600:.2f} hours")

    # Check for gaps
    df['time_diff'] = df['Timestamp'].diff()
    expected_interval = 0.1  # 10 Hz = 0.1s intervals
    tolerance = 0.05  # Allow 50ms tolerance

    gaps = df[df['time_diff'] > expected_interval + tolerance]

    if len(gaps) > 0:
        print(f"\n⚠️  WARNING: Found {len(gaps)} gaps in data:")
        for idx, row in gaps.head(10).iterrows():
            print(f"  - Gap of {row['time_diff']:.3f}s at timestamp {row['Timestamp']:.2f}")
        if len(gaps) > 10:
            print(f"  ... and {len(gaps)-10} more gaps")
    else:
        print(f"\n✅ No significant gaps found (all intervals within {expected_interval}±{tolerance}s)")

    # Calculate actual sample rate
    avg_interval = df['time_diff'].mean()
    actual_hz = 1.0 / avg_interval if avg_interval > 0 else 0
    print(f"\nAverage sample interval: {avg_interval:.4f}s")
    print(f"Actual sample rate: {actual_hz:.2f} Hz (expected: 10 Hz)")

    # Check for duplicates
    duplicates = df[df['Timestamp'].duplicated()]
    if len(duplicates) > 0:
        print(f"\n⚠️  WARNING: Found {len(duplicates)} duplicate timestamps")
    else:
        print(f"✅ No duplicate timestamps")

    # Check data ranges (typical accelerometer range is ±2g to ±16g)
    print(f"\nData ranges:")
    print(f"  X: {df['X'].min():.3f} to {df['X'].max():.3f} (mean: {df['X'].mean():.3f})")
    print(f"  Y: {df['Y'].min():.3f} to {df['Y'].max():.3f} (mean: {df['Y'].mean():.3f})")
    print(f"  Z: {df['Z'].min():.3f} to {df['Z'].max():.3f} (mean: {df['Z'].mean():.3f})")

    # Check for suspicious constant values
    for axis in ['X', 'Y', 'Z']:
        if df[axis].std() < 0.001:
            print(f"⚠️  WARNING: {axis} axis has very low variance (std: {df[axis].std():.6f})")

    # Summary
    print(f"\n{'='*60}")
    if len(gaps) == 0 and len(duplicates) == 0:
        print("✅ VALIDATION PASSED")
    else:
        print("⚠️  VALIDATION COMPLETED WITH WARNINGS")
    print(f"{'='*60}\n")

    return {
        'total_rows': len(df),
        'duration_seconds': df['Timestamp'].max() - df['Timestamp'].min(),
        'gaps': len(gaps),
        'duplicates': len(duplicates),
        'actual_hz': actual_hz
    }

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python validate_data.py <csv_file_path>")
        sys.exit(1)

    validate_csv(sys.argv[1])
```

### Usage:
```bash
python validate_data.py accel_session_2025-11-06_15-15-46_part1.csv
```

---

## Test Execution Tracking

### Recommended Tools:

1. **Google Sheets** (Best for collaborative testing)
   - Create columns: Test ID, Date, Tester, Status, Notes, Data File Link
   - Color code: 🟢 Pass, 🔴 Fail, 🟡 Partial, ⚪ Not Run
   - Track battery drain percentage
   - Link to CSV files in shared drive

2. **Linear/Jira** (For professional projects)
   - Create ticket for each failed test
   - Track bugs separately
   - Link test results to issues

3. **Markdown Checklist** (Simple, version controlled)
   - Copy this file, check boxes as you test
   - Commit results after each test session

---

## Test Reporting Template

After each test session, record:

```markdown
## Test Session: [DATE]

**Tester:** [Name]
**Watch Model:** [e.g., Series 9]
**watchOS Version:** [e.g., 11.2]
**Battery at Start:** [e.g., 95%]
**Battery at End:** [e.g., 72%]

### Tests Executed:
- [Test ID]: ✅/❌ - [Brief notes]

### Issues Found:
1. [Description] - [Severity: Critical/High/Medium/Low]

### Data Files:
- `filename.csv` - [Test ID] - [File size] - [Duration]

### Overall Assessment:
[Summary of findings]
```

---

## How Big Companies Do This

### Testing Pyramid:
1. **Unit Tests** (Fast, many) - Test individual functions
2. **Integration Tests** (Medium) - Test components together
3. **Field Tests** (Slow, few) - Test real-world scenarios ← You are here

### Best Practices:
- **Automated Testing**: Use XCTest for unit tests (not applicable for field tests)
- **Test Matrix**: Cover all permutations systematically
- **Regression Testing**: Re-run failed tests after fixes
- **Dog-fooding**: Use your own app daily
- **Beta Testing**: Give to trusted users
- **Analytics**: Track crashes/errors in production

### Companies like Apple/Fitbit:
- Have dedicated QA teams testing on real devices 24/7
- Use device farms (100s of watches) for automated testing
- Collect telemetry from beta users
- Run soak tests (days/weeks of continuous operation)
- Test in environmental chambers (hot/cold/humid)

---

## Quick Start: Essential Test Suite (30 minutes)

If you only have limited time, run these critical tests first:

1. ✅ **B004** - 3 hour collection (leave running)
2. ✅ **BG002** - Background with home
3. ✅ **W001** - During outdoor walk
4. ✅ **T001** - Transfer with iPhone app closed
5. ✅ **L001** - Force quit during collection

Then validate all CSV files with Python script.

---

## Next Steps

1. Copy this to Google Sheets for easier tracking
2. Start with Essential Test Suite
3. Run validation script on all generated CSV files
4. Fix any issues found
5. Gradually expand to full test matrix
6. Keep test results for regression testing after changes

---

## Notes Section

Use this space to track patterns, observations, and learnings:

-
-
-
