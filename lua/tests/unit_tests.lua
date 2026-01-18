-- tests/unit_tests.lua
-- Unit tests for state management
-- Run with :luafile tests/unit_tests.lua

local state = require('strato.local_plugin_stubs.jjplugin.state')

local tests_passed = 0
local tests_failed = 0
local test_results = {}

local function assert_eq(name, expected, actual)
    if vim.deep_equal(expected, actual) then
        tests_passed = tests_passed + 1
        table.insert(test_results, {name = name, status = "PASS"})
        return true
    else
        tests_failed = tests_failed + 1
        table.insert(test_results, {
            name = name,
            status = "FAIL",
            expected = expected,
            actual = actual
        })
        return false
    end
end

local function assert_true(name, condition)
    return assert_eq(name, true, condition)
end

local function assert_false(name, condition)
    return assert_eq(name, false, condition)
end

print("=== State Management Unit Tests ===\n")

-- Setup clean state
state.clear()
state.set_repo("/tmp/test-jj-repo")

local test_file = "test.c"

-- Test 1: Initial state
print("Test Group: Initial State")
assert_false("1.1: File has no tree initially", state.file_has_tree(test_file))
assert_eq("1.2: Current path empty", {}, state.get_current_path(test_file))

-- Test 2: Major creation
print("\nTest Group: Major Creation")
local major_id, major_path = state.add_node(test_file, {}, {
    description = "Test major",
    commit_id = "commit_001",
    is_main = true,
})
assert_eq("2.1: Major ID is A", "A", major_id)
assert_eq("2.2: Major path is {A}", {"A"}, major_path)
assert_true("2.3: File now has tree", state.file_has_tree(test_file))

-- Test 3: Major node properties
print("\nTest Group: Major Node Properties")
state.set_current_node(test_file, major_path)
local node = state.get_current_node(test_file)
assert_eq("3.1: Node ID correct", "A", node.id)
assert_eq("3.2: Node description correct", "Test major", node.description)
assert_true("3.3: Node is main", node.is_main)
assert_false("3.4: Node not frozen", node.frozen)
assert_eq("3.5: Drift is 0", 0, node.drift)

-- Test 4: Minor creation
print("\nTest Group: Minor Creation")
local minor_id, minor_path = state.add_node(test_file, major_path, {
    description = "Test minor",
    commit_id = "commit_002",
    is_main = true,
})
assert_eq("4.1: Minor ID format", "A.1", minor_id)
assert_eq("4.2: Minor path correct", {"A", "A.1"}, minor_path)

-- Test 5: Multiple minors
print("\nTest Group: Multiple Minors")
local minor2_id, minor2_path = state.add_node(test_file, major_path, {
    description = "Second minor",
    commit_id = "commit_003",
})
assert_eq("5.1: Second minor ID", "A.2", minor2_id)
assert_eq("5.2: Second minor path", {"A", "A.2"}, minor2_path)

-- Test 6: Deep nesting
print("\nTest Group: Deep Nesting")
state.set_current_node(test_file, minor_path)
local deep_id, deep_path = state.add_node(test_file, minor_path, {
    description = "Deep node",
    commit_id = "commit_004",
})
assert_eq("6.1: Deep node ID", "A.1.1", deep_id)
assert_eq("6.2: Deep path length", 3, #deep_path)
assert_eq("6.3: Deep path correct", {"A", "A.1", "A.1.1"}, deep_path)

-- Test 7: Node navigation
print("\nTest Group: Node Navigation")
local ok = state.set_current_node(test_file, major_path)
assert_true("7.1: Can switch to major", ok)
assert_eq("7.2: Current path updated", {"A"}, state.get_current_path(test_file))

ok = state.set_current_node(test_file, deep_path)
assert_true("7.3: Can switch to deep node", ok)
assert_eq("7.4: Deep path set", deep_path, state.get_current_path(test_file))

-- Test 8: Invalid navigation
print("\nTest Group: Invalid Navigation")
ok = state.set_current_node(test_file, {"Z", "Z1"})
assert_false("8.1: Cannot switch to nonexistent path", ok)

-- Test 9: Freeze operations
print("\nTest Group: Freeze Operations")
state.set_current_node(test_file, major_path)
assert_false("9.1: Node not frozen initially", state.is_frozen(test_file, major_path))

ok = state.freeze_node(test_file, major_path)
assert_true("9.2: Freeze succeeds", ok)
assert_true("9.3: Node is frozen", state.is_frozen(test_file, major_path))

ok = state.unfreeze_node(test_file, major_path)
assert_true("9.4: Unfreeze succeeds", ok)
assert_false("9.5: Node not frozen after unfreeze", state.is_frozen(test_file, major_path))

-- Test 10: Main designation
print("\nTest Group: Main Designation")
state.set_current_node(test_file, minor2_path)
ok = state.set_main(test_file, minor2_path)
assert_true("10.1: Set main succeeds", ok)

local minor2_node = state.get_current_node(test_file)
assert_true("10.2: Minor2 is now main", minor2_node.is_main)

-- Verify sibling is no longer main
state.set_current_node(test_file, minor_path)
local minor1_node = state.get_current_node(test_file)
assert_false("10.3: Minor1 no longer main", minor1_node.is_main)

-- Test 11: Drift tracking
print("\nTest Group: Drift Tracking")
state.set_current_node(test_file, major_path)
assert_eq("11.1: Initial drift 0", 0, state.get_drift(test_file))

ok = state.update_drift(test_file, 50)
assert_eq("11.2: Drift updated", 50, state.get_drift(test_file))

ok = state.update_drift(test_file, 100)
assert_eq("11.3: Drift accumulated", 150, state.get_drift(test_file))

ok = state.reset_drift(test_file)
assert_eq("11.4: Drift reset", 0, state.get_drift(test_file))

-- Test 12: Anchor tracking
print("\nTest Group: Anchor Tracking")
assert_eq("12.1: Initial anchor nil", nil, state.get_anchor(test_file))

state.set_anchor(test_file, "commit_anchor")
assert_eq("12.2: Anchor set", "commit_anchor", state.get_anchor(test_file))

-- Test 13: Node description updates
print("\nTest Group: Node Updates")
state.set_current_node(test_file, major_path)
ok = state.set_node_description(test_file, major_path, "Updated description")
assert_true("13.1: Description update succeeds", ok)

node = state.get_current_node(test_file)
assert_eq("13.2: Description updated", "Updated description", node.description)

-- Test 14: Node commit updates
print("\nTest Group: Commit Updates")
ok = state.set_node_commit(test_file, major_path, "commit_new")
assert_true("14.1: Commit update succeeds", ok)

node = state.get_current_node(test_file)
assert_eq("14.2: Commit updated", "commit_new", node.main_commit)

-- Test 15: Dependencies
print("\nTest Group: Dependencies")
state.add_dependency(test_file, "helper.c", "stable", "v1")
local deps = state.get_dependencies(test_file)
assert_true("15.1: Dependency added", deps["helper.c"] ~= nil)
assert_eq("15.2: Dep major correct", "stable", deps["helper.c"].major)

state.remove_dependency(test_file, "helper.c")
deps = state.get_dependencies(test_file)
assert_eq("15.3: Dependency removed", nil, deps["helper.c"])

-- Test 16: Tree walking
print("\nTest Group: Tree Walking")
local nodes = state.walk_tree(test_file)
assert_true("16.1: Walk returns nodes", #nodes > 0)
assert_true("16.2: Walk includes major", nodes[1].id == "A")

-- Test 17: Multiple majors
print("\nTest Group: Multiple Majors")
local major_b_id, major_b_path = state.add_node(test_file, {}, {
    description = "Major B",
    commit_id = "commit_b",
})
assert_eq("17.1: Second major ID is B", "B", major_b_id)
assert_eq("17.2: Major B path", {"B"}, major_b_path)

local majors = state.get_majors(test_file)
assert_eq("17.3: Two majors exist", 2, #majors)

-- Test 18: Persistence
print("\nTest Group: Persistence")
ok = state.persist()
assert_true("18.1: Persist succeeds", ok)

-- Clear and reload
state.clear()
assert_false("18.2: State cleared", state.file_has_tree(test_file))

ok = state.load()
assert_true("18.3: Load succeeds", ok)
assert_true("18.4: Tree restored after load", state.file_has_tree(test_file))

-- Verify data integrity after reload
local restored_path = state.get_current_path(test_file)
assert_eq("18.5: Current path preserved", 3, #restored_path)

-- Test 19: Multiple files
print("\nTest Group: Multiple Files")
local file2 = "parser.c"
local f2_major_id = state.add_node(file2, {}, {
    description = "Parser major",
    commit_id = "commit_parser",
})
assert_eq("19.1: Second file gets own major A", "A", f2_major_id)
assert_true("19.2: Both files have trees",
    state.file_has_tree(test_file) and state.file_has_tree(file2))

-- Test 20: Close node
print("\nTest Group: Close Node")
state.set_current_node(test_file, minor2_path)
ok = state.close_node(test_file, minor2_path)
assert_true("20.1: Close succeeds", ok)

local closed_node = state.get_current_node(test_file)
assert_true("20.2: Node marked closed", closed_node.closed)

-- Print results
print("\n=== Test Results ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print(string.format("Total: %d", tests_passed + tests_failed))

if tests_failed > 0 then
    print("\n=== Failed Tests ===")
    for _, result in ipairs(test_results) do
        if result.status == "FAIL" then
            print(string.format("\n%s:", result.name))
            print("  Expected:", vim.inspect(result.expected))
            print("  Actual:", vim.inspect(result.actual))
        end
    end
end

print("\n=== Summary ===")
if tests_failed == 0 then
    print("✓ All tests passed!")
    return true
else
    print("✗ Some tests failed")
    return false
end
