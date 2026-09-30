-- =====================================================================
-- queries.sql
-- Short-Term Rental & Group Travel Management Database
-- TAE 2 - Advanced SQL Implementation + Performance Tuning & Indexing
-- Target RDBMS: MySQL 8.0
-- =====================================================================

USE rental_travel_db;

-- ---------------------------------------------------------------------
-- 1. MULTI-TABLE INNER JOIN
-- Every booking together with guest name, property location and the
-- host who owns that property.
-- ---------------------------------------------------------------------
SELECT
    b.Booking_ID,
    g.Guest_Name,
    p.Location,
    h.Host_Name,
    b.Check_In,
    b.Check_Out,
    b.Booking_Status
FROM BOOKING b
INNER JOIN GUEST g    ON b.Guest_ID = g.Guest_ID
INNER JOIN PROPERTY p ON b.Property_ID = p.Property_ID
INNER JOIN HOST h     ON p.Host_ID = h.Host_ID
ORDER BY b.Check_In;

-- ---------------------------------------------------------------------
-- 2. MULTI-TABLE OUTER JOIN (LEFT JOIN)
-- Every property with its bookings -- properties that have NEVER been
-- booked still appear, with NULL booking columns.
-- ---------------------------------------------------------------------
SELECT
    p.Property_ID,
    p.Location,
    h.Host_Name,
    b.Booking_ID,
    b.Booking_Status
FROM PROPERTY p
LEFT JOIN HOST h    ON p.Host_ID = h.Host_ID
LEFT JOIN BOOKING b ON p.Property_ID = b.Property_ID
ORDER BY p.Property_ID;

-- ---------------------------------------------------------------------
-- 3. SELF JOIN
-- Competing listings: pairs of DIFFERENT properties in the same city,
-- so a host can benchmark their price against nearby competitors.
-- ---------------------------------------------------------------------
SELECT
    p1.Property_ID   AS Property_A,
    p1.Location      AS Location_A,
    p1.Nightly_Price AS Price_A,
    p2.Property_ID   AS Property_B,
    p2.Location      AS Location_B,
    p2.Nightly_Price AS Price_B
FROM PROPERTY p1
INNER JOIN PROPERTY p2
    ON SUBSTRING_INDEX(p1.Location, ' - ', 1) = SUBSTRING_INDEX(p2.Location, ' - ', 1)
   AND p1.Property_ID < p2.Property_ID
ORDER BY Location_A
LIMIT 50;

-- ---------------------------------------------------------------------
-- 4. CORRELATED SUBQUERY
-- Properties priced above the AVERAGE nightly price charged by their
-- OWN host (each host's own "premium" listings).
-- ---------------------------------------------------------------------
SELECT
    p.Property_ID,
    p.Location,
    p.Nightly_Price,
    p.Host_ID
FROM PROPERTY p
WHERE p.Nightly_Price > (
    SELECT AVG(p2.Nightly_Price)
    FROM PROPERTY p2
    WHERE p2.Host_ID = p.Host_ID
)
ORDER BY p.Host_ID;

-- ---------------------------------------------------------------------
-- 5. AGGREGATE FUNCTIONS + GROUP BY / HAVING
-- Monthly revenue per property (nights stayed x nightly price),
-- restricted to properties earning more than 20,000 in that month.
-- ---------------------------------------------------------------------
SELECT
    p.Property_ID,
    p.Location,
    DATE_FORMAT(b.Check_In, '%Y-%m') AS Booking_Month,
    COUNT(b.Booking_ID) AS Total_Bookings,
    SUM(DATEDIFF(b.Check_Out, b.Check_In) * p.Nightly_Price) AS Revenue
FROM BOOKING b
INNER JOIN PROPERTY p ON b.Property_ID = p.Property_ID
WHERE b.Booking_Status IN ('Completed', 'Confirmed')
GROUP BY p.Property_ID, p.Location, DATE_FORMAT(b.Check_In, '%Y-%m')
HAVING Revenue > 20000
ORDER BY Revenue DESC;

-- ---------------------------------------------------------------------
-- 6. STORED PROCEDURE (with parameters) - operational transaction
-- Processes a new guest booking end-to-end: validates the date range
-- and checks for overlap before inserting (the trigger below is the
-- last line of defense if this procedure is bypassed).
-- ---------------------------------------------------------------------
DELIMITER //

CREATE PROCEDURE sp_create_booking (
    IN  p_guest_id    INT,
    IN  p_property_id INT,
    IN  p_check_in    DATE,
    IN  p_check_out   DATE,
    OUT p_result_msg   VARCHAR(200)
)
BEGIN
    DECLARE v_overlap_count INT DEFAULT 0;

    IF p_check_out <= p_check_in THEN
        SET p_result_msg = 'REJECTED: Check-out must be after check-in';
    ELSE
        SELECT COUNT(*) INTO v_overlap_count
        FROM BOOKING
        WHERE Property_ID = p_property_id
          AND Booking_Status <> 'Cancelled'
          AND p_check_in < Check_Out
          AND p_check_out > Check_In;

        IF v_overlap_count > 0 THEN
            SET p_result_msg = 'REJECTED: Property already booked for overlapping dates';
        ELSE
            INSERT INTO BOOKING (Guest_ID, Property_ID, Check_In, Check_Out, Booking_Status)
            VALUES (p_guest_id, p_property_id, p_check_in, p_check_out, 'Confirmed');
            SET p_result_msg = CONCAT('CONFIRMED: Booking_ID ', LAST_INSERT_ID());
        END IF;
    END IF;
END //

DELIMITER ;

-- Example call (uncomment to run):
-- CALL sp_create_booking(5, 12, '2026-03-01', '2026-03-05', @msg);
-- SELECT @msg;

-- ---------------------------------------------------------------------
-- 7. TRIGGER - automated business rule
-- "A property cannot have overlapping booking dates" (TAE 1 constraint).
-- Fires BEFORE INSERT on BOOKING and blocks the row if any existing,
-- non-cancelled booking on the same property overlaps the new dates.
-- ---------------------------------------------------------------------
DELIMITER //

CREATE TRIGGER trg_prevent_double_booking
BEFORE INSERT ON BOOKING
FOR EACH ROW
BEGIN
    DECLARE v_conflict INT DEFAULT 0;

    SELECT COUNT(*) INTO v_conflict
    FROM BOOKING
    WHERE Property_ID = NEW.Property_ID
      AND Booking_Status <> 'Cancelled'
      AND NEW.Check_In < Check_Out
      AND NEW.Check_Out > Check_In;

    IF v_conflict > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Booking rejected: overlapping dates for this property';
    END IF;
END //

DELIMITER ;

-- ---------------------------------------------------------------------
-- 8. VIEWS (business reporting)
-- ---------------------------------------------------------------------

-- View 1: Stays that are active right now (today falls inside the window)
CREATE OR REPLACE VIEW v_active_bookings AS
SELECT
    b.Booking_ID,
    g.Guest_Name,
    p.Location,
    h.Host_Name,
    b.Check_In,
    b.Check_Out
FROM BOOKING b
INNER JOIN GUEST g    ON b.Guest_ID = g.Guest_ID
INNER JOIN PROPERTY p ON b.Property_ID = p.Property_ID
INNER JOIN HOST h     ON p.Host_ID = h.Host_ID
WHERE CURDATE() BETWEEN b.Check_In AND b.Check_Out
  AND b.Booking_Status = 'Confirmed';

-- View 2: Host revenue & rating summary
CREATE OR REPLACE VIEW v_host_revenue_summary AS
SELECT
    h.Host_ID,
    h.Host_Name,
    COUNT(DISTINCT p.Property_ID) AS Total_Properties,
    COUNT(b.Booking_ID)           AS Total_Bookings,
    SUM(DATEDIFF(b.Check_Out, b.Check_In) * p.Nightly_Price) AS Total_Revenue,
    ROUND(AVG(r.Rating), 2)       AS Avg_Rating
FROM HOST h
LEFT JOIN PROPERTY p ON h.Host_ID = p.Host_ID
LEFT JOIN BOOKING b  ON p.Property_ID = b.Property_ID AND b.Booking_Status IN ('Completed', 'Confirmed')
LEFT JOIN REVIEW r   ON b.Booking_ID = r.Booking_ID
GROUP BY h.Host_ID, h.Host_Name;

-- ---------------------------------------------------------------------
-- 9. PERFORMANCE TUNING: EXPLAIN BEFORE INDEXING
-- ---------------------------------------------------------------------

-- Query A: correlated subquery from Section 4 (host's own average price)
EXPLAIN
SELECT p.Property_ID, p.Location, p.Nightly_Price
FROM PROPERTY p
WHERE p.Nightly_Price > (
    SELECT AVG(p2.Nightly_Price) FROM PROPERTY p2 WHERE p2.Host_ID = p.Host_ID
);

-- Query B: revenue lookup filtered by a check-in date range
EXPLAIN
SELECT p.Location, SUM(DATEDIFF(b.Check_Out, b.Check_In) * p.Nightly_Price) AS Revenue
FROM BOOKING b
INNER JOIN PROPERTY p ON b.Property_ID = p.Property_ID
WHERE b.Check_In BETWEEN '2025-06-01' AND '2025-08-31'
GROUP BY p.Location;

-- ---------------------------------------------------------------------
-- 10. CREATE INDEXES
-- ---------------------------------------------------------------------

-- Speeds up Query A: PROPERTY is filtered/correlated by Host_ID
CREATE INDEX idx_property_host ON PROPERTY(Host_ID);

-- Speeds up Query B: BOOKING is filtered by Check_In and joined on Property_ID
CREATE INDEX idx_booking_property_checkin ON BOOKING(Property_ID, Check_In);

-- ---------------------------------------------------------------------
-- 11. PERFORMANCE TUNING: EXPLAIN AFTER INDEXING (same two queries)
-- ---------------------------------------------------------------------

EXPLAIN
SELECT p.Property_ID, p.Location, p.Nightly_Price
FROM PROPERTY p
WHERE p.Nightly_Price > (
    SELECT AVG(p2.Nightly_Price) FROM PROPERTY p2 WHERE p2.Host_ID = p.Host_ID
);

EXPLAIN
SELECT p.Location, SUM(DATEDIFF(b.Check_Out, b.Check_In) * p.Nightly_Price) AS Revenue
FROM BOOKING b
INNER JOIN PROPERTY p ON b.Property_ID = p.Property_ID
WHERE b.Check_In BETWEEN '2025-06-01' AND '2025-08-31'
GROUP BY p.Location;
