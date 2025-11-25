#!/usr/bin/env python3
"""
Cloud SQL PostgreSQL Connection Example
Uses Cloud SQL Python Connector with Workload Identity

Usage:
    export GCP_PROJECT=my-project-id
    export GCP_REGION=us-central1
    export CLOUDSQL_INSTANCE=my-instance
    export DB_NAME=mydb
    export DB_USER=postgres
    export DB_PASSWORD=your-password
    python postgresql_cloudsql.py
"""

from google.cloud.sql.connector import Connector
import sqlalchemy
from sqlalchemy import text
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

class CloudSQLConfig:
    """Cloud SQL configuration from environment variables"""
    def __init__(self):
        self.project_id = os.getenv('GCP_PROJECT')
        self.region = os.getenv('GCP_REGION', 'us-central1')
        self.instance_name = os.getenv('CLOUDSQL_INSTANCE')
        self.database = os.getenv('DB_NAME', 'postgres')
        self.user = os.getenv('DB_USER', 'postgres')
        self.password = os.getenv('DB_PASSWORD', '')
        
    @property
    def instance_connection_name(self):
        """Get full instance connection name"""
        return f"{self.project_id}:{self.region}:{self.instance_name}"
    
    def validate(self):
        """Validate required configuration"""
        if not self.project_id:
            log_structured('GCP_PROJECT not set', severity='ERROR')
            return False
        if not self.instance_name:
            log_structured('CLOUDSQL_INSTANCE not set', severity='ERROR')
            return False
        if not self.password:
            log_structured('DB_PASSWORD not set', severity='ERROR')
            return False
        return True

def create_engine(config):
    """Create SQLAlchemy engine with Cloud SQL Connector"""
    connector = Connector()
    
    def getconn():
        conn = connector.connect(
            config.instance_connection_name,
            "pg8000",
            user=config.user,
            password=config.password,
            db=config.database
        )
        return conn
    
    engine = sqlalchemy.create_engine(
        "postgresql+pg8000://",
        creator=getconn,
        pool_size=5,
        max_overflow=2,
        pool_timeout=30,
        pool_recycle=1800,
    )
    
    log_structured('SQLAlchemy engine created',
                  instance=config.instance_connection_name,
                  database=config.database)
    
    return engine, connector

def create_tables(engine):
    """Create example tables"""
    with engine.connect() as conn:
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                product_name VARCHAR(200) NOT NULL,
                quantity INTEGER NOT NULL,
                price DECIMAL(10, 2) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        
        conn.commit()
        log_structured('Tables created successfully')

def insert_user(engine, name, email):
    """Insert a new user"""
    try:
        with engine.connect() as conn:
            result = conn.execute(
                text("INSERT INTO users (name, email) VALUES (:name, :email) RETURNING id"),
                {"name": name, "email": email}
            )
            user_id = result.fetchone()[0]
            conn.commit()
            log_structured('User created',
                          user_id=user_id,
                          name=name,
                          email=email)
            return user_id
    except sqlalchemy.exc.IntegrityError as e:
        log_structured(f'Failed to create user: {e}',
                      severity='WARNING',
                      name=name,
                      email=email)
        return None

def insert_order(engine, user_id, product_name, quantity, price):
    """Insert a new order"""
    try:
        with engine.connect() as conn:
            result = conn.execute(
                text("""INSERT INTO orders (user_id, product_name, quantity, price)
                        VALUES (:user_id, :product_name, :quantity, :price) RETURNING id"""),
                {
                    "user_id": user_id,
                    "product_name": product_name,
                    "quantity": quantity,
                    "price": price
                }
            )
            order_id = result.fetchone()[0]
            conn.commit()
            log_structured('Order created',
                          order_id=order_id,
                          user_id=user_id,
                          product_name=product_name)
            return order_id
    except sqlalchemy.exc.SQLAlchemyError as e:
        log_structured(f'Failed to create order: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return None

def get_users(engine):
    """Get all users"""
    with engine.connect() as conn:
        result = conn.execute(text("SELECT * FROM users ORDER BY created_at DESC"))
        users = [dict(row._mapping) for row in result]
        log_structured('Retrieved users', count=len(users))
        return users

def get_user_orders(engine, user_id):
    """Get all orders for a user"""
    with engine.connect() as conn:
        result = conn.execute(
            text("""SELECT o.*, u.name as user_name, u.email as user_email
                    FROM orders o
                    JOIN users u ON o.user_id = u.id
                    WHERE o.user_id = :user_id
                    ORDER BY o.created_at DESC"""),
            {"user_id": user_id}
        )
        orders = [dict(row._mapping) for row in result]
        log_structured('Retrieved user orders',
                      user_id=user_id,
                      count=len(orders))
        return orders

def update_user(engine, user_id, name=None, email=None):
    """Update user information"""
    updates = []
    params = {"user_id": user_id}
    
    if name:
        updates.append("name = :name")
        params["name"] = name
    if email:
        updates.append("email = :email")
        params["email"] = email
    
    if not updates:
        return False
    
    updates.append("updated_at = CURRENT_TIMESTAMP")
    
    try:
        with engine.connect() as conn:
            query = f"UPDATE users SET {', '.join(updates)} WHERE id = :user_id"
            conn.execute(text(query), params)
            conn.commit()
            log_structured('User updated',
                          user_id=user_id,
                          name=name,
                          email=email)
            return True
    except sqlalchemy.exc.SQLAlchemyError as e:
        log_structured(f'Failed to update user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def main():
    """Main function"""
    log_structured('Starting Cloud SQL PostgreSQL example')
    
    config = CloudSQLConfig()
    if not config.validate():
        sys.exit(1)
    
    try:
        engine, connector = create_engine(config)
    except Exception as e:
        log_structured(f'Failed to create engine: {e}', severity='ERROR')
        sys.exit(1)
    
    try:
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version()"))
            version = result.fetchone()[0]
            log_structured('Connected to PostgreSQL', version=version)
        
        create_tables(engine)
        
        user1_id = insert_user(engine, 'John Doe', 'john@example.com')
        user2_id = insert_user(engine, 'Jane Smith', 'jane@example.com')
        
        if user1_id:
            insert_order(engine, user1_id, 'Laptop', 1, 999.99)
            insert_order(engine, user1_id, 'Mouse', 2, 29.99)
        
        if user2_id:
            insert_order(engine, user2_id, 'Keyboard', 1, 79.99)
        
        users = get_users(engine)
        print("\n=== All Users ===")
        for user in users:
            print(f"ID: {user['id']}, Name: {user['name']}, Email: {user['email']}")
        
        if user1_id:
            orders = get_user_orders(engine, user1_id)
            print(f"\n=== Orders for User {user1_id} ===")
            for order in orders:
                print(f"Order ID: {order['id']}, Product: {order['product_name']}, "
                      f"Quantity: {order['quantity']}, Price: ${order['price']}")
        
        if user1_id:
            update_user(engine, user1_id, name='John Updated')
        
        users = get_users(engine)
        print("\n=== Updated Users ===")
        for user in users:
            print(f"ID: {user['id']}, Name: {user['name']}, Email: {user['email']}")
        
        log_structured('Cloud SQL PostgreSQL example completed successfully')
        
    except Exception as e:
        log_structured(f'Error during execution: {e}', severity='ERROR')
        sys.exit(1)
    finally:
        connector.close()
        log_structured('Cloud SQL connector closed')

if __name__ == '__main__':
    main()
