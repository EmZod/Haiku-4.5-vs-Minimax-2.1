def fizzbuzz(n):
    """
    Implements the classic FizzBuzz algorithm.
    
    Args:
        n: An integer representing the upper limit (inclusive)
    
    Returns:
        A list of strings where:
        - Numbers divisible by both 3 and 5 become "FizzBuzz"
        - Numbers divisible by only 3 become "Fizz"
        - Numbers divisible by only 5 become "Buzz"
        - Other numbers are converted to strings
    """
    result = []
    for i in range(1, n + 1):
        if i % 3 == 0 and i % 5 == 0:
            result.append("FizzBuzz")
        elif i % 3 == 0:
            result.append("Fizz")
        elif i % 5 == 0:
            result.append("Buzz")
        else:
            result.append(str(i))
    return result


if __name__ == "__main__":
    print(fizzbuzz(15))
