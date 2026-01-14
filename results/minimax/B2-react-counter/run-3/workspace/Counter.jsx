import React, { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  const increment = () => {
    setCount(count + 1);
  };

  const decrement = () => {
    setCount(count - 1);
  };

  return (
    <div>
      <span data-testid="count">{count}</span>
      <button data-testid="increment" onClick={increment}>Increment</button>
      <button data-testid="decrement" onClick={decrement}>Decrement</button>
    </div>
  );
}

export default Counter;
