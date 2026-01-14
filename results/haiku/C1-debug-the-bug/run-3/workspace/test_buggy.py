from buggy import longest_unique_substring

# Test cases from the requirements
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
    passed = result == expected
    all_passed = all_passed and passed
    status = "✓ PASS" if passed else "✗ FAIL"
    print(f"{status}: longest_unique_substring({repr(input_str)}) = {result} (expected {expected})")

print()
if all_passed:
    print("All tests passed!")
else:
    print("Some tests failed!")
