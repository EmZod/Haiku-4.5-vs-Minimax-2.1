"""
Stack implementation for TDD exercise.
A stack is a Last-In-First-Out (LIFO) data structure.
"""


class Stack:
    """A simple stack implementation using a list."""
    
    def __init__(self):
        """Initialize an empty stack."""
        self._items = []
    
    def push(self, item):
        """Add an item to the top of the stack."""
        self._items.append(item)
    
    def pop(self):
        """Remove and return the top item from the stack.
        
        Raises:
            IndexError: If the stack is empty.
        """
        if self.is_empty():
            raise IndexError("pop from empty stack")
        return self._items.pop()
    
    def peek(self):
        """Return the top item without removing it.
        
        Raises:
            IndexError: If the stack is empty.
        """
        if self.is_empty():
            raise IndexError("peek from empty stack")
        return self._items[-1]
    
    def is_empty(self):
        """Return True if the stack is empty, False otherwise."""
        return len(self._items) == 0
    
    def size(self):
        """Return the number of items in the stack."""
        return len(self._items)
