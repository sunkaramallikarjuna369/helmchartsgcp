#!/usr/bin/env python3
"""
PostgreSQL Direct Connection Example
For in-cluster PostgreSQL (Bitnami chart)

Usage:
    export DB_HOST=postgresql.default.svc.cluster.local
    export DB_PORT=5432
    export DB_NAME=mydb
    export DB_USER=postgres
    export DB_PASSWORD=your-password
    python postgresql_direct.py
"""

import psycopg2
from psycopg2.extras import RealDictCursor
import os
import sys
import logging
import json
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(message)s')

def log_structured(message, severity='INFO', **kwargs):
    """Log in structured format for GCP Cloud Logging"""
    log_entry = {
        'severity': severity,
        'message': message,
        'timestamp': datetime.utcnow().isoformat(),
        **kwargs
    }
    print(json.dumps(log_entry))

class DatabaseConfig:
    """Database configuration from environment variables"""
    def __init__(self):
        self.host = os.getenv('DB_HOST', 'postgresql.default.svc.cluster.local')
        self.port = int(os.getenv('DB_PORT', '5432'))
        self.database = os.getenv('DB_NAME', 'mydb')
        self.user = os.getenv('DB_USER', 'postgres')
        self.password = os.getenv('DB_PASSWORD', '')
        
    def validate(self):
        """Validate required configuration"""
        if not self.password:
            log_structured('DB_PASSWORD not set', severity='ERROR')
            return False
        return True

def get_connection(config):
    """Create database connection"""
    try:
        conn = psycopg2.connect(
            host=config.host,
            port=config.port,
            database=config.database,
            user=config.user,
            password=config.password,
            connect_timeout=10
        )
        log_structured('Database connection established',
                      host=config.host,
                      database=config.database)
        return conn
    except psycopg2.OperationalError as e:
        log_structured(f'Failed to connect to database: {e}',
                      severity='ERROR',
                      host=config.host,
                      database=config.database)
        raise

def create_tables(conn):
    """Create example tables"""
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                product_name VARCHAR(200) NOT NULL,
                quantity INTEGER NOT NULL,
                price DECIMAL(10, 2) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        conn.commit()
        log_structured('Tables created successfully')

def insert_user(conn, name, email):
    """Insert a new user"""
    try:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id",
                (name, email)
            )
            user_id = cur.fetchone()[0]
            conn.commit()
            log_structured('User created',
                          user_id=user_id,
                          name=name,
                          email=email)
            return user_id
    except psycopg2.IntegrityError as e:
        conn.rollback()
        log_structured(f'Failed to create user: {e}',
                      severity='WARNING',
                      name=name,
                      email=email)
        return None

def insert_order(conn, user_id, product_name, quantity, price):
    """Insert a new order"""
    try:
        with conn.cursor() as cur:
            cur.execute(
                """INSERT INTO orders (user_id, product_name, quantity, price)
                   VALUES (%s, %s, %s, %s) RETURNING id""",
                (user_id, product_name, quantity, price)
            )
            order_id = cur.fetchone()[0]
            conn.commit()
            log_structured('Order created',
                          order_id=order_id,
                          user_id=user_id,
                          product_name=product_name)
            return order_id
    except psycopg2.Error as e:
        conn.rollback()
        log_structured(f'Failed to create order: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return None

def get_users(conn):
    """Get all users"""
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("SELECT * FROM users ORDER BY created_at DESC")
        users = cur.fetchall()
        log_structured('Retrieved users', count=len(users))
        return users

def get_user_orders(conn, user_id):
    """Get all orders for a user"""
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """SELECT o.*, u.name as user_name, u.email as user_email
               FROM orders o
               JOIN users u ON o.user_id = u.id
               WHERE o.user_id = %s
               ORDER BY o.created_at DESC""",
            (user_id,)
        )
        orders = cur.fetchall()
        log_structured('Retrieved user orders',
                      user_id=user_id,
                      count=len(orders))
        return orders

def update_user(conn, user_id, name=None, email=None):
    """Update user information"""
    updates = []
    params = []
    
    if name:
        updates.append("name = %s")
        params.append(name)
    if email:
        updates.append("email = %s")
        params.append(email)
    
    if not updates:
        return False
    
    updates.append("updated_at = CURRENT_TIMESTAMP")
    params.append(user_id)
    
    try:
        with conn.cursor() as cur:
            query = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
            cur.execute(query, params)
            conn.commit()
            log_structured('User updated',
                          user_id=user_id,
                          name=name,
                          email=email)
            return True
    except psycopg2.Error as e:
        conn.rollback()
        log_structured(f'Failed to update user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def delete_user(conn, user_id):
    """Delete a user (cascades to orders)"""
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
            conn.commit()
            log_structured('User deleted', user_id=user_id)
            return True
    except psycopg2.Error as e:
        conn.rollback()
        log_structured(f'Failed to delete user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def main():
    """Main function"""
    log_structured('Starting PostgreSQL example')
    
    config = DatabaseConfig()
    if not config.validate():
        sys.exit(1)
    
    try:
        conn = get_connection(config)
    except Exception as e:
        log_structured(f'Failed to connect: {e}', severity='ERROR')
        sys.exit(1)
    
    try:
        create_tables(conn)
        
        user1_id = insert_user(conn, 'John Doe', 'john@example.com')
        user2_id = insert_user(conn, 'Jane Smith', 'jane@example.com')
        
        if user1_id:
            insert_order(conn, user1_id, 'Laptop', 1, 999.99)
            insert_order(conn, user1_id, 'Mouse', 2, 29.99)
        
        if user2_id:
            insert_order(conn, user2_id, 'Keyboard', 1, 79.99)
        
        users = get_users(conn)
        print("\n=== All Users ===")
        for user in users:
            print(f"ID: {user['id']}, Name: {user['name']}, Email: {user['email']}")
        
        if user1_id:
            orders = get_user_orders(conn, user1_id)
            print(f"\n=== Orders for User {user1_id} ===")
            for order in orders:
                print(f"Order ID: {order['id']}, Product: {order['product_name']}, "
                      f"Quantity: {order['quantity']}, Price: ${order['price']}")
        
        if user1_id:
            update_user(conn, user1_id, name='John Updated')
        
        users = get_users(conn)
        print("\n=== Updated Users ===")
        for user in users:
            print(f"ID: {user['id']}, Name: {user['name']}, Email: {user['email']}")
        
        log_structured('PostgreSQL example completed successfully')
        
    except Exception as e:
        log_structured(f'Error during execution: {e}', severity='ERROR')
        sys.exit(1)
    finally:
        conn.close()
        log_structured('Database connection closed')

if __name__ == '__main__':
    main()
