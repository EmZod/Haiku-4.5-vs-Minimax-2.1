import React, { useState } from 'react';

function Counter() {
  const [count, setCount] = useState(0);

  const handleIncrement = () => {
    setCount(count + 1);
  };

  const handleDecrement = () => {
    setCount(count - 1);
  };

  return (
    <div>
      <p data-testid="count">{count}</p>
      <button data-testid="increment" onClick={handleIncrement}>
        Increment
      </button>
      <button data-testid="decrement" onClick={handleDecrement}>
        Decrement
      </button>
    </div>
  );
}

export default Counter;
