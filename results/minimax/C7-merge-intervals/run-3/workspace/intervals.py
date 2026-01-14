def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    """
    Merge overlapping intervals.
    
    Args:
        intervals: List of [start, end] pairs
    
    Returns:
        List of merged [start, end] pairs, sorted by start
    """
    if not intervals:
        return []
    
    # Sort intervals by start time
    intervals = sorted(intervals, key=lambda x: x[0])
    
    merged = [intervals[0]]
    
    for current in intervals[1:]:
        last = merged[-1]
        # Check if current interval overlaps or is adjacent to last merged
        # Overlap/adjacent if current start <= last end
        if current[0] <= last[1]:
            # Merge by extending the end
            last[1] = max(last[1], current[1])
        else:
            # No overlap, add as new interval
            merged.append(current)
    
    return merged
