# Task C4: Multi-Step Data Pipeline

## Objective
Process `orders.json` through a multi-step pipeline and produce `summary.csv`.

## Input
`orders.json` - A JSON file containing an array of order objects with:
- `id`: Order ID (string)
- `customer`: Customer name (string)
- `items`: Array of items, each with `name`, `quantity`, `price`
- `status`: "completed", "pending", or "cancelled"
- `date`: ISO date string

## Pipeline Steps

### Step 1: Filter
Keep only orders where `status` is "completed"

### Step 2: Transform
For each order, calculate:
- `total`: sum of (quantity × price) for all items
- `item_count`: total number of items (sum of quantities)

### Step 3: Aggregate
Group by customer and calculate:
- `order_count`: number of orders per customer
- `total_spent`: sum of all order totals per customer
- `avg_order_value`: total_spent / order_count (rounded to 2 decimals)

### Step 4: Sort
Sort by `total_spent` descending

### Step 5: Output
Write `summary.csv` with columns:
```
customer,order_count,total_spent,avg_order_value
```

## Example
If Alice has 2 completed orders totaling $150 and $100:
```csv
customer,order_count,total_spent,avg_order_value
Alice,2,250.00,125.00
```

## Deliverables
- `summary.csv` - The processed output

## Success Criteria
- CSV has correct headers
- Calculations are accurate
- Sorting is correct
- Only completed orders are included

## Hints
- Process step by step, don't try to do everything at once
- Verify intermediate results
- Watch out for floating point precision
