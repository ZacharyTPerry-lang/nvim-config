-- tests/integration_tests.lua
-- Integration tests for command workflows
-- REQUIRES: jj repo setup, run from nvim in jj repo
-- Run with :luafile tests/integration_tests.lua

local state = require('strato.local_plugin_stubs.jjplugin.state')
local diff = require('strato.local_plugin_stubs.jjplugin.diff')
local core = require('strato.local_plugin_stubs.jjplugin.core')
local auto_branch = require('strato.local_plugin_stubs.jjplugin.auto_branch')

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
    print(string.format("\nTest: %s", name))
    local ok, err = pcall(fn)
    if ok then
        tests_passed = tests_passed + 1
        print("  ✓ PASS")
        return true
    else
        tests_failed = tests_failed + 1
        print("  ✗ FAIL: " .. tostring(err))
        return false
    end
end

local function assert(condition, msg)
    if not condition then
        error(msg or "Assertion failed")
    end
end

print("=== Integration Tests ===")
print("Prerequisites: In jj repo, buffer open\n")

-- Verify prerequisites
if not state.in_repo() then
    print("ERROR: Not in jj repo. Run from jj repository.")
    return
end

local test_file = vim.fn.expand('%:.')
if test_file == "" then
    print("ERROR: No file in buffer")
    return
end

print("Test file:", test_file)

-- Clean slate
state.clear()
print("State cleared\n")

-- Test 1: Initial major creation
test("Create initial major", function()
    local commit_id = diff.get_current_commit()
    assert(commit_id, "No current commit")

    local major_id, major_path = state.add_node(test_file, {}, {
        description = "integration test major",
        commit_id = commit_id,
        is_main = true,
    })

    assert(major_id == "A", "Expected major ID 'A', got " .. tostring(major_id))
    assert(#major_path == 1, "Expected path length 1")

    state.set_current_node(test_file, major_path)
    state.set_anchor(test_file, commit_id)
end)

-- Test 2: Drift calculation
test("Calculate drift from jj diff", function()
    -- Create some changes
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"// Test line 1", "// Test line 2"})
    vim.cmd('write')

    vim.cmd('sleep 100m')  -- Wait for write

    local drift = diff.get_drift_from_anchor(test_file)
    assert(drift >= 0, "Drift should be non-negative, got " .. tostring(drift))
end)

-- Test 3: Manual drift update
test("Update drift counter", function()
    local ok, new_drift = state.update_drift(test_file, 50)
    assert(ok, "Failed to update drift")

    local drift = state.get_drift(test_file)
    assert(drift >= 50, "Drift should be at least 50, got " .. tostring(drift))
end)

-- Test 4: Frozen node behavior
test("Frozen node creates child on edit", function()
    local current_path = state.get_current_path(test_file)

    -- Freeze current node
    local ok = state.freeze_node(test_file, current_path)
    assert(ok, "Failed to freeze node")
    assert(state.is_frozen(test_file, current_path), "Node should be frozen")

    -- Simulate editing frozen node
    ok = auto_branch.handle_frozen_edit(test_file)
    assert(ok, "Failed to handle frozen edit")

    -- Check child was created
    local new_path = state.get_current_path(test_file)
    assert(#new_path > #current_path, "Child should have been created")
end)

-- Test 5: Manual minor creation
test("Create minor sibling", function()
    local current_path = state.get_current_path(test_file)
    local parent_path = vim.list_slice(current_path, 1, #current_path - 1)

    local commit_id = diff.get_current_commit()
    local minor_id, minor_path = state.add_node(test_file, parent_path, {
        description = "test minor sibling",
        commit_id = commit_id,
    })

    assert(minor_id, "Failed to create minor")
    assert(#minor_path == #current_path, "Sibling should be at same depth")
end)

-- Test 6: Switch between nodes
test("Switch to different node", function()
    -- Get all nodes
    local file_state = state.get_file_state(test_file)
    local major_path = {"A"}

    local ok = state.set_current_node(test_file, major_path)
    assert(ok, "Failed to switch to major")

    local current = state.get_current_path(test_file)
    assert(vim.deep_equal(current, major_path), "Current path should match major")
end)

-- Test 7: Tree walking
test("Walk entire tree structure", function()
    local nodes = state.walk_tree(test_file)
    assert(#nodes > 0, "Should have at least one node")

    -- Verify structure
    local has_major = false
    local has_minor = false
    for _, node in ipairs(nodes) do
        if #node.path == 1 then
            has_major = true
        elseif #node.path > 1 then
            has_minor = true
        end
    end

    assert(has_major, "Should have at least one major")
    assert(has_minor, "Should have at least one minor")
end)

-- Test 8: Multiple majors
test("Create second major", function()
    local commit_id = diff.get_current_commit()
    local major_id, major_path = state.add_node(test_file, {}, {
        description = "second major",
        commit_id = commit_id,
    })

    assert(major_id == "B", "Expected major ID 'B', got " .. tostring(major_id))

    local majors = state.get_majors(test_file)
    assert(#majors >= 2, "Should have at least 2 majors")
end)

-- Test 9: Main designation
test("Set node as main", function()
    local current_path = state.get_current_path(test_file)
    local ok = state.set_main(test_file, current_path)
    assert(ok, "Failed to set main")

    local node = state.get_current_node(test_file)
    assert(node.is_main, "Node should be marked as main")
end)

-- Test 10: Persistence roundtrip
test("Persist and load state", function()
    local original_path = state.get_current_path(test_file)
    local original_drift = state.get_drift(test_file)

    -- Persist
    local ok = state.persist()
    assert(ok, "Failed to persist")

    -- Clear
    state.clear()
    assert(not state.file_has_tree(test_file), "State should be cleared")

    -- Load
    ok = state.load()
    assert(ok, "Failed to load")
    assert(state.file_has_tree(test_file), "Tree should be restored")

    -- Verify data
    local restored_path = state.get_current_path(test_file)
    local restored_drift = state.get_drift(test_file)

    assert(#restored_path == #original_path, "Path length should match")
    assert(restored_drift == original_drift, "Drift should match")
end)

-- Test 11: Node description update
test("Update node description", function()
    local current_path = state.get_current_path(test_file)
    local new_desc = "updated description " .. os.time()

    local ok = state.set_node_description(test_file, current_path, new_desc)
    assert(ok, "Failed to update description")

    local node = state.get_current_node(test_file)
    assert(node.description == new_desc, "Description should be updated")
end)

-- Test 12: jj command execution
test("Execute jj status", function()
    local result = core.execute({'status'})
    assert(result.success, "jj status failed: " .. tostring(result.stderr))
    assert(result.stdout, "Should have stdout")
end)

-- Test 13: Get current change ID
test("Get current change ID", function()
    local change_id = diff.get_current_change_id()
    assert(change_id, "Should have change ID")
    assert(#change_id > 0, "Change ID should not be empty")
end)

-- Test 14: Dependencies
test("Add and remove dependencies", function()
    state.add_dependency(test_file, "helper.c", "stable", nil)
    local deps = state.get_dependencies(test_file)
    assert(deps["helper.c"], "Dependency should exist")

    state.remove_dependency(test_file, "helper.c")
    deps = state.get_dependencies(test_file)
    assert(not deps["helper.c"], "Dependency should be removed")
end)

-- Test 15: Close node
test("Close node", function()
    local current_path = state.get_current_path(test_file)
    local ok = state.close_node(test_file, current_path)
    assert(ok, "Failed to close node")

    local node = state.get_current_node(test_file)
    assert(node.closed, "Node should be marked closed")
end)

-- Test 16: Config access
test("Get and set config", function()
    local config = state.get_config()
    assert(config.auto_split_threshold, "Config should have threshold")

    state.set_config({auto_split_threshold = 999})
    config = state.get_config()
    assert(config.auto_split_threshold == 999, "Config should be updated")

    -- Restore default
    state.set_config({auto_split_threshold = 500})
end)

-- Test 17: Reset drift
test("Reset drift counter", function()
    state.update_drift(test_file, 100)
    local drift = state.get_drift(test_file)
    assert(drift > 0, "Drift should be positive")

    state.reset_drift(test_file)
    drift = state.get_drift(test_file)
    assert(drift == 0, "Drift should be 0 after reset")
end)

-- Test 18: Unfreeze node
test("Unfreeze frozen node", function()
    local current_path = state.get_current_path(test_file)

    state.freeze_node(test_file, current_path)
    assert(state.is_frozen(test_file, current_path), "Should be frozen")

    state.unfreeze_node(test_file, current_path)
    assert(not state.is_frozen(test_file, current_path), "Should be unfrozen")
end)

-- Test 19: Deep nesting
test("Create deep nested structure", function()
    local current_path = state.get_current_path(test_file)

    -- Create child
    local commit_id = diff.get_current_commit()
    local child_id, child_path = state.add_node(test_file, current_path, {
        description = "deep child",
        commit_id = commit_id,
    })

    assert(#child_path > #current_path, "Child path should be deeper")

    -- Switch to child
    state.set_current_node(test_file, child_path)

    -- Create grandchild
    local grandchild_id, grandchild_path = state.add_node(test_file, child_path, {
        description = "grandchild",
        commit_id = commit_id,
    })

    assert(#grandchild_path > #child_path, "Grandchild should be even deeper")
end)

-- Test 20: Invalid operations
test("Handle invalid operations gracefully", function()
    -- Try to switch to invalid path
    local ok = state.set_current_node(test_file, {"Z", "Z99"})
    assert(not ok, "Should fail to switch to invalid path")

    -- Try to freeze nonexistent node
    ok = state.freeze_node(test_file, {"INVALID"})
    assert(not ok, "Should fail to freeze invalid node")

    -- Try to set main on invalid path
    ok = state.set_main(test_file, {"NOPE"})
    assert(not ok, "Should fail to set main on invalid path")
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print("Integration Test Results")
print(string.rep("=", 50))
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print(string.format("Total:  %d", tests_passed + tests_failed))

if tests_failed == 0 then
    print("\n✓ All integration tests passed!")
else
    print("\n✗ Some integration tests failed")
end

print("\nNote: Some tests modify buffer and create commits.")
print("Review with :JJLog and :JJTree")

return tests_failed == 0
