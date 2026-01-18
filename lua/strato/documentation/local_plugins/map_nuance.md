# map_nuance.lua - Technical Documentation

## Overview

A Neovim plugin that manages system-wide keyboard layout changes (Caps Lock → Ctrl, tapped Ctrl → Escape) with multi-instance coordination to prevent conflicts when multiple Neovim instances are running.

## Core Functionality

### Keyboard Modifications
- **Caps Lock remapping**: `setxkbmap -option ctrl:nocaps`
- **Tap-to-Escape**: `xcape -e 'Control_L=Escape' -t 150`
- **Cleanup on exit**: Restores normal keyboard layout

### Multi-Instance Coordination

Uses a shared lockfile (`/tmp/nvim-devkeys.lock`) with reference counting:

```json
{
  "count": 2,
  "activated_at": 1234567890,
  "pids": [47994, 48032]
}
```

**Behavior:**
- **First instance**: Spawns xcape, creates lockfile with count=1
- **Additional instances**: Increment count, append PID to tracking array
- **Instance exit**: Decrement count, remove PID from array
- **Last instance exit**: Delete lockfile, kill xcape

## Architecture

### Critical Section Locking

Uses **atomic directory creation** for mutual exclusion:

```lua
vim.loop.fs_mkdir(lockdir, 493)  -- Succeeds only if dir doesn't exist
```

**Lock behavior:**
- Spin-lock with 100 attempts (2 second timeout)
- Stale lock detection: removes locks older than 5 seconds
- Automatic cleanup on section exit

**Why mkdir?** Unlike file operations, directory creation is guaranteed atomic at the OS level.

### State Management

**Idempotency Guard:**
```lua
local deactivation_done = false
```
Prevents double-deactivation from `VimLeavePre` + `VimLeave` events firing on same exit.

**Process Verification:**
```lua
pgrep -x xcape
```
Checks actual system state rather than trusting local variables. Enables self-healing if state desyncs.

### Lifecycle Events

**Activation (VimEnter):**
1. Acquire lock
2. Read lockfile
3. If first instance: spawn keyboard setup
4. If additional: increment count, append PID
5. Release lock

**Deactivation (VimLeave/VimLeavePre):**
1. Check idempotency guard (return if already run)
2. Acquire lock
3. Read lockfile
4. Remove this PID from tracking array
5. Decrement count
6. If count > 0: write updated lockfile
7. If count = 0: delete lockfile, kill xcape
8. Release lock

### Atomic Lockfile Updates

**Write strategy:**
1. Write to temporary file: `/tmp/nvim-devkeys.lock.tmp.{PID}`
2. Atomic rename to actual lockfile
3. Prevents corruption from concurrent writes

## Commands

### `:DevKeysHealth`
Shows current state:
- Lockfile existence
- Reference count
- Tracked PIDs (and whether current instance is tracked)
- xcape process status
- Sync status (lockfile vs actual process)

### `:ToggleDevKeys`
Force reset - tears down and rebuilds keyboard setup regardless of reference count.

### `:DevKeysLog`
Opens debug log (`/tmp/nvim-devkeys.log`) in vertical split.

### `:DevKeysClearLog`
Truncates debug log file.

## Debug Logging

All operations logged to `/tmp/nvim-devkeys.log`:

**Format:**
```
[HH:MM:SS][PID:12345] Message
```

**Logged events:**
- Plugin initialization
- Autocmd triggers (VimEnter, VimLeave, VimLeavePre)
- Lock acquisition/release
- Lockfile read/write operations
- Count changes
- Idempotency guard triggers
- Error conditions

## Edge Cases Handled

### Orphaned xcape
If xcape is running but no lockfile exists:
- Next nvim to start adopts it
- Creates lockfile with count=1

### Stale lockfile
If lockfile claims active but xcape is dead:
- Detected via `pgrep` verification
- Lockfile cleaned up automatically

### Double deactivation
`VimLeave` and `VimLeavePre` both fire on exit:
- First call: processes normally
- Second call: idempotency guard returns early

### Race conditions
Multiple nvim instances starting simultaneously:
- Atomic mkdir prevents concurrent lockfile access
- One instance succeeds, others spin-wait
- Reference counting ensures all instances tracked

### Migration from old format
Handles lockfiles with singular `pid` field:
```lua
if lockdata.pid and not lockdata.pids then
  lockdata.pids = {lockdata.pid}
  lockdata.pid = nil
end
```

## Known Limitations

### Async job spawning
Keyboard setup spawns async jobs - lockfile may be created before xcape fully starts.

### System-wide state
All nvim instances share one xcape process. If xcape crashes externally, state desyncs until next toggle/restart.

### Lock timeout
2-second maximum wait for lock acquisition. If exceeded, operation fails with error notification.

### PID reuse
If a PID gets reused by OS (rare), tracking could become confused. Not currently handled.

## File Locations

- **Lockfile**: `/tmp/nvim-devkeys.lock`
- **Lock directory**: `/tmp/nvim-devkeys.lock.lock`
- **Debug log**: `/tmp/nvim-devkeys.log`
- **Temp files**: `/tmp/nvim-devkeys.lock.tmp.{PID}`
