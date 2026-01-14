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
    intervals.sort(key=lambda x: x[0])
    
    # Initialize merged list with first interval
    merged = [intervals[0]]
    
    # Iterate through remaining intervals
    for current in intervals[1:]:
        last_merged = merged[-1]
        
        # If current interval overlaps or touches the last merged interval
        if current[0] <= last_merged[1]:
            # Merge by updating the end of the last merged interval
            last_merged[1] = max(last_merged[1], current[1])
        else:
            # No overlap, add current interval as new merged interval
            merged.append(current)
    
    return merged
