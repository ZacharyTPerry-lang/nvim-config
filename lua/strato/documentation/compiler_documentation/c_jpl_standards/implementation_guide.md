# Practical JPL C Standard Implementation Guide

This guide provides practical examples and patterns to help implement JPL C Coding Standard compliance using our clangd configuration.

## Setting Up a New Project

### Directory Structure

A well-organized structure helps with compliance:

```
project/
├── .clangd                     # JPL compliance configuration
├── .clang-tidy                 # Optional additional static analysis rules
├── include/                    # Public headers
│   └── project_name/
│       ├── module1.h
│       └── types.h             # Centralized typedefs (Rule 17)
├── src/                        # Implementation files
│   ├── module1.c
│   └── main.c
├── test/                       # Test code
└── tools/                      # Compliance verification tools
    └── check_compliance.sh     # Script to verify JPL compliance
```

### Centralized Type Definitions (Rule 17)

Create a single types.h file:

```c
/* types.h - Centralized type definitions per Rule 17 */
#ifndef PROJECT_TYPES_H
#define PROJECT_TYPES_H

/* JPL Rule 17: Use typedefs that indicate size and signedness */
typedef signed char         I8;
typedef unsigned char       U8;
typedef signed short        I16;
typedef unsigned short      U16;
typedef signed int          I32;
typedef unsigned int        U32;
typedef signed long long    I64;
typedef unsigned long long  U64;
typedef float               F32;
typedef double              F64;

/* Size-specific boolean type */
typedef U8                  BOOL;
#define TRUE                1U
#define FALSE               0U

/* Status type for error handling */
typedef enum {
    STATUS_SUCCESS = 0,
    STATUS_INVALID_ARGUMENT,
    STATUS_OUT_OF_RANGE,
    STATUS_NULL_POINTER,
    STATUS_OVERFLOW,
    STATUS_INITIALIZATION_ERROR,
    STATUS_RUNTIME_ERROR
} StatusCode;

#endif /* PROJECT_TYPES_H */
```

## Code Patterns for JPL Compliance

### Loop Bounds Enforcement (Rule 3)

```c
/* JPL Rule 3: All loops must have verifiable upper bounds */

/* Pattern 1: Standard for-loop with static counter */
for (U32 i = 0; i < FIXED_SIZE; i++) {
    /* Loop body */
}

/* Pattern 2: While loop with explicit max iterations */
U32 count = 0;
const U32 MAX_ITERATIONS = 1000;
while (condition && count < MAX_ITERATIONS) {
    /* Loop body */
    count++;
}

/* Pattern 3: Processing linked list with bounded iterations */
U32 nodes_visited = 0;
const U32 MAX_NODES = 100;
Node* current = head;
while (current != NULL && nodes_visited < MAX_NODES) {
    /* Process node */
    current = current->next;
    nodes_visited++;
}

/* Pattern 4: Labeled non-terminating task loop */
/* @non-terminating@ */
while (1) {
    StatusCode status = receive_and_process_message();
    if (status != STATUS_SUCCESS) {
        log_error("Message processing error", status);
    }
}
```

### Dynamic Memory Management (Rule 5)

```c
/* JPL Rule 5: No dynamic memory after initialization */

/* Pattern: Pre-allocate all memory during initialization */
typedef struct {
    U32 count;
    Message messages[MAX_MESSAGES];
    BOOL slots_used[MAX_MESSAGES];
} MessagePool;

/* Global memory pools initialized at startup */
static MessagePool g_message_pool;
static U8 g_data_buffer[MAX_DATA_SIZE];

/* Initialize memory pools */
StatusCode initialize_memory(void) {
    for (U32 i = 0; i < MAX_MESSAGES; i++) {
        g_message_pool.slots_used[i] = FALSE;
    }
    g_message_pool.count = 0;

    /* Initialize other memory pools */

    return STATUS_SUCCESS;
}

/* Allocation from pool instead of malloc */
Message* allocate_message(void) {
    if (g_message_pool.count >= MAX_MESSAGES) {
        return NULL;
    }

    for (U32 i = 0; i < MAX_MESSAGES; i++) {
        if (!g_message_pool.slots_used[i]) {
            g_message_pool.slots_used[i] = TRUE;
            g_message_pool.count++;
            return &g_message_pool.messages[i];
        }
    }

    return NULL;
}

/* Return to pool instead of free */
void release_message(Message* msg) {
    if (msg == NULL) {
        return;
    }

    U32 index = ((U32)(msg - g_message_pool.messages)) / sizeof(Message);
    if (index < MAX_MESSAGES && g_message_pool.slots_used[index]) {
        g_message_pool.slots_used[index] = FALSE;
        g_message_pool.count--;
    }
}
```

### Assertions Framework (Rule 16)

```c
/* JPL Rule 16: Use assertions for sanity checks */

/* assertions.h */
#ifndef ASSERTIONS_H
#define ASSERTIONS_H

#include "types.h"
#include <stdio.h>

/* Runtime assertion with error reporting and recovery */
#define ASSERT(condition, error_code) \
    ((condition) ? STATUS_SUCCESS : \
        (log_assertion_failure(__FILE__, __LINE__, #condition), (error_code)))

/* Verify function parameters */
#define VERIFY_NOT_NULL(ptr) \
    if ((ptr) == NULL) { \
        log_error("Null pointer", __FILE__, __LINE__); \
        return STATUS_NULL_POINTER; \
    }

#define VERIFY_RANGE(value, min, max) \
    if ((value) < (min) || (value) > (max)) { \
        log_error("Value out of range", __FILE__, __LINE__); \
        return STATUS_OUT_OF_RANGE; \
    }

/* Static assertion (compile-time) */
#define STATIC_ASSERT(condition, message) \
    typedef char static_assertion_##message[(condition) ? 1 : -1]

/* Log assertion failure */
void log_assertion_failure(const char* file, int line, const char* condition);

/* Log error with context */
void log_error(const char* message, const char* file, int line);

#endif /* ASSERTIONS_H */
```

### Parameter Validation (Rule 15)

```c
/* JPL Rule 15: Check validity of function parameters */

/* Example public function with complete parameter validation */
StatusCode process_data(const U8* data, U32 data_size, U32 flags) {
    /* Start with parameter validation */
    VERIFY_NOT_NULL(data);
    VERIFY_RANGE(data_size, MIN_DATA_SIZE, MAX_DATA_SIZE);

    /* Validate flags - only certain bits should be set */
    if ((flags & ~VALID_FLAGS_MASK) != 0) {
        log_error("Invalid flags", __FILE__, __LINE__);
        return STATUS_INVALID_ARGUMENT;
    }

    /* Now process with validated inputs */
    StatusCode status = internal_process_data(data, data_size, flags);

    /* Check return values from called functions (Rule 14) */
    if (status != STATUS_SUCCESS) {
        log_error("Processing failed", __FILE__, __LINE__);
        return status;
    }

    return STATUS_SUCCESS;
}
```

### Memory Protection (Rule 10)

```c
/* JPL Rule 10: Memory protection with safety margins and barriers */

/* Structure with barrier protection */
typedef struct {
    U32 barrier_begin;    /* Barrier pattern before data */
    U8 data[DATA_SIZE];   /* Actual data */
    U32 barrier_end;      /* Barrier pattern after data */
} ProtectedBuffer;

/* Initialize protected buffer */
void init_protected_buffer(ProtectedBuffer* buffer) {
    VERIFY_NOT_NULL(buffer);

    /* Set barrier patterns */
    buffer->barrier_begin = BARRIER_PATTERN;
    buffer->barrier_end = BARRIER_PATTERN;

    /* Initialize data to known state */
    for (U32 i = 0; i < DATA_SIZE; i++) {
        buffer->data[i] = 0;
    }
}

/* Verify buffer integrity */
BOOL verify_buffer_integrity(const ProtectedBuffer* buffer) {
    if (buffer == NULL) {
        return FALSE;
    }

    if (buffer->barrier_begin != BARRIER_PATTERN ||
        buffer->barrier_end != BARRIER_PATTERN) {
        log_error("Memory corruption detected", __FILE__, __LINE__);
        return FALSE;
    }

    return TRUE;
}
```

### Stack Safety Monitoring

```c
/* Stack safety monitoring helper */

/* Define stack margin size (in bytes) */
#define STACK_MARGIN_SIZE 128

/* Stack margin pattern */
static const U8 STACK_PATTERN = 0xA5;

/* Stack margin for each task */
typedef struct {
    U8 margin[STACK_MARGIN_SIZE];
} StackMargin;

/* Task stack margins */
static StackMargin g_task_margins[NUM_TASKS];

/* Initialize all task stack margins */
void init_stack_margins(void) {
    for (U32 task_id = 0; task_id < NUM_TASKS; task_id++) {
        for (U32 i = 0; i < STACK_MARGIN_SIZE; i++) {
            g_task_margins[task_id].margin[i] = STACK_PATTERN;
        }
    }
}

/* Check for stack overflows */
void check_stack_margins(void) {
    for (U32 task_id = 0; task_id < NUM_TASKS; task_id++) {
        for (U32 i = 0; i < STACK_MARGIN_SIZE; i++) {
            if (g_task_margins[task_id].margin[i] != STACK_PATTERN) {
                log_critical_error("Stack overflow detected for task", task_id);
                /* Handle error according to system requirements */
                break;
            }
        }
    }
}
```

## Practical CI Integration

Add this to your CI pipeline to enforce JPL compliance:

```yaml
# .github/workflows/jpl-compliance.yml
name: JPL C Standard Compliance

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2

    - name: Install tools
      run: |
        sudo apt-get update
        sudo apt-get install -y clang-tools clang-tidy cppcheck

    - name: Check compilation warnings
      run: |
        clang -std=c99 -pedantic -Wall -Wextra -Werror -fsyntax-only src/*.c

    - name: Run clang-tidy
      run: |
        clang-tidy src/*.c -- -std=c99

    - name: Run cppcheck
      run: |
        cppcheck --enable=all --std=c99 --suppress=missingIncludeSystem src/

    - name: Check for banned functions
      run: |
        ! grep -r --include="*.c" --include="*.h" "malloc\|calloc\|realloc\|goto\|setjmp\|longjmp" src/
```

## Compliance Verification Checklist

Create a file `COMPLIANCE.md` in your repository:

```markdown
# JPL Compliance Verification

## LOC-1: Language Compliance
- [ ] All code compiles with no warnings using -std=c99 -pedantic -Wall -Wextra
- [ ] No undefined or unspecified behavior is relied upon
- [ ] No #pragma directives are used

## LOC-2: Predictable Execution
- [ ] All loops have statically verifiable upper bounds
- [ ] No direct or indirect recursion
- [ ] No dynamic memory allocation after initialization
- [ ] IPC mechanism used for all task communication
- [ ] No task delays for synchronization
- [ ] Single owning task for shared data objects
- [ ] No nested use of semaphores or locks
- [ ] Memory protection and barrier patterns implemented
- [ ] No goto, setjmp or longjmp
- [ ] No selective enum initialization

## LOC-3: Defensive Coding
- [ ] All data objects declared at smallest scope
- [ ] All return values of non-void functions are checked
- [ ] All function parameters are validated
- [ ] Assertions used throughout for sanity checks
- [ ] Custom typedefs used for all variable declarations
- [ ] Evaluation order in compound expressions is explicit
- [ ] No side effects in Boolean expressions

## LOC-4: Code Clarity
- [ ] Limited use of preprocessor
- [ ] No macros defined within functions or blocks
- [ ] No #undef directives
- [ ] No preprocessor directives split across files
- [ ] One statement/declaration per line
- [ ] Functions are ≤ 60 lines with ≤ 6 parameters
- [ ] No more than two levels of indirection in declarations
- [ ] No more than two levels of dereferencing in statements
- [ ] No pointer dereference operations in macros/typedefs
- [ ] No non-constant function pointers
- [ ] No function pointer casts
- [ ] Include directives only preceded by preprocessor or comments
```

## Common JPL Violations and Fixes

| Violation | Fix |
|-----------|-----|
| Unbounded while loop | Add explicit iteration counter and maximum |
| Failing to check return value | Add explicit check or cast to (void) |
| malloc/calloc usage | Replace with pre-allocated pools |
| goto statement | Refactor using structured programming techniques |
| Overly complex function | Split into smaller helper functions |
| Pointer to function | Use enumerated strategy pattern instead |
| Deeply nested pointers | Redesign data structures to use arrays and indices |
| Macros with side effects | Replace with inline functions |
| Hidden side effects | Make all state changes explicit |
