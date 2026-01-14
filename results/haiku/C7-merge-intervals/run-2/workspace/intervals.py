def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    """
    Merge overlapping intervals.
    
    Args:
        intervals: List of [start, end] pairs
    
    Returns:
        List of merged [start, end] pairs, sorted by start
    """
    # Handle empty input
    if not intervals:
        return []
    
    # Sort intervals by start value
    sorted_intervals = sorted(intervals, key=lambda x: x[0])
    
    # Initialize merged list with first interval
    merged = [sorted_intervals[0]]
    
    # Iterate through remaining intervals
    for current in sorted_intervals[1:]:
        last_merged = merged[-1]
        
        # Check if current interval overlaps or is adjacent to the last merged interval
        # Overlapping/adjacent means: current_start <= last_end
        if current[0] <= last_merged[1]:
            # Merge by extending the end of the last merged interval
            last_merged[1] = max(last_merged[1], current[1])
        else:
            # No overlap, add current interval to merged list
            merged.append(current)
    
    return merged
