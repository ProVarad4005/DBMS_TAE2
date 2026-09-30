DROP DATABASE IF EXISTS rental_travel_db;
CREATE DATABASE rental_travel_db;
USE rental_travel_db;

CREATE TABLE HOST (
    Host_ID     INT AUTO_INCREMENT PRIMARY KEY,
    Host_Name   VARCHAR(100) NOT NULL,
    Host_Email  VARCHAR(100) NOT NULL,
    Host_Phone  VARCHAR(15)  NOT NULL,
    CONSTRAINT uq_host_email UNIQUE (Host_Email),
    CONSTRAINT chk_host_phone_len CHECK (CHAR_LENGTH(Host_Phone) >= 10)
) ENGINE = InnoDB;

CREATE TABLE PROPERTY (
    Property_ID    INT AUTO_INCREMENT PRIMARY KEY,
    Host_ID        INT NOT NULL,
    Location       VARCHAR(150) NOT NULL,
    Nightly_Price  DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_property_host
        FOREIGN KEY (Host_ID) REFERENCES HOST(Host_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_property_price CHECK (Nightly_Price > 0)
) ENGINE = InnoDB;

CREATE TABLE GUEST (
    Guest_ID    INT AUTO_INCREMENT PRIMARY KEY,
    Guest_Name  VARCHAR(100) NOT NULL,
    Guest_Phone VARCHAR(15)  NOT NULL,
    CONSTRAINT chk_guest_phone_len CHECK (CHAR_LENGTH(Guest_Phone) >= 10)
) ENGINE = InnoDB;

CREATE TABLE BOOKING (
    Booking_ID      INT AUTO_INCREMENT PRIMARY KEY,
    Guest_ID        INT NOT NULL,
    Property_ID     INT NOT NULL,
    Check_In        DATE NOT NULL,
    Check_Out       DATE NOT NULL,
    Booking_Status  VARCHAR(20) NOT NULL DEFAULT 'Confirmed',
    CONSTRAINT fk_booking_guest
        FOREIGN KEY (Guest_ID) REFERENCES GUEST(Guest_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_booking_property
        FOREIGN KEY (Property_ID) REFERENCES PROPERTY(Property_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_booking_dates CHECK (Check_Out > Check_In),
    CONSTRAINT chk_booking_status CHECK (Booking_Status IN ('Confirmed','Cancelled','Completed'))
) ENGINE = InnoDB;

CREATE TABLE REVIEW (
    Review_ID   INT AUTO_INCREMENT PRIMARY KEY,
    Booking_ID  INT NOT NULL,
    Rating      INT NOT NULL,
    Comment     TEXT,
    CONSTRAINT uq_review_booking UNIQUE (Booking_ID),
    CONSTRAINT fk_review_booking
        FOREIGN KEY (Booking_ID) REFERENCES BOOKING(Booking_ID)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_review_rating CHECK (Rating BETWEEN 1 AND 5)
) ENGINE = InnoDB;
