def longest_unique_substring(s):
    """
    Find the length of the longest substring without repeating characters.
    Uses sliding window approach with a hash map to track character positions.
    """
    if not s:
        return 0
    
    char_index = {}  # Maps character to its most recent index
    max_length = 0
    window_start = 0
    
    for window_end, char in enumerate(s):
        # If we've seen this character before and it's in our current window
        if char in char_index:
            # Move window start to after the previous occurrence
            # BUG: Should use max() to ensure we don't move backward
            window_start = max(window_start, char_index[char] + 1)
        
        # Update the character's most recent position
        char_index[char] = window_end
        
        # Update max length
        current_length = window_end - window_start + 1
        max_length = max(max_length, current_length)
    
    return max_length
