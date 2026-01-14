def fizzbuzz(n):
    """
    Implements the FizzBuzz algorithm.
    
    Args:
        n: An integer representing the upper limit
        
    Returns:
        A list of strings for numbers 1 to n where:
        - Numbers divisible by 3 AND 5 → "FizzBuzz"
        - Numbers divisible by only 3 → "Fizz"
        - Numbers divisible by only 5 → "Buzz"
        - Other numbers → the number as a string
    """
    result = []
    for i in range(1, n + 1):
        if i % 15 == 0:
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
