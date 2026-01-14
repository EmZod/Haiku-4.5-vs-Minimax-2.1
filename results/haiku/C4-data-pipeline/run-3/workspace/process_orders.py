#!/usr/bin/env python3
import json
from collections import defaultdict
from typing import Dict, List, Any

# Step 1: Read orders.json
with open('orders.json', 'r') as f:
    orders = json.load(f)

# Step 1: Filter - Keep only completed orders
completed_orders = [order for order in orders if order['status'] == 'completed']
print(f"Step 1: Filtered {len(completed_orders)} completed orders from {len(orders)} total")

# Step 2: Transform - Calculate total and item_count for each order
transformed_orders = []
for order in completed_orders:
    total = sum(item['quantity'] * item['price'] for item in order['items'])
    item_count = sum(item['quantity'] for item in order['items'])
    transformed_orders.append({
        'customer': order['customer'],
        'total': total,
        'item_count': item_count
    })
    print(f"  {order['id']}: {order['customer']} - total=${total:.2f}, item_count={item_count}")

# Step 3: Aggregate - Group by customer
customer_stats = defaultdict(lambda: {'order_count': 0, 'total_spent': 0})
for order in transformed_orders:
    customer = order['customer']
    customer_stats[customer]['order_count'] += 1
    customer_stats[customer]['total_spent'] += order['total']

# Calculate avg_order_value
for customer in customer_stats:
    total_spent = customer_stats[customer]['total_spent']
    order_count = customer_stats[customer]['order_count']
    avg_order_value = round(total_spent / order_count, 2)
    customer_stats[customer]['avg_order_value'] = avg_order_value

print(f"\nStep 3: Aggregated data by customer:")
for customer, stats in customer_stats.items():
    print(f"  {customer}: {stats}")

# Step 4: Sort by total_spent descending
sorted_customers = sorted(customer_stats.items(), 
                         key=lambda x: x[1]['total_spent'], 
                         reverse=True)

print(f"\nStep 4: Sorted by total_spent (descending):")
for customer, stats in sorted_customers:
    print(f"  {customer}: ${stats['total_spent']:.2f}")

# Step 5: Write to summary.csv
with open('summary.csv', 'w') as f:
    f.write('customer,order_count,total_spent,avg_order_value\n')
    for customer, stats in sorted_customers:
        f.write(f"{customer},{stats['order_count']},{stats['total_spent']:.2f},{stats['avg_order_value']:.2f}\n")

print(f"\nStep 5: Written summary.csv")
