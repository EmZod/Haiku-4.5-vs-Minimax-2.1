# Task B2: React Counter Component

## Objective
Create a simple React counter component with increment and decrement buttons.

## Requirements
1. Create a file named `Counter.jsx`
2. The component should:
   - Display a count (starting at 0)
   - Have an "Increment" button that adds 1
   - Have a "Decrement" button that subtracts 1
   - Use React hooks (useState)
3. Export the component as default

## Expected Structure
```jsx
import React, { useState } from 'react';

function Counter() {
  // State for count
  // Increment handler
  // Decrement handler
  // Return JSX with count display and two buttons
}

export default Counter;
```

## Required Elements
- `data-testid="count"` on the element displaying the count
- `data-testid="increment"` on the increment button
- `data-testid="decrement"` on the decrement button

## Deliverables
- `Counter.jsx` - The React component

## Success Criteria
- File exists and is valid JSX syntax
- Contains useState hook
- Has all three data-testid attributes
- Exports default component

## DO NOT
- Use class components
- Add external dependencies
- Create additional files
