-- Cow Farming Management System : MySQL script
DROP DATABASE IF EXISTS cow_farm_db;
CREATE DATABASE cow_farm_db;
USE cow_farm_db;

CREATE TABLE cow (
  cow_id            INT AUTO_INCREMENT PRIMARY KEY,
  cow_name          VARCHAR(50) NOT NULL UNIQUE,
  breed             VARCHAR(50) NOT NULL,
  age               INT NOT NULL CHECK (age BETWEEN 0 AND 30),
  gender            VARCHAR(10) NOT NULL CHECK (gender IN ('Female','Male')),
  weight            DECIMAL(6,2) NOT NULL CHECK (weight > 0),
  registration_date DATE NOT NULL,
  health_status     VARCHAR(20) NOT NULL DEFAULT 'Healthy'
                    CHECK (health_status IN ('Healthy','Under Treatment','Sick'))
);

CREATE TABLE milk_production (
  production_id   INT AUTO_INCREMENT PRIMARY KEY,
  cow_id          INT NOT NULL,
  production_date DATE NOT NULL,
  morning_qty     DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (morning_qty >= 0),
  evening_qty     DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (evening_qty >= 0),
  total_qty       DECIMAL(6,2) GENERATED ALWAYS AS (morning_qty + evening_qty) STORED,
  UNIQUE (cow_id, production_date),
  FOREIGN KEY (cow_id) REFERENCES cow(cow_id) ON DELETE CASCADE
);

CREATE TABLE feeding (
  feed_id       INT AUTO_INCREMENT PRIMARY KEY,
  cow_id        INT NOT NULL,
  feed_type     VARCHAR(50) NOT NULL,
  feed_quantity DECIMAL(6,2) NOT NULL CHECK (feed_quantity > 0),
  feeding_date  DATE NOT NULL,
  feed_cost     DECIMAL(8,2) NOT NULL CHECK (feed_cost >= 0),
  FOREIGN KEY (cow_id) REFERENCES cow(cow_id) ON DELETE CASCADE
);

CREATE TABLE health_record (
  health_id       INT AUTO_INCREMENT PRIMARY KEY,
  cow_id          INT NOT NULL,
  disease_details VARCHAR(150) NOT NULL DEFAULT 'None (routine vaccination)',
  treatment       VARCHAR(150),
  vaccination_date DATE,
  vet_name        VARCHAR(60) NOT NULL,
  vet_phone       VARCHAR(15),
  FOREIGN KEY (cow_id) REFERENCES cow(cow_id) ON DELETE CASCADE
);

CREATE TABLE breeding (
  breeding_id            INT AUTO_INCREMENT PRIMARY KEY,
  cow_id                 INT NOT NULL,
  breeding_date          DATE NOT NULL,
  pregnancy_status       VARCHAR(20) NOT NULL DEFAULT 'Pending'
                         CHECK (pregnancy_status IN ('Pending','Pregnant','Not Pregnant','Delivered')),
  expected_delivery_date DATE,
  FOREIGN KEY (cow_id) REFERENCES cow(cow_id) ON DELETE CASCADE
);

CREATE TABLE milk_sales (
  sale_id         INT AUTO_INCREMENT PRIMARY KEY,
  sale_date       DATE NOT NULL,
  customer_name   VARCHAR(60) NOT NULL,
  milk_quantity   DECIMAL(7,2) NOT NULL CHECK (milk_quantity > 0),
  price_per_litre DECIMAL(6,2) NOT NULL CHECK (price_per_litre > 0),
  total_amount    DECIMAL(10,2) GENERATED ALWAYS AS (milk_quantity * price_per_litre) STORED
);

CREATE TABLE expense (
  expense_id          INT AUTO_INCREMENT PRIMARY KEY,
  expense_category    VARCHAR(40) NOT NULL,
  expense_description VARCHAR(150),
  expense_date        DATE NOT NULL,
  amount              DECIMAL(10,2) NOT NULL CHECK (amount > 0)
);

-- TRIGGER: auto-fill expected delivery date (about 283 days of gestation)
DELIMITER //
CREATE TRIGGER trg_breeding_delivery
BEFORE INSERT ON breeding
FOR EACH ROW
BEGIN
  IF NEW.expected_delivery_date IS NULL THEN
    SET NEW.expected_delivery_date = DATE_ADD(NEW.breeding_date, INTERVAL 283 DAY);
  END IF;
END//
DELIMITER ;

-- VIEW: cow-wise milk summary
CREATE VIEW vw_cow_milk_summary AS
SELECT c.cow_id, c.cow_name, c.breed,
       COALESCE(SUM(m.total_qty),0) AS total_litres
FROM cow c LEFT JOIN milk_production m ON c.cow_id = m.cow_id
GROUP BY c.cow_id, c.cow_name, c.breed;

-- ---------- SAMPLE DATA ----------
INSERT INTO cow (cow_name, breed, age, gender, weight, registration_date, health_status) VALUES
('Lakshmi','Holstein Friesian',4,'Female',480.50,'2025-01-10','Healthy'),
('Ganga','Jersey',3,'Female',390.00,'2025-02-15','Healthy'),
('Gauri','Gir',5,'Female',420.75,'2025-03-01','Under Treatment'),
('Kamadhenu','Sahiwal',6,'Female',450.00,'2025-03-20','Healthy'),
('Nandi','Hallikar',4,'Male',510.00,'2025-04-05','Healthy');

INSERT INTO milk_production (cow_id, production_date, morning_qty, evening_qty) VALUES
(1,'2026-11-13',12.5,10.0),(2,'2026-11-13',8.0,7.0),(3,'2026-11-13',6.5,5.5),(4,'2026-11-13',9.0,8.0),
(1,'2026-11-14',13.0,10.5),(2,'2026-11-14',8.5,7.5),(3,'2026-11-14',6.0,5.0),(4,'2026-11-14',9.5,8.5),
(1,'2026-11-15',12.8,10.2),(2,'2026-11-15',8.2,7.1),(4,'2026-11-15',9.2,8.3);

INSERT INTO feeding (cow_id, feed_type, feed_quantity, feeding_date, feed_cost) VALUES
(1,'Green Fodder',25.0,'2026-11-14',150.00),(1,'Cattle Feed',5.0,'2026-11-14',130.00),
(2,'Green Fodder',20.0,'2026-11-14',120.00),(3,'Dry Hay',15.0,'2026-11-14',90.00),
(4,'Cattle Feed',6.0,'2026-11-14',156.00),(5,'Dry Hay',12.0,'2026-11-14',72.00);

INSERT INTO health_record (cow_id, disease_details, treatment, vaccination_date, vet_name, vet_phone) VALUES
(3,'Mastitis','Antibiotic course for 5 days','2026-11-10','Dr. Ramesh Kumar','9876543210'),
(1,'None (routine vaccination)','FMD vaccine','2026-10-05','Dr. Ramesh Kumar','9876543210'),
(2,'None (routine vaccination)','FMD vaccine','2026-10-05','Dr. Anita Rao','9123456780'),
(4,'Foot infection','Antiseptic dressing','2026-09-18','Dr. Anita Rao','9123456780');

INSERT INTO breeding (cow_id, breeding_date, pregnancy_status, expected_delivery_date) VALUES
(1,'2026-08-01','Pregnant','2027-05-11'),
(2,'2026-09-10','Pending',NULL),
(4,'2026-02-12','Delivered','2026-11-22');

INSERT INTO milk_sales (sale_date, customer_name, milk_quantity, price_per_litre) VALUES
('2026-11-13','Sri Dairy Co-op',40.0,45.00),('2026-11-13','Ravi Sweets',20.0,48.00),
('2026-11-14','Sri Dairy Co-op',42.0,45.00),('2026-11-14','Hotel Annapurna',15.0,50.00),
('2026-11-15','Sri Dairy Co-op',38.0,45.00);

INSERT INTO expense (expense_category, expense_description, expense_date, amount) VALUES
('Feed','Cattle feed 10 bags','2026-11-01',7800.00),
('Medicine','Antibiotics and vaccines','2026-11-10',2400.00),
('Labour','Worker salary - November','2026-11-05',9000.00),
('Electricity','Milking machine and shed','2026-11-08',1800.00),
('Veterinary','Doctor visit charges','2026-10-18',1500.00);
