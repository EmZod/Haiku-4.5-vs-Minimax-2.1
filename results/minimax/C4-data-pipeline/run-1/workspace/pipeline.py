#!/usr/bin/env python3
"""Multi-step data pipeline to process orders and produce summary.csv"""

import json
from collections import defaultdict

# Read input
with open('orders.json', 'r') as f:
    orders = json.load(f)

# Step 1: Filter - Keep only completed orders
completed_orders = [order for order in orders if order['status'] == 'completed']

# Step 2: Transform - Calculate total and item_count
transformed = []
for order in completed_orders:
    total = sum(item['quantity'] * item['price'] for item in order['items'])
    item_count = sum(item['quantity'] for item in order['items'])
    transformed.append({
        'customer': order['customer'],
        'total': total,
        'item_count': item_count
    })

# Step 3: Aggregate - Group by customer
customer_stats = defaultdict(lambda: {'order_count': 0, 'total_spent': 0})
for order in transformed:
    customer = order['customer']
    customer_stats[customer]['order_count'] += 1
    customer_stats[customer]['total_spent'] += order['total']

# Step 4: Sort - By total_spent descending
sorted_customers = sorted(customer_stats.items(), key=lambda x: x[1]['total_spent'], reverse=True)

# Step 5: Output - Write summary.csv
with open('summary.csv', 'w') as f:
    f.write('customer,order_count,total_spent,avg_order_value\n')
    for customer, stats in sorted_customers:
        avg = round(stats['total_spent'] / stats['order_count'], 2)
        f.write(f'{customer},{stats["order_count"]},{stats["total_spent"]},{avg}\n')

print("Pipeline complete! Output written to summary.csv")
