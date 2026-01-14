def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    """
    Merge overlapping intervals.
    
    Args:
        intervals: List of [start, end] pairs
    
    Returns:
        List of merged [start, end] pairs, sorted by start
    """
    # Edge case: empty input
    if not intervals:
        return []
    
    # Sort intervals by start time
    sorted_intervals = sorted(intervals, key=lambda x: x[0])
    
    # Initialize merged list with the first interval
    merged = [sorted_intervals[0]]
    
    # Iterate through remaining intervals
    for current in sorted_intervals[1:]:
        last_merged = merged[-1]
        
        # If current interval overlaps or is adjacent to the last merged interval
        if current[0] <= last_merged[1]:
            # Merge by extending the end of the last interval
            last_merged[1] = max(last_merged[1], current[1])
        else:
            # No overlap, add current interval to merged list
            merged.append(current)
    
    return merged


# Test cases
if __name__ == "__main__":
    test_cases = [
        ([], []),
        ([[1,3]], [[1,3]]),
        ([[1,3],[2,6],[8,10],[15,18]], [[1,6],[8,10],[15,18]]),
        ([[1,4],[4,5]], [[1,5]]),
        ([[1,4],[0,4]], [[0,4]]),
        ([[1,4],[2,3]], [[1,4]]),
        ([[2,3],[4,5],[6,7],[8,9],[1,10]], [[1,10]]),
        ([[1,4],[0,2],[3,5]], [[0,5]]),
    ]
    
    all_passed = True
    for i, (input_val, expected) in enumerate(test_cases):
        result = merge_intervals(input_val)
        passed = result == expected
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"Test {i+1}: {status}")
        if not passed:
            print(f"  Input:    {input_val}")
            print(f"  Expected: {expected}")
            print(f"  Got:      {result}")
    
    print(f"\nAll tests passed: {all_passed}")
