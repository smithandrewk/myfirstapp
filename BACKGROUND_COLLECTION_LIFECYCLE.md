# Continuous Background Data Collection - Lifecycle Documentation

## Overview
This document describes the complete lifecycle of the continuous accelerometer data collection system with automatic restart ("sticky mode") and auto-transfer capabilities.

---

## 🔄 System States

### SessionState Enum
- **idle**: Not collecting, ready to start
- **starting**: Initializing collection and extended runtime session
- **running**: Actively collecting data in foreground
- **backgrounded**: Actively collecting data in background
- **stopping**: Shutting down collection
- **error(String)**: Collection failed with error message

---

## 📱 Normal Operation Flow

### 1. User Presses "Start"
```
User Taps Start Button
    ↓
Set shouldContinueCollecting = true (sticky mode enabled)
    ↓
Save state to UserDefaults (persists across app restarts)
    ↓
Start WKExtendedRuntimeSession (for background execution)
    ↓
Create session file: "accel_session_2025-01-15_14-30-00_part1.csv"
    ↓
Initialize file with CSV header
    ↓
Start CMMotionManager at 10Hz
    ↓
Start duration timer
    ↓
State → RUNNING
    ↓
Begin collecting data...
```

### 2. Data Collection (Every 0.1 seconds)
```
Accelerometer reading received
    ↓
Append to in-memory buffer
    ↓
Buffer reaches 100 readings?
    ├─ YES → Save buffer to disk (append to CSV)
    │        Clear buffer
    │        Continue collecting
    └─ NO  → Continue collecting
```

**Result**: Data is saved to disk every 100 readings (~10 seconds at 10Hz)
**Benefit**: Prevents data loss if app crashes

---

## 🌙 Background Behavior

### 3. User Backgrounds the App (Crown pressed, wrist down, etc.)
```
App enters background
    ↓
Scene phase changes to .background
    ↓
motionManager.handleAppDidEnterBackground() called
    ↓
State → BACKGROUNDED
    ↓
⚡ WKExtendedRuntimeSession KEEPS RUNNING
    ↓
Data collection CONTINUES uninterrupted
    ↓
Periodic saves to disk CONTINUE (every 100 readings)
```

**Result**: Collection continues seamlessly in background
**Duration**: Extended runtime session typically lasts several hours

### 4. User Opens Another App or Starts Workout
```
Watch OS starts other app/workout
    ↓
Our app remains in background
    ↓
Extended runtime session STILL ACTIVE
    ↓
Data collection CONTINUES
    ↓
Note: Workout apps may compete for sensor access,
      but our session attempts to maintain priority
```

---

## ⏰ Extended Runtime Session Expiration (Automatic Restart)

### 5. Session About to Expire (System-Initiated)
```
WKExtendedRuntimeSession will expire (typically after 4-6 hours)
    ↓
extendedRuntimeSessionWillExpire() delegate called
    ↓
⚠️ WARNING: Session expiring soon!
    ↓
┌─────────────────────────────────────────┐
│ AUTOMATIC RECOVERY SEQUENCE             │
├─────────────────────────────────────────┤
│ 1. Save current buffer to disk          │
│ 2. Auto-transfer current file to iPhone │
│ 3. Create NEW session file with part2   │
│ 4. Start NEW extended runtime session   │
│ 5. Continue data collection seamlessly  │
└─────────────────────────────────────────┘
    ↓
File: "accel_session_2025-01-15_20-45-30_part2.csv"
    ↓
✓ Collection resumes automatically
    ↓
State → RUNNING
```

**Result**: Zero data loss, automatic file rotation, continuous operation
**File Management**: Each session creates a new file part (part1, part2, part3...)
**Transfer**: Previous file automatically sent to iPhone before rotation

---

## 🔄 App Lifecycle Events

### 6. App Comes to Foreground
```
User opens app
    ↓
Scene phase changes to .active
    ↓
motionManager.handleAppWillEnterForeground() called
    ↓
State → RUNNING (if collecting)
    ↓
Call attemptRecovery() (just in case)
    ↓
UI updates with current data count and duration
```

### 7. App Crashes or System Terminates App
```
App terminated unexpectedly
    ↓
shouldContinueCollecting = true (persisted in UserDefaults)
    ↓
═══════════════════════════════════
User next opens app
    ↓
MotionManager.init() called
    ↓
loadCollectionState() reads UserDefaults
    ↓
Detects shouldContinueCollecting = true
    ↓
Wait 1 second for app to stabilize
    ↓
✓ AUTOMATICALLY RESTART collection!
    ↓
Creates new recovery file:
"accel_session_2025-01-15_21-10-00_recovery3.csv"
    ↓
State → RUNNING
═══════════════════════════════════
```

**Result**: Even after crash or force quit, collection auto-resumes on next launch
**Sticky Mode**: System "remembers" user's intent to collect continuously

---

## 🛑 User Stops Collection

### 8. User Presses "Stop"
```
User taps Stop button
    ↓
Set shouldContinueCollecting = false
    ↓
Save state to UserDefaults (disables auto-restart)
    ↓
Stop CMMotionManager
    ↓
Save remaining buffer to disk
    ↓
Auto-transfer current file to iPhone
    ↓
Stop extended runtime session
    ↓
Stop duration timer
    ↓
State → IDLE
    ↓
✓ Collection stopped (will NOT auto-restart)
```

**Result**: Clean shutdown, final file transferred, sticky mode disabled

---

## 📤 Auto-Transfer Behavior

### When Files Are Auto-Transferred to iPhone:

1. **Session Expiration** (before starting new part)
   - Ensures completed files don't pile up on watch

2. **User Stops Collection**
   - Sends final file immediately

3. **System Invalidates Session**
   - Before attempting recovery/restart

4. **Recovery Events**
   - Before creating new recovery file

### Transfer Mechanism:
```
transferSessionFileToiPhone(fileName)
    ↓
Check file exists on disk
    ↓
Add to allSessionFiles tracking list
    ↓
WatchConnectivity transfers file in background
    ↓
iPhone receives file automatically
    ↓
File appears in iPhone app's Documents directory
```

---

## ⚠️ Error Handling & Recovery

### Scenario: Extended Runtime Session Invalidated
```
System invalidates session (low battery, system pressure, etc.)
    ↓
extendedRuntimeSession(didInvalidateWith:) called
    ↓
Check: shouldContinueCollecting?
    ├─ YES → Save buffer
    │        Transfer current file
    │        Wait 0.5 seconds
    │        Call attemptRecovery()
    │            ↓
    │        Create new extended runtime session
    │        Create new recovery file
    │        Restart accelerometer
    │        ✓ Collection resumes
    │
    └─ NO  → Do nothing (user stopped intentionally)
```

### Scenario: Accelerometer Stops Unexpectedly
```
App foregrounds, detects accelerometer inactive
    ↓
attemptRecovery() called from scene phase change
    ↓
Check: shouldContinueCollecting?
    ├─ YES → Save buffer
    │        Transfer file
    │        Restart session
    │        Create recovery file
    │        ✓ Resume collection
    │
    └─ NO  → Skip recovery
```

---

## 💾 File Management Strategy

### File Naming Convention:
- **Normal parts**: `accel_session_2025-01-15_14-30-00_part1.csv`
- **Recovery parts**: `accel_session_2025-01-15_21-10-00_recovery3.csv`

### Why Multiple Files?
1. **Session Expiration**: System limits extended runtime duration (4-6 hours)
2. **Data Safety**: Smaller files transferred incrementally
3. **Recovery Tracking**: Easy to identify recovery vs. normal operation
4. **Sequence Numbers**: Tracks session continuity

### File Structure:
```csv
Timestamp,X,Y,Z
0.123456,0.012,-0.981,0.045
0.223456,-0.003,-0.975,0.051
...
```

---

## 🔐 State Persistence (UserDefaults)

### Saved State:
```swift
UserDefaults keys:
- shouldContinueCollecting: Bool  // Is sticky mode active?
- sessionFileSequence: Int        // Current part number
```

### Why Persist?
- Survives app termination
- Survives device restart (if app relaunches)
- Enables true "sticky" behavior
- User doesn't need to restart manually

---

## 🎯 Key Design Principles

### 1. **Sticky Mode**
Once started, collection continues until user explicitly stops, even through:
- App backgrounding
- Session expirations
- System interruptions
- App crashes (resumes on relaunch)
- Device sleep

### 2. **Zero Data Loss**
- Periodic saves every 100 readings
- Auto-transfer before session rotation
- Buffer saves before any restart

### 3. **Seamless Continuity**
- Session expirations handled transparently
- File rotation automatic
- No user intervention required

### 4. **Observable State**
- UI shows current state (RUNNING, BACKGROUNDED, etc.)
- Duration timer continues across sessions
- Background indicator when app backgrounded

---

## 📊 Example Timeline

```
Time  | Event                          | State        | Files
------|--------------------------------|--------------|---------------------------
14:30 | User presses Start             | RUNNING      | part1.csv (creating)
14:35 | User backgrounds app           | BACKGROUNDED | part1.csv (10 saves)
16:00 | User starts workout            | BACKGROUNDED | part1.csv (90 saves)
18:30 | Session expires (4hr limit)    | RUNNING      | part1.csv → iPhone
      | Auto-restart with part2        |              | part2.csv (creating)
20:00 | Low battery, session killed    | RUNNING      | part2.csv → iPhone
      | Auto-recovery with recovery3   |              | recovery3.csv (creating)
20:15 | User force quits app           | -            | recovery3.csv (saved)
20:20 | User opens app                 | RUNNING      | recovery3.csv (resumed!)
      | Auto-resume detected           |              |
21:00 | User presses Stop              | IDLE         | recovery3.csv → iPhone
      | Sticky mode disabled           |              | All files transferred
```

---

## 🔍 Verification & Testing

### How to Verify Sticky Mode Works:

1. **Start collection** → Press Start button
2. **Background app** → Press crown, should see "Background Active" indicator
3. **Open other apps** → Collection continues
4. **Wait several hours** → Should auto-rotate files and transfer
5. **Force quit app** → Swipe up in app switcher
6. **Reopen app** → Should auto-resume within 1 second
7. **Press Stop** → Should stop permanently (no auto-restart)

### Console Log Indicators:
- `✓ Started continuous data collection (sticky mode enabled)`
- `⚠️ Extended runtime session will expire - auto-restarting`
- `→ Auto-transferring session file to iPhone`
- `↻ Auto-restarting data collection (sticky mode)`
- `✓ Recovery successful - collection resumed`
- `✓ Stopped data collection` (when user stops)

---

## 🏢 Industry Best Practices Applied

This implementation follows several industry best practices:

1. **State Machine Pattern**: Clear state transitions
2. **Persistence Layer**: UserDefaults for critical state
3. **Graceful Degradation**: Handles failures without crashing
4. **Automatic Recovery**: Self-healing system
5. **Incremental Saves**: Prevents data loss
6. **File Rotation**: Manages storage efficiently
7. **Observable Pattern**: UI reflects true state
8. **Delegate Pattern**: WKExtendedRuntimeSessionDelegate
9. **Singleton Pattern**: Shared MotionManager instance
10. **Background Processing**: Minimal battery impact

---

## ⚡ Performance Characteristics

- **Battery Impact**: Moderate (continuous sensor + extended runtime session)
- **Storage**: ~1MB per hour at 10Hz (varies with precision)
- **Session Duration**: 4-6 hours before auto-rotation
- **Restart Latency**: <1 second for automatic recovery
- **Transfer Rate**: Depends on WatchConnectivity availability

---

## 🎓 Summary

**What makes this "sticky"?**
- `shouldContinueCollecting` flag persists user's intent
- Automatic restart on session expiration
- Automatic recovery from crashes/interruptions
- State survives app termination

**What prevents data loss?**
- Saves to disk every 100 readings (~10 seconds)
- Auto-transfer before file rotation
- Buffer flush before any restart

**What enables continuous operation?**
- WKExtendedRuntimeSession for background execution
- Automatic session renewal on expiration
- State persistence across app lifecycle
- Recovery mechanisms for all failure modes

**Result**: True continuous data collection that only stops when user says stop! 🎯
