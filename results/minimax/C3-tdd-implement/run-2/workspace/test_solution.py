"""
Test suite for Stack implementation.
Your task: Create solution.py with a Stack class that passes all these tests.
"""
import unittest
from solution import Stack


class TestStack(unittest.TestCase):
    
    def test_01_create_empty_stack(self):
        """A new stack should be empty"""
        stack = Stack()
        self.assertTrue(stack.is_empty())
        self.assertEqual(stack.size(), 0)
    
    def test_02_push_single_item(self):
        """Pushing an item should increase size"""
        stack = Stack()
        stack.push(42)
        self.assertFalse(stack.is_empty())
        self.assertEqual(stack.size(), 1)
    
    def test_03_push_multiple_items(self):
        """Pushing multiple items should increase size correctly"""
        stack = Stack()
        stack.push("a")
        stack.push("b")
        stack.push("c")
        self.assertEqual(stack.size(), 3)
    
    def test_04_pop_returns_last_pushed(self):
        """Pop should return items in LIFO order"""
        stack = Stack()
        stack.push(1)
        stack.push(2)
        stack.push(3)
        self.assertEqual(stack.pop(), 3)
        self.assertEqual(stack.pop(), 2)
        self.assertEqual(stack.pop(), 1)
    
    def test_05_pop_decreases_size(self):
        """Pop should decrease the size"""
        stack = Stack()
        stack.push("x")
        stack.push("y")
        self.assertEqual(stack.size(), 2)
        stack.pop()
        self.assertEqual(stack.size(), 1)
        stack.pop()
        self.assertEqual(stack.size(), 0)
        self.assertTrue(stack.is_empty())
    
    def test_06_peek_returns_top_without_removing(self):
        """Peek should return top item without removing it"""
        stack = Stack()
        stack.push(100)
        stack.push(200)
        self.assertEqual(stack.peek(), 200)
        self.assertEqual(stack.size(), 2)  # Size unchanged
        self.assertEqual(stack.peek(), 200)  # Still same item
    
    def test_07_pop_empty_raises_exception(self):
        """Popping from empty stack should raise IndexError"""
        stack = Stack()
        with self.assertRaises(IndexError):
            stack.pop()
    
    def test_08_peek_empty_raises_exception(self):
        """Peeking empty stack should raise IndexError"""
        stack = Stack()
        with self.assertRaises(IndexError):
            stack.peek()


if __name__ == "__main__":
    unittest.main()
