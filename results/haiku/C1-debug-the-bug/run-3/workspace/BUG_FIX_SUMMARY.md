# Bug Fix Summary - Task C1

## Bug Found
The bug was in the sliding window implementation in `buggy.py`, specifically in how the window start position was updated when encountering a repeated character.

### Location
Line 18 in `buggy.py`:
```python
window_start = char_index[char] + 1
```

## The Problem
When a repeated character is encountered, the code moves the window start position to after the previous occurrence of that character. However, the original implementation doesn't prevent the window from moving backwards.

### Example: "abba"
With the buggy code:
- At index 3 (second 'a'), `char_index['a'] = 0`
- The code sets `window_start = 0 + 1 = 1`
- But window_start was already at 2 (from processing the second 'b')
- This moves the window backwards, including the already-removed duplicate 'b'
- Result: Incorrectly returns 3 instead of 2

## The Fix
Use `max()` to ensure the window never moves backwards:
```python
window_start = max(window_start, char_index[char] + 1)
```

This ensures:
1. We only move the window forward
2. We skip duplicates that appeared before the current window
3. The sliding window algorithm works correctly

## Test Results
All test cases now pass:
- `longest_unique_substring("")` → `0` ✓
- `longest_unique_substring("a")` → `1` ✓
- `longest_unique_substring("abcabcbb")` → `3` ✓
- `longest_unique_substring("bbbbb")` → `1` ✓
- `longest_unique_substring("pwwkew")` → `3` ✓
- `longest_unique_substring("abba")` → `2` ✓

## Changes Made
- **File Modified**: `buggy.py`
- **Lines Changed**: 1 line (minimal surgical fix)
- **Algorithm**: Unchanged, only bug fix applied
