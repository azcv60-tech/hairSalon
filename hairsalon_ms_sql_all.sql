USE HairSalonDB;
GO
CREATE SCHEMA salon;
GO

CREATE TABLE salon.services (
    id        INT IDENTITY(1,1) PRIMARY KEY,
    name      NVARCHAR(100) NOT NULL UNIQUE,
    category  NVARCHAR(50) NOT NULL CHECK (category IN (N'Стрижка', N'Окрашивание', N'Уход за волосами', N'Маникюр', N'Услуги для мужчин')),
    price     DECIMAL(10,2) NOT NULL CHECK (price > 0)
);
GO

CREATE TABLE salon.masters (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    full_name  NVARCHAR(150) NOT NULL,
    phone      NVARCHAR(20) NOT NULL UNIQUE,
    specialization NVARCHAR(100) NOT NULL
);
GO

CREATE TABLE salon.clients (
    id         INT IDENTITY(1,1) PRIMARY KEY,
    full_name  NVARCHAR(150) NOT NULL,
    phone      NVARCHAR(20) NOT NULL UNIQUE
);
GO

CREATE TABLE salon.visits (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    client_id    INT NOT NULL,
    master_id    INT NOT NULL,
    created_at   DATETIME2 DEFAULT SYSDATETIME(),
    visit_date   DATETIME2 NOT NULL,
    FOREIGN KEY (client_id) REFERENCES salon.clients(id) ON DELETE CASCADE,
    FOREIGN KEY (master_id) REFERENCES salon.masters(id)
);
GO

CREATE TABLE salon.visit_items (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    visit_id    INT NOT NULL,
    service_id  INT NOT NULL,
    quantity    INT NOT NULL CHECK (quantity > 0),
    price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
    FOREIGN KEY (visit_id) REFERENCES salon.visits(id) ON DELETE CASCADE,
    FOREIGN KEY (service_id) REFERENCES salon.services(id)
);
GO

INSERT INTO salon.services (name, category, price) VALUES 
(N'Женская стрижка', N'Стрижка', 1500.00),
(N'Мужская стрижка', N'Услуги для мужчин', 800.00),
(N'Окрашивание в один тон', N'Окрашивание', 3500.00),
(N'Маникюр классический', N'Маникюр', 1200.00),
(N'Уход за волосами (SPA)', N'Уход за волосами', 2000.00);

INSERT INTO salon.masters (full_name, phone, specialization) VALUES 
(N'Соколова Елена', N'+7-900-111-22-33', N'Парикмахер-стилист'),
(N'Кузнецов Дмитрий', N'+7-900-444-55-66', N'Барбер'),
(N'Морозова Ольга', N'+7-900-777-88-99', N'Мастер маникюра');

INSERT INTO salon.clients (full_name, phone) VALUES 
(N'Иванова Анна', N'+7-900-123-45-67'),
(N'Петров Сергей', N'+7-900-234-56-78'),
(N'Сидорова Мария', N'+7-900-345-67-89');
GO

CREATE INDEX ix_services_name ON salon.services(name);
CREATE INDEX ix_visits_visit_date ON salon.visits(visit_date);
CREATE INDEX ix_visits_created_at ON salon.visits(created_at);
GO

CREATE VIEW salon.v_daily_revenue AS
SELECT 
    CAST(v.visit_date AS DATE) AS visit_date,
    COUNT(DISTINCT v.id) AS visits_count,
    SUM(vi.quantity * vi.price) AS revenue
FROM salon.visits v 
JOIN salon.visit_items vi ON vi.visit_id = v.id
GROUP BY CAST(v.visit_date AS DATE);
GO

CREATE VIEW salon.v_master_workload AS
SELECT 
    m.full_name AS master_name,
    COUNT(v.id) AS visits_count,
    SUM(vi.quantity * vi.price) AS total_revenue
FROM salon.masters m
LEFT JOIN salon.visits v ON v.master_id = m.id
LEFT JOIN salon.visit_items vi ON vi.visit_id = v.id
GROUP BY m.id, m.full_name;
GO

CREATE PROCEDURE salon.proc_Services_GetAll AS
BEGIN 
    SELECT * FROM salon.services ORDER BY name; 
END
GO

CREATE PROCEDURE salon.proc_Visits_Create 
    @ClientId INT, 
    @MasterId INT, 
    @VisitDate DATETIME2,
    @VisitId INT OUTPUT 
AS
BEGIN
    IF NOT EXISTS (SELECT 1 FROM salon.clients WHERE id = @ClientId) 
        THROW 50010, N'Клиент не найден', 1;
    IF NOT EXISTS (SELECT 1 FROM salon.masters WHERE id = @MasterId) 
        THROW 50011, N'Мастер не найден', 1;
    
    INSERT INTO salon.visits (client_id, master_id, visit_date) 
    VALUES (@ClientId, @MasterId, @VisitDate);
    
    SET @VisitId = SCOPE_IDENTITY();
END
GO

CREATE FUNCTION salon.fn_VisitItem_LineTotal (@Quantity INT, @Price DECIMAL(10,2))
RETURNS DECIMAL(10,2) AS
BEGIN
    IF @Quantity IS NULL OR @Price IS NULL OR @Quantity <= 0 RETURN 0;
    RETURN @Quantity * @Price;
END
GO

CREATE FUNCTION salon.fn_Visits_ByClient (@ClientId INT)
RETURNS TABLE AS
RETURN (
    SELECT 
        v.id, 
        v.visit_date,
        m.full_name AS master_name,
        (SELECT SUM(quantity * price) FROM salon.visit_items WHERE visit_id = v.id) AS total
    FROM salon.visits v
    JOIN salon.masters m ON m.id = v.master_id
    WHERE v.client_id = @ClientId
)
GO

CREATE TABLE salon.audit_log (
    id INT IDENTITY(1,1) PRIMARY KEY, 
    table_name NVARCHAR(100), 
    operation NVARCHAR(10),
    old_value NVARCHAR(MAX), 
    new_value NVARCHAR(MAX), 
    changed_at DATETIME2 DEFAULT GETDATE()
);
GO

CREATE TRIGGER salon.trg_Services_Audit_Update ON salon.services AFTER UPDATE AS
BEGIN
    INSERT INTO salon.audit_log (table_name, operation, old_value, new_value)
    SELECT N'services', N'UPDATE', CONCAT(N'price=', d.price), CONCAT(N'price=', i.price)
    FROM inserted i JOIN deleted d ON d.id = i.id;
END
GO

CREATE TRIGGER salon.trg_VisitItems_CheckMaster ON salon.visit_items AFTER INSERT AS
BEGIN
    -- Проверка: мастер должен иметь специализацию, соответствующую категории услуги
    IF EXISTS (
        SELECT 1 
        FROM inserted i 
        JOIN salon.visits v ON v.id = i.visit_id
        JOIN salon.masters m ON m.id = v.master_id
        JOIN salon.services s ON s.id = i.service_id
        WHERE (s.category = N'Услуги для мужчин' AND m.specialization NOT LIKE N'%барбер%')
           OR (s.category = N'Маникюр' AND m.specialization NOT LIKE N'%маникюр%')
    )
    BEGIN
        THROW 50020, N'Мастер не имеет соответствующей специализации для данной услуги', 1;
    END
END
GO
