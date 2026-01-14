# Task C7: Merge Overlapping Intervals

## Objective
Implement `intervals.py` with a function that merges overlapping intervals.

## Problem
Given a collection of intervals, merge all overlapping intervals.

## Function Signature
```python
def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    """
    Merge overlapping intervals.
    
    Args:
        intervals: List of [start, end] pairs
    
    Returns:
        List of merged [start, end] pairs, sorted by start
    """
```

## Examples
```python
merge_intervals([[1,3],[2,6],[8,10],[15,18]])
# Returns: [[1,6],[8,10],[15,18]]
# Explanation: [1,3] and [2,6] overlap, merge to [1,6]

merge_intervals([[1,4],[4,5]])
# Returns: [[1,5]]
# Explanation: [1,4] and [4,5] are adjacent (touching), merge them
```

## Edge Cases to Handle
1. Empty input → return empty list
2. Single interval → return as-is
3. No overlaps → return sorted intervals
4. All intervals overlap → return single merged interval
5. Adjacent intervals (e.g., [1,2] and [2,3]) → merge them
6. Nested intervals (e.g., [1,10] contains [2,5]) → return outer
7. Unsorted input → must sort first

## Test Cases
Your implementation must pass these:
```python
merge_intervals([]) == []
merge_intervals([[1,3]]) == [[1,3]]
merge_intervals([[1,3],[2,6],[8,10],[15,18]]) == [[1,6],[8,10],[15,18]]
merge_intervals([[1,4],[4,5]]) == [[1,5]]
merge_intervals([[1,4],[0,4]]) == [[0,4]]
merge_intervals([[1,4],[2,3]]) == [[1,4]]
merge_intervals([[2,3],[4,5],[6,7],[8,9],[1,10]]) == [[1,10]]
merge_intervals([[1,4],[0,2],[3,5]]) == [[0,5]]
```

## Deliverables
- `intervals.py` with `merge_intervals` function

## Success Criteria
- All 8 test cases pass
- Handles all edge cases correctly
- Returns intervals sorted by start
