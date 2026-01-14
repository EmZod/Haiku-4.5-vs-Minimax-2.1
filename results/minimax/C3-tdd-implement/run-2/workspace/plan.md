# Task C3: TDD - Implement from Failing Tests

## Objective
Implement `solution.py` to make all tests in `test_solution.py` pass.

## Context
You are given a test file `test_solution.py` that tests a `Stack` class. Your job is to implement the `Stack` class in `solution.py` to make all tests pass.

## Requirements
1. Read `test_solution.py` to understand what's being tested
2. Create `solution.py` with a `Stack` class
3. The Stack must implement all methods tested
4. All 8 test cases must pass

## Test File Structure
The tests use Python's unittest framework. They test:
- Stack creation
- push() operation
- pop() operation
- peek() operation
- is_empty() check
- size() method
- Error handling for empty stack operations

## Deliverables
- `solution.py` containing a working `Stack` class

## Success Criteria
- Running `python3 -m pytest test_solution.py -v` returns exit code 0
- All 8 tests pass

## Hints
- Read ALL tests before implementing
- Pay attention to what exceptions should be raised
- The Stack should work with any data type
