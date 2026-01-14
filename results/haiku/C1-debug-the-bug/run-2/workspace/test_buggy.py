from buggy import longest_unique_substring

# Test cases
test_cases = [
    ("", 0),
    ("a", 1),
    ("abcabcbb", 3),
    ("bbbbb", 1),
    ("pwwkew", 3),
    ("abba", 2),
]

print("Running tests...")
all_passed = True

for input_str, expected in test_cases:
    result = longest_unique_substring(input_str)
    status = "✓" if result == expected else "✗"
    if result != expected:
        all_passed = False
    print(f"{status} longest_unique_substring('{input_str}') = {result} (expected {expected})")

print("\n" + ("All tests passed!" if all_passed else "Some tests failed!"))
