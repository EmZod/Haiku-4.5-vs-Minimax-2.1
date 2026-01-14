#!/usr/bin/env python3
import json
import csv
from collections import defaultdict

# Step 1: Load and filter
print("Step 1: Loading and filtering orders...")
with open('orders.json', 'r') as f:
    orders = json.load(f)

completed_orders = [order for order in orders if order['status'] == 'completed']
print(f"  Filtered {len(orders)} orders → {len(completed_orders)} completed orders")

# Step 2: Transform - calculate total and item_count
print("\nStep 2: Transforming orders...")
transformed = []
for order in completed_orders:
    total = sum(item['quantity'] * item['price'] for item in order['items'])
    item_count = sum(item['quantity'] for item in order['items'])
    transformed.append({
        'customer': order['customer'],
        'order_id': order['id'],
        'total': total,
        'item_count': item_count
    })
    print(f"  {order['id']}: {order['customer']} - ${total:.2f} ({item_count} items)")

# Step 3: Aggregate by customer
print("\nStep 3: Aggregating by customer...")
customer_stats = defaultdict(lambda: {'order_count': 0, 'total_spent': 0})

for order in transformed:
    customer = order['customer']
    customer_stats[customer]['order_count'] += 1
    customer_stats[customer]['total_spent'] += order['total']

# Calculate average order value
aggregated = []
for customer, stats in customer_stats.items():
    avg_order_value = stats['total_spent'] / stats['order_count']
    aggregated.append({
        'customer': customer,
        'order_count': stats['order_count'],
        'total_spent': round(stats['total_spent'], 2),
        'avg_order_value': round(avg_order_value, 2)
    })
    print(f"  {customer}: {stats['order_count']} orders, ${stats['total_spent']:.2f} spent, ${avg_order_value:.2f} avg")

# Step 4: Sort by total_spent descending
print("\nStep 4: Sorting by total_spent descending...")
aggregated.sort(key=lambda x: x['total_spent'], reverse=True)
for row in aggregated:
    print(f"  {row['customer']}: ${row['total_spent']}")

# Step 5: Output to CSV
print("\nStep 5: Writing summary.csv...")
with open('summary.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerow(['customer', 'order_count', 'total_spent', 'avg_order_value'])
    for row in aggregated:
        writer.writerow([
            row['customer'],
            row['order_count'],
            f"{row['total_spent']:.2f}",
            f"{row['avg_order_value']:.2f}"
        ])

print("  ✓ summary.csv created successfully")

# Verify the output
print("\nFinal CSV contents:")
with open('summary.csv', 'r') as f:
    print(f.read())
