import tkinter as tk
from tkinter import ttk, messagebox
import sqlite3
import os
import unittest

DB_NAME = 'salon.db'
SCHEMA = 'salon_schema.sql'

def get_conn():
    return sqlite3.connect(DB_NAME)

def init_db():
    if not os.path.exists(DB_NAME):
        with get_conn() as conn:
            with open(SCHEMA, 'r', encoding='utf-8') as f:
                conn.executescript(f.read())
        # Начальные данные
        with get_conn() as conn:
            conn.execute("INSERT INTO services (name, category, price, duration) VALUES ('Стрижка женская', 'Стрижка', 1500, 60)")
            conn.execute("INSERT INTO clients (full_name, phone) VALUES ('Иванова Анна', '+79001112233')")


def add_service(name, cat, price, duration):
    with get_conn() as c:
        c.execute("INSERT INTO services (name, category, price, duration) VALUES (?,?,?,?)", (name, cat, price, duration))

def get_services():
    with get_conn() as c:
        return c.execute("SELECT id, name, category, price, duration FROM services").fetchall()

def add_client(name, phone):
    with get_conn() as c:
        c.execute("INSERT INTO clients (full_name, phone) VALUES (?,?)", (name, phone))

def get_clients():
    with get_conn() as c:
        return c.execute("SELECT id, full_name FROM clients").fetchall()

def create_appointment(client_id, service_id, qty):
    with get_conn() as c:
        
        cur = c.execute("INSERT INTO appointments (client_id) VALUES (?)", (client_id,))
        appointment_id = cur.lastrowid
      
        price = c.execute("SELECT price FROM services WHERE id=?", (service_id,)).fetchone()[0]
       
        c.execute("INSERT INTO appointment_items (appointment_id, service_id, quantity, price) VALUES (?,?,?,?)", 
                  (appointment_id, service_id, qty, price))

def get_appointments():
    with get_conn() as c:
        return c.execute('''
            SELECT a.id, cl.full_name, s.name, ai.quantity, (ai.quantity * ai.price)
            FROM appointments a
            JOIN clients cl ON cl.id = a.client_id
            JOIN appointment_items ai ON ai.appointment_id = a.id
            JOIN services s ON s.id = ai.service_id
        ''').fetchall()


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Парикмахерская (Простая версия)")
        
        tabs = ttk.Notebook(root)
        tabs.pack(fill='both', expand=True)
        
        self.t1 = tk.Frame(tabs); tabs.add(self.t1, text='Услуги')
        self.t2 = tk.Frame(tabs); tabs.add(self.t2, text='Клиенты')
        self.t3 = tk.Frame(tabs); tabs.add(self.t3, text='Записи')
        
        self.setup_tab1()
        self.setup_tab2()
        self.setup_tab3()

    def setup_tab1(self):
        f = tk.Frame(self.t1); f.pack(pady=5)
        tk.Label(f, text="Название:").pack(side='left')
        self.e_name = tk.Entry(f); self.e_name.pack(side='left')
        tk.Label(f, text="Цена:").pack(side='left')
        self.e_price = tk.Entry(f, width=10); self.e_price.pack(side='left')
        tk.Label(f, text="Длительность (мин):").pack(side='left')
        self.e_duration = tk.Entry(f, width=10); self.e_duration.pack(side='left')
        tk.Button(f, text="Добавить", command=self.add_srv).pack(side='left')
        
        self.tree1 = ttk.Treeview(self.t1, columns=('ID','Название','Цена','Длительность'), show='headings')
        for col in self.tree1['columns']: self.tree1.heading(col, text=col)
        self.tree1.pack(fill='both', expand=True)
        self.refresh_srvs()

    def add_srv(self):
        try:
            add_service(self.e_name.get(), 'Стрижка', float(self.e_price.get()), int(self.e_duration.get()))
            self.refresh_srvs()
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_srvs(self):
        for i in self.tree1.get_children(): self.tree1.delete(i)
        for row in get_services(): self.tree1.insert('', 'end', values=(row[0], row[1], row[3], row[4]))

    def setup_tab2(self):
        f = tk.Frame(self.t2); f.pack(pady=5)
        tk.Label(f, text="ФИО:").pack(side='left')
        self.c_name = tk.Entry(f); self.c_name.pack(side='left')
        tk.Label(f, text="Телефон:").pack(side='left')
        self.c_phone = tk.Entry(f); self.c_phone.pack(side='left')
        tk.Button(f, text="Добавить", command=self.add_cli).pack(side='left')
        
        self.tree2 = ttk.Treeview(self.t2, columns=('ID','ФИО','Телефон'), show='headings')
        for col in self.tree2['columns']: self.tree2.heading(col, text=col)
        self.tree2.pack(fill='both', expand=True)
        self.refresh_clis()

    def add_cli(self):
        try:
            add_client(self.c_name.get(), self.c_phone.get())
            self.refresh_clis()
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_clis(self):
        for i in self.tree2.get_children(): self.tree2.delete(i)
        for row in get_clients(): self.tree2.insert('', 'end', values=row)

    def setup_tab3(self):
        f = tk.Frame(self.t3); f.pack(pady=5)
        tk.Button(f, text="Оформить тестовую запись (клиент 1, услуга 1, 3 раза)", command=self.mock_appointment).pack()
        
        self.tree3 = ttk.Treeview(self.t3, columns=('ID','Клиент','Услуга','Кол-во','Сумма'), show='headings')
        for col in self.tree3['columns']: self.tree3.heading(col, text=col)
        self.tree3.pack(fill='both', expand=True)
        self.refresh_appointments()

    def mock_appointment(self):
        try:
            create_appointment(1, 1, 3) # Берем первого клиента и услугу
            self.refresh_appointments()
            messagebox.showinfo("Успех", "Запись создана! Счётчик длительности услуги увеличился.")
        except Exception as e: messagebox.showerror("Ошибка", str(e))

    def refresh_appointments(self):
        for i in self.tree3.get_children(): self.tree3.delete(i)
        for row in get_appointments(): self.tree3.insert('', 'end', values=row)


class TestApp(unittest.TestCase):
    def setUp(self):
       
        self.old_db = DB_NAME
        globals()['DB_NAME'] = ':memory:'
        init_db()

    def tearDown(self):
        globals()['DB_NAME'] = self.old_db

    def test_add_service(self):
        add_service('Тест', 'Стрижка', 1000, 45)
        self.assertEqual(len(get_services()), 2) # 1 стартовая + 1 новая

    def test_appointment_trigger(self):
   
        create_appointment(1, 1, 5) 
       
        srvs = get_services()
        self.assertEqual(srvs[0][4], 65)  # 60 стартовых + 5 добавленных минут

if __name__ == '__main__':
    import sys
    if '--test' in sys.argv:
        unittest.main(argv=['first-arg-is-ignored'], exit=False)
    else:
        init_db()
        root = tk.Tk()
        app = App(root)
        root.mainloop()
