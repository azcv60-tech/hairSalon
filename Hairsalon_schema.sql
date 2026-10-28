CREATE TABLE IF NOT EXISTS services (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    price REAL NOT NULL,
    duration INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS appointments (
    id INTEGER PRIMARY KEY,
    client_id INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS appointment_items (
    id INTEGER PRIMARY KEY,
    appointment_id INTEGER NOT NULL,
    service_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL NOT NULL
);


CREATE TRIGGER IF NOT EXISTS trg_add_visit
AFTER INSERT ON appointment_items
BEGIN
    UPDATE services SET duration = duration + NEW.quantity WHERE id = NEW.service_id;
END;


CREATE TRIGGER IF NOT EXISTS trg_remove_visit
AFTER DELETE ON appointment_items
BEGIN
    UPDATE services SET duration = duration - OLD.quantity WHERE id = OLD.service_id;
END;
