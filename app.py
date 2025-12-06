from flask import Flask, jsonify, request, send_from_directory
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter
import sqlite3
import logging
from datetime import datetime
import os

app = Flask(__name__, static_folder='.')

# Prometheus metrics
metrics = PrometheusMetrics(app, defaults_prefix="ecommerce_app")
metrics.info('app_info', 'E-commerce Application', version='1.0.0')

# Custom metrics
order_counter = Counter(
    'ecommerce_app_orders_total', 
    'Total number of successfully created orders'
)

order_revenue = Counter(
    'ecommerce_app_revenue_total',
    'Total revenue from orders'
)

product_requests = Counter(
    'ecommerce_app_product_requests_total',
    'Total product requests',
    ['endpoint', 'method']
)

low_stock_products = Counter(
    'ecommerce_app_low_stock_total',
    'Products with low stock (< 10 items)'
)

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Safe DB connection
def get_db():
    conn = sqlite3.connect('ecommerce.db', check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

# DB Initialization
def init_db():
    conn = sqlite3.connect('ecommerce.db')
    c = conn.cursor()

    c.execute('''CREATE TABLE IF NOT EXISTS products
                (id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                price REAL NOT NULL,
                stock INTEGER NOT NULL)''')

    c.execute('''CREATE TABLE IF NOT EXISTS orders
                (id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id INTEGER,
                quantity INTEGER,
                total_price REAL,
                order_date TEXT,
                FOREIGN KEY(product_id) REFERENCES products(id))''')

    # Insert sample data
    c.execute("SELECT COUNT(*) FROM products")
    if c.fetchone()[0] == 0:
        sample = [
            ('Laptop', 15000, 50),
            ('Phone', 8000, 100),
            ('Headphones', 500, 200),
            ('Mouse', 150, 300),
            ('Keyboard', 800, 150)
        ]
        c.executemany("INSERT INTO products (name, price, stock) VALUES (?, ?, ?)", sample)

    conn.commit()
    conn.close()
    logger.info("Database initialized successfully")

init_db()

# Serve HTML
@app.route('/')
def index():
    return send_from_directory('.', 'index.html')

# API Routes
@app.route('/health')
def health():
    return jsonify({"status": "healthy", "timestamp": datetime.now().isoformat()}), 200

@app.route('/products')
def get_products():
    try:
        product_requests.labels(endpoint='/products', method='GET').inc()
        
        conn = get_db()
        rows = conn.execute("SELECT * FROM products").fetchall()
        conn.close()

        for row in rows:
            if row['stock'] < 10:
                low_stock_products.inc()

        return jsonify([dict(r) for r in rows]), 200
        
    except Exception as e:
        logger.error(f"Error getting products: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:pid>')
def get_product(pid):
    try:
        product_requests.labels(endpoint=f'/products/{pid}', method='GET').inc()
        
        conn = get_db()
        item = conn.execute("SELECT * FROM products WHERE id = ?", (pid,)).fetchone()
        conn.close()

        if item:
            return jsonify(dict(item)), 200
        return jsonify({"error": "Product not found"}), 404

    except Exception as e:
        logger.error(f"Error getting product: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders', methods=['POST'])
def create_order():
    try:
        data = request.get_json()
        pid = data.get("product_id")
        qty = data.get("quantity")

        if not pid or not qty:
            return jsonify({"error": "product_id and quantity required"}), 400

        conn = get_db()
        product = conn.execute("SELECT * FROM products WHERE id = ?", (pid,)).fetchone()

        if not product:
            conn.close()
            return jsonify({"error": "Product not found"}), 404

        if product["stock"] < qty:
            conn.close()
            return jsonify({"error": "Insufficient stock"}), 400

        total = product["price"] * qty
        date = datetime.now().isoformat()

        cur = conn.cursor()
        cur.execute("INSERT INTO orders (product_id, quantity, total_price, order_date) VALUES (?, ?, ?, ?)",
                    (pid, qty, total, date))
        cur.execute("UPDATE products SET stock = stock - ? WHERE id = ?", (qty, pid))

        order_id = cur.lastrowid
        conn.commit()
        conn.close()

        order_counter.inc()
        order_revenue.inc(total)

        logger.info(f"Order {order_id} created - Revenue: {total}")
        
        return jsonify({
            "order_id": order_id,
            "product_id": pid,
            "quantity": qty,
            "total_price": total,
            "order_date": date
        }), 201

    except Exception as e:
        logger.error(f"Error creating order: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders')
def get_orders():
    try:
        conn = get_db()
        rows = conn.execute("""
            SELECT o.*, p.name AS product_name
            FROM orders o JOIN products p ON o.product_id = p.id
            ORDER BY o.order_date DESC
        """).fetchall()
        conn.close()

        return jsonify([dict(r) for r in rows]), 200

    except Exception as e:
        logger.error(f"Error getting orders: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/stats')
def stats():
    try:
        conn = get_db()
        products = conn.execute("SELECT COUNT(*) FROM products").fetchone()[0]
        orders = conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0]
        revenue = conn.execute("SELECT SUM(total_price) FROM orders").fetchone()[0] or 0
        low_stock = conn.execute("SELECT COUNT(*) FROM products WHERE stock < 10").fetchone()[0]
        conn.close()

        return jsonify({
            "total_products": products,
            "total_orders": orders,
            "total_revenue": revenue,
            "low_stock_products": low_stock
        }), 200

    except Exception as e:
        logger.error(f"Error getting stats: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
