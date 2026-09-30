import random
from datetime import date, timedelta
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

HOST_COUNT = 100
PROPERTY_COUNT = 150
GUEST_COUNT = 200
BOOKINGS_PER_PROPERTY_MIN = 2
BOOKINGS_PER_PROPERTY_MAX = 4

CITIES = ["Pune", "Mumbai", "Goa", "Nashik", "Lonavala", "Alibaug",
          "Mahabaleshwar", "Nagpur", "Aurangabad", "Kolhapur"]
STATUSES = ["Completed", "Completed", "Completed", "Confirmed", "Cancelled"]

output_lines = []


def add_line(line):
    output_lines.append(line)


def escape(text):
    result = ""
    index = 0
    while index < len(text):
        character = text[index]
        if character == "'":
            result = result + "''"
        else:
            result = result + character
        index = index + 1
    return result


add_line("USE rental_travel_db;")
add_line("")
add_line("-- ========================= HOST =========================")

host_ids = []
host_index = 0
while host_index < HOST_COUNT:
    host_id = host_index + 1
    host_name = fake.name()
    host_email = fake.unique.email()
    host_phone = fake.msisdn()[0:10]
    line = "INSERT INTO HOST (Host_ID, Host_Name, Host_Email, Host_Phone) VALUES ("
    line = line + str(host_id) + ", '" + escape(host_name) + "', '" + escape(host_email) + "', '" + escape(host_phone) + "');"
    add_line(line)
    host_ids.append(host_id)
    host_index = host_index + 1

add_line("")
add_line("-- ======================== PROPERTY =======================")

property_ids = []
property_index = 0
while property_index < PROPERTY_COUNT:
    property_id = property_index + 1
    host_id = random.choice(host_ids)
    city = random.choice(CITIES)
    location = city + " - " + fake.street_name()
    nightly_price = round(random.uniform(1200.0, 9500.0), 2)
    line = "INSERT INTO PROPERTY (Property_ID, Host_ID, Location, Nightly_Price) VALUES ("
    line = line + str(property_id) + ", " + str(host_id) + ", '" + escape(location) + "', " + str(nightly_price) + ");"
    add_line(line)
    property_ids.append(property_id)
    property_index = property_index + 1

add_line("")
add_line("-- ========================= GUEST ==========================")

guest_ids = []
guest_index = 0
while guest_index < GUEST_COUNT:
    guest_id = guest_index + 1
    guest_name = fake.name()
    guest_phone = fake.msisdn()[0:10]
    line = "INSERT INTO GUEST (Guest_ID, Guest_Name, Guest_Phone) VALUES ("
    line = line + str(guest_id) + ", '" + escape(guest_name) + "', '" + escape(guest_phone) + "');"
    add_line(line)
    guest_ids.append(guest_id)
    guest_index = guest_index + 1

add_line("")
add_line("-- ======================== BOOKING =========================")
add_line("-- Non-overlapping date windows are generated per property so the")
add_line("-- anti-double-booking trigger (trg_prevent_double_booking, added")
add_line("-- in queries.sql) never rejects a row here.")

booking_records = []
booking_id_counter = 1

property_index = 0
while property_index < len(property_ids):
    current_property_id = property_ids[property_index]
    number_of_bookings = random.randint(BOOKINGS_PER_PROPERTY_MIN, BOOKINGS_PER_PROPERTY_MAX)
    cursor_date = date(2025, 1, 1)

    booking_index = 0
    while booking_index < number_of_bookings:
        gap_before_days = random.randint(3, 20)
        stay_length_days = random.randint(2, 9)
        check_in = cursor_date + timedelta(days=gap_before_days)
        check_out = check_in + timedelta(days=stay_length_days)

        if check_out > date(2025, 12, 20):
            break

        guest_id = random.choice(guest_ids)
        status = random.choice(STATUSES)

        booking_records.append([booking_id_counter, guest_id, current_property_id, check_in, check_out, status])

        line = "INSERT INTO BOOKING (Booking_ID, Guest_ID, Property_ID, Check_In, Check_Out, Booking_Status) VALUES ("
        line = line + str(booking_id_counter) + ", " + str(guest_id) + ", " + str(current_property_id) + ", '"
        line = line + check_in.isoformat() + "', '" + check_out.isoformat() + "', '" + status + "');"
        add_line(line)

        booking_id_counter = booking_id_counter + 1
        cursor_date = check_out
        booking_index = booking_index + 1

    property_index = property_index + 1

add_line("")
add_line("-- ========================= REVIEW =========================")
add_line("-- Only 'Completed' bookings receive a review, matching the")
add_line("-- business rule that a guest cannot review a stay that never happened.")

review_id_counter = 1
record_index = 0
while record_index < len(booking_records):
    record = booking_records[record_index]
    this_booking_id = record[0]
    this_status = record[5]

    if this_status == "Completed" and random.random() < 0.85:
        rating = random.randint(1, 5)
        comment = fake.sentence(nb_words=12)
        line = "INSERT INTO REVIEW (Review_ID, Booking_ID, Rating, Comment) VALUES ("
        line = line + str(review_id_counter) + ", " + str(this_booking_id) + ", " + str(rating) + ", '" + escape(comment) + "');"
        add_line(line)
        review_id_counter = review_id_counter + 1

    record_index = record_index + 1

output_file = open("data.sql", "w")
line_index = 0
while line_index < len(output_lines):
    output_file.write(output_lines[line_index] + "\n")
    line_index = line_index + 1
output_file.close()

print("Generated " + str(len(host_ids)) + " hosts")
print("Generated " + str(len(property_ids)) + " properties")
print("Generated " + str(len(guest_ids)) + " guests")
print("Generated " + str(len(booking_records)) + " bookings")
print("Generated " + str(review_id_counter - 1) + " reviews")
print("Written to data.sql")
