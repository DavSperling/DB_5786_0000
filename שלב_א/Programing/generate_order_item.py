import random
import os

OUTPUT_DIR = "Programming"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "order_item_data.sql")
NUM_ROWS = 20000

SPECIAL_REQUESTS = [
    'No salt', 'Extra sauce', 'Allergic to nuts', 'Well done',
    'No onions', 'Gluten free', 'No pepper', 'Extra cheese'
]

os.makedirs(OUTPUT_DIR, exist_ok=True)

with open(OUTPUT_FILE, 'w') as f:
    f.write("BEGIN;\n\n")
    for i in range(1, NUM_ROWS + 1):
        order_id = random.randint(1, 500)
        menu_item_id = random.randint(1, 100)
        quantity = random.randint(1, 10)

        if random.random() < 0.6:
            special_request = "NULL"
        else:
            special_request = "'" + random.choice(SPECIAL_REQUESTS) + "'"

        f.write(
            f"INSERT INTO ORDER_ITEM (order_item_id, order_id, menu_item_id, quantity, special_request) "
            f"VALUES ({i}, {order_id}, {menu_item_id}, {quantity}, {special_request});\n"
        )
    f.write("\nCOMMIT;\n")

print(f"Generated {NUM_ROWS} INSERT statements into '{OUTPUT_FILE}'.")
