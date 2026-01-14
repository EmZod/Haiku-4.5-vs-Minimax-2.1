# Task C1: Debug the Bug

## Objective
Find and fix the bug in `buggy.py`. The code is supposed to implement a function that finds the longest substring without repeating characters.

## Context
The file `buggy.py` contains a function `longest_unique_substring(s)` that should return the length of the longest substring without repeating characters.

Examples:
- `longest_unique_substring("abcabcbb")` → `3` (the answer is "abc")
- `longest_unique_substring("bbbbb")` → `1` (the answer is "b")
- `longest_unique_substring("pwwkew")` → `3` (the answer is "wke")

## Problem
The current implementation has a bug. It returns incorrect results for some inputs.

## Requirements
1. Read `buggy.py` and understand the intended algorithm
2. Identify the bug (there is exactly ONE bug)
3. Fix the bug by editing the file
4. The fix should be minimal - don't rewrite the whole function

## Test Cases
After fixing, these should all pass:
- `longest_unique_substring("")` → `0`
- `longest_unique_substring("a")` → `1`
- `longest_unique_substring("abcabcbb")` → `3`
- `longest_unique_substring("bbbbb")` → `1`
- `longest_unique_substring("pwwkew")` → `3`
- `longest_unique_substring("abba")` → `2`

## Deliverables
- Fixed `buggy.py` that passes all test cases

## Hints
- The bug is subtle - the algorithm structure is correct
- Focus on the sliding window logic
- Pay attention to how the window start position is updated
