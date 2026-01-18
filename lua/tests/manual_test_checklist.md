Manual Test Checklist
=====================

Prerequisites
-------------
[ ] In jj repository
[ ] nvim open with test file (e.g., test.c)
[ ] Plugin loaded (:echo exists(':JJMajor'))
[ ] No existing tree state (run :lua require('strato.local_plugin_stubs.jjplugin.state').clear())


Basic Command Tests
-------------------

JJMajor:
[ ] :JJMajor first implementation
    - Should succeed with notification
    - Check: :lua print(vim.inspect(require('strato.local_plugin_stubs.jjplugin.state').get_file_state(vim.fn.expand('%:.'))))
    - Should see major A created

[ ] :JJMajor second implementation
    - Should create major B
    - Check state shows 2 majors

[ ] :JJMajor (no args)
    - Should show error message about usage

JJMinor:
[ ] Start in major A
[ ] :JJMinor optimization attempt
    - Should fail (can't create minor sibling at major level)
    - Error message should be clear

[ ] Create a minor under A first (manually via state)
[ ] Switch to that minor
[ ] :JJMinor alternative approach
    - Should succeed creating A.2 or similar
    - Should switch to new minor

[ ] :JJMinor (no args)
    - Should show usage error

JJFreeze/JJUnfreeze:
[ ] :JJFreeze
    - Should succeed with notification
    - Notification should mention "next edit will create child"

[ ] Edit file (add a line)
[ ] :w
    - Should trigger frozen edit handler
    - Notification about child creation
    - :JJTree should show parent frozen, child created

[ ] :JJUnfreeze
    - Should succeed
    - Should be able to edit without branching

[ ] :JJFreeze on nonexistent tree
    - Should show appropriate error

JJSwitch:
[ ] :JJSwitch A
    - Should switch to major A
    - Notification should confirm switch
    - Buffer should reload

[ ] :JJSwitch A.1
    - Should switch to first minor of A
    - Check buffer content changed

[ ] :JJSwitch INVALID
    - Should show error about path not found

[ ] :JJSwitch (no args)
    - Should show usage error

JJTree:
[ ] :JJTree
    - Should open split window
    - Window title should be "JJ Tree: <filename>"
    - Should show tree structure with:
      * Major nodes
      * Minor nodes (if any)
      * Proper indentation
      * [MAIN] markers on main nodes
      * [FROZEN] markers on frozen nodes
      * → marker on current node

[ ] Close tree window
[ ] :JJTree again
    - Should open fresh

[ ] :JJTree with complex tree (multiple majors, deep nesting)
    - Structure should be readable
    - No visual glitches

JJDrift:
[ ] After some edits without reaching threshold
[ ] :JJDrift
    - Should show drift status
    - Stored drift value
    - Real-time drift value
    - Progress bar
    - Threshold value
    - Percentage

[ ] After exceeding threshold
[ ] :JJDrift before saving
    - Should show warning about threshold exceeded

[ ] After auto-branch
[ ] :JJDrift
    - Should show drift reset to 0

JJCommit:
[ ] :JJCommit end of day checkpoint
    - Should create commit with description
    - Notification should confirm

[ ] :JJCommit (no args)
    - Should create commit with auto timestamp
    - Check description: "Checkpoint YYYY-MM-DD HH:MM"

JJStatus:
[ ] :JJStatus
    - Should show jj status output
    - Should not error

JJLog:
[ ] :JJLog
    - Should show commit history
    - Format: "commit_id | change_id | description"
    - Should be readable

JJEdit:
[ ] Get a change ID from :JJLog
[ ] :JJEdit <change_id>
    - Should switch to that change
    - Notification should confirm

[ ] :JJEdit INVALID
    - Should show jj error

[ ] :JJEdit (no args)
    - Should show usage error

JJDescribe:
[ ] :JJDescribe new description text
    - Should update current commit description
    - Notification should confirm

[ ] :JJDescribe (no args)
    - Should show usage error


Auto-Branch Tests
-----------------

Basic Auto-Branch:
[ ] Create fresh major
[ ] Add exactly 500 lines of code
[ ] :w
    - Should trigger auto-branch
    - Notification about auto-branch
    - Parent should be frozen
    - New child should be current

[ ] :JJTree
    - Verify structure: parent frozen, child created

[ ] Check drift after auto-branch
    - Should be 0

Incremental Drift:
[ ] Create major
[ ] Add 100 lines, :w (drift: 100)
[ ] Add 100 lines, :w (drift: 200)
[ ] Add 100 lines, :w (drift: 300)
[ ] :JJDrift - should show progress bar ~60%
[ ] Add 100 lines, :w (drift: 400)
[ ] Add 100 lines, :w (drift: 500)
    - Should auto-branch

[ ] Verify state persisted across saves

Frozen Node Auto-Branch:
[ ] Create major
[ ] :JJFreeze
[ ] Add 1 line
[ ] :w
    - Should immediately create child (no drift check)
    - Notification about editing frozen node

[ ] :JJTree
    - Parent frozen, child exists


Tree Navigation Tests
---------------------

Simple Tree:
[ ] Create: A → A.1 → A.1.1
[ ] :JJSwitch A
[ ] :JJSwitch A.1
[ ] :JJSwitch A.1.1
[ ] Verify buffer changes with each switch
[ ] :JJTree after each switch
    - → marker should move

Complex Tree:
[ ] Create structure:
    A
    ├── A.1
    │   ├── A.1.1
    │   └── A.1.2
    └── A.2
    B
    └── B.1

[ ] Navigate to each node
[ ] :JJTree at each node
    - Verify → marker correct

[ ] Switch between majors (A ↔ B)
    - Verify works correctly

Deep Nesting:
[ ] Create 5+ levels deep
[ ] Navigate to deepest node
[ ] :JJTree
    - Verify indentation readable
    - No visual issues

[ ] Switch back to root
[ ] Navigate back to deep node
    - Should work


Main Path Tests
---------------

[ ] Create majors A, B, C
[ ] All default to is_main = true
[ ] :JJSwitch B
[ ] Verify B is main
    - :JJTree should show [MAIN] on B

[ ] Create minors under A
[ ] Set A.2 as main (via lua state.set_main)
[ ] :JJTree
    - Only A.2 should have [MAIN] at that level


Persistence Tests
-----------------

[ ] Create complex tree
[ ] :JJTree (note structure)
[ ] Exit nvim
[ ] Check .jj-tree-metadata.json exists
[ ] cat .jj-tree-metadata.json | jq
    - Should be valid JSON
    - Should have files key
    - Should have your test file

[ ] Reopen nvim
[ ] :JJTree
    - Structure should match exactly
    - Current node preserved
    - Drift values preserved
    - Frozen states preserved


Multiple Files Test
-------------------

[ ] Open test1.c
[ ] :JJMajor test1 major
[ ] Create structure for test1

[ ] :e test2.c
[ ] :JJMajor test2 major
[ ] Create structure for test2

[ ] :JJTree in test1.c
    - Should show test1 tree only

[ ] :JJTree in test2.c
    - Should show test2 tree only

[ ] Switch between files
    - Trees should be independent
    - State should not mix


Error Handling Tests
--------------------

[ ] Run commands without tree initialized
    - Should show appropriate errors

[ ] Run commands on non-file buffers (e.g., :h help)
    - Should handle gracefully

[ ] Run commands outside jj repo
    - Should show repo-related errors

[ ] Create major
[ ] Manually corrupt .jj-tree-metadata.json
[ ] Restart nvim
    - Should handle corruption gracefully

[ ] Try to switch to currently active node
    - Should handle without error


UI/Visual Tests
---------------

JJTree visual elements:
[ ] Colors:
    - [MAIN] should be green
    - [FROZEN] should be red
    - → should be yellow/bold
    - (drift: N) should be blue

[ ] Tree structure:
    - Lines connect correctly (├── and └──)
    - Indentation consistent
    - No visual glitches with deep nesting

[ ] Window behavior:
    - Opens in split
    - Can close with :q
    - Can reopen
    - Doesn't interfere with main buffer

JJDrift visual elements:
[ ] Progress bar renders correctly
[ ] Bar characters (█ and ░) visible
[ ] Percentage calculation correct
[ ] Warning message when threshold exceeded


Performance Tests
-----------------

[ ] Create tree with 50+ nodes
    - :JJTree should be fast (<1 second)
    - No lag

[ ] File with 10,000 lines
    - Auto-branch drift calculation should be reasonable
    - :w should not hang

[ ] Rapid saves (press :w 10 times quickly)
    - Debouncing should prevent issues
    - Only processes once per second


Edge Cases
----------

[ ] Create major with very long description (100+ chars)
    - Should handle gracefully

[ ] Create 26+ majors (more than A-Z)
    - Should handle (or error gracefully)

[ ] Create 100+ minors under one parent
    - Should work
    - :JJTree should handle display

[ ] Switch nodes rapidly
    - Should not crash or corrupt state

[ ] Auto-branch exactly at threshold (500)
    - Should trigger

[ ] Auto-branch at 499 lines
    - Should NOT trigger

[ ] Edit frozen node multiple times
    - Should create multiple children


Integration with jj
--------------------

[ ] Compare :JJLog output with `jj log` in terminal
    - Should match (ignoring formatting)

[ ] Create branches via plugin, check in terminal
    - `jj log` should show commits

[ ] Check file content after switches
    - Should match jj's working copy

[ ] Metadata file should be gitignored
    - Or committed (project decision)


Documentation Tests
-------------------

[ ] All commands have descriptions
    - :JJMajor <Tab> should show description

[ ] Error messages are helpful
    - Not just generic failures

[ ] Notifications are informative
    - Success/failure clear


Final Validation
----------------

[ ] Run automated test suite
    - tests/unit_tests.lua
    - tests/integration_tests.lua
    - tests/auto_branch_test.lua

[ ] All automated tests pass

[ ] Create real project tree
[ ] Work normally for 30 minutes
    - No crashes
    - Auto-branch works naturally
    - Navigation feels smooth
    - Tree visualization useful

[ ] Complex workflow:
    - Create 3 majors
    - Work on each in parallel
    - Auto-branch triggers naturally
    - Switch between them
    - Freeze and unfreeze
    - All state preserved
    - No confusion about current state


Sign-off
--------

Tester: ________________
Date: __________________
Issues Found: __________
Overall Status: [ ] Pass [ ] Fail

Notes:
