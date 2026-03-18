import random
import os

OUTPUT_DIR = "Programming"
OUTPUT_FILE = os.path.join(OUTPUT_DIR, "bill_discount_data.sql")
NUM_ROWS = 20000

os.makedirs(OUTPUT_DIR, exist_ok=True)

with open(OUTPUT_FILE, 'w') as f:
    f.write("BEGIN;\n\n")
    for i in range(1, NUM_ROWS + 1):
        bill_id = random.randint(1, 500)
        discount_id = random.randint(1, 500)

        f.write(
            f"INSERT INTO BILL_DISCOUNT (bill_discount_id, bill_id, discount_id) "
            f"VALUES ({i}, {bill_id}, {discount_id});\n"
        )
    f.write("\nCOMMIT;\n")

print(f"Generated {NUM_ROWS} INSERT statements into '{OUTPUT_FILE}'.")
