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

print("Running test cases...")
all_passed = True

for input_str, expected in test_cases:
    result = longest_unique_substring(input_str)
    passed = result == expected
    status = "✓ PASS" if passed else "✗ FAIL"
    print(f"{status}: longest_unique_substring('{input_str}') = {result} (expected {expected})")
    if not passed:
        all_passed = False

print("\n" + ("=" * 50))
if all_passed:
    print("✓ All test cases passed!")
else:
    print("✗ Some test cases failed!")
