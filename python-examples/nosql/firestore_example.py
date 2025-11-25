#!/usr/bin/env python3
"""
Firestore Example
Uses Workload Identity for authentication (no credentials needed)

Usage:
    export GCP_PROJECT=my-project-id
    python firestore_example.py
"""

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter
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

class FirestoreConfig:
    """Firestore configuration from environment variables"""
    def __init__(self):
        self.project_id = os.getenv('GCP_PROJECT')
    
    def validate(self):
        """Validate required configuration"""
        if not self.project_id:
            log_structured('GCP_PROJECT not set', severity='ERROR')
            return False
        return True

def create_user(db, user_id, name, email, age):
    """Create a new user document"""
    try:
        doc_ref = db.collection('users').document(user_id)
        doc_ref.set({
            'name': name,
            'email': email,
            'age': age,
            'created_at': firestore.SERVER_TIMESTAMP,
            'updated_at': firestore.SERVER_TIMESTAMP
        })
        log_structured('User created',
                      user_id=user_id,
                      name=name,
                      email=email)
        return True
    except Exception as e:
        log_structured(f'Failed to create user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def get_user(db, user_id):
    """Get a user document"""
    try:
        doc_ref = db.collection('users').document(user_id)
        doc = doc_ref.get()
        
        if doc.exists:
            user_data = doc.to_dict()
            log_structured('User retrieved', user_id=user_id)
            return user_data
        else:
            log_structured('User not found',
                          severity='WARNING',
                          user_id=user_id)
            return None
    except Exception as e:
        log_structured(f'Failed to get user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return None

def update_user(db, user_id, **fields):
    """Update user fields"""
    try:
        doc_ref = db.collection('users').document(user_id)
        fields['updated_at'] = firestore.SERVER_TIMESTAMP
        doc_ref.update(fields)
        log_structured('User updated',
                      user_id=user_id,
                      fields=list(fields.keys()))
        return True
    except Exception as e:
        log_structured(f'Failed to update user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def delete_user(db, user_id):
    """Delete a user document"""
    try:
        db.collection('users').document(user_id).delete()
        log_structured('User deleted', user_id=user_id)
        return True
    except Exception as e:
        log_structured(f'Failed to delete user: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def query_users_by_age(db, min_age):
    """Query users by minimum age"""
    try:
        users_ref = db.collection('users')
        query = users_ref.where(filter=FieldFilter('age', '>=', min_age))
        
        users = []
        for doc in query.stream():
            user_data = doc.to_dict()
            user_data['id'] = doc.id
            users.append(user_data)
        
        log_structured('Users queried by age',
                      min_age=min_age,
                      count=len(users))
        return users
    except Exception as e:
        log_structured(f'Failed to query users: {e}',
                      severity='ERROR')
        return []

def get_all_users(db):
    """Get all users"""
    try:
        users_ref = db.collection('users')
        users = []
        
        for doc in users_ref.stream():
            user_data = doc.to_dict()
            user_data['id'] = doc.id
            users.append(user_data)
        
        log_structured('All users retrieved', count=len(users))
        return users
    except Exception as e:
        log_structured(f'Failed to get all users: {e}',
                      severity='ERROR')
        return []

def create_order(db, order_id, user_id, product_name, quantity, price):
    """Create an order document"""
    try:
        doc_ref = db.collection('orders').document(order_id)
        doc_ref.set({
            'user_id': user_id,
            'product_name': product_name,
            'quantity': quantity,
            'price': price,
            'total': quantity * price,
            'status': 'pending',
            'created_at': firestore.SERVER_TIMESTAMP
        })
        log_structured('Order created',
                      order_id=order_id,
                      user_id=user_id,
                      product_name=product_name)
        return True
    except Exception as e:
        log_structured(f'Failed to create order: {e}',
                      severity='ERROR',
                      order_id=order_id)
        return False

def get_user_orders(db, user_id):
    """Get all orders for a user"""
    try:
        orders_ref = db.collection('orders')
        query = orders_ref.where(filter=FieldFilter('user_id', '==', user_id))
        
        orders = []
        for doc in query.stream():
            order_data = doc.to_dict()
            order_data['id'] = doc.id
            orders.append(order_data)
        
        log_structured('User orders retrieved',
                      user_id=user_id,
                      count=len(orders))
        return orders
    except Exception as e:
        log_structured(f'Failed to get user orders: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return []

def batch_write_example(db):
    """Example of batch write operations"""
    try:
        batch = db.batch()
        
        for i in range(3):
            doc_ref = db.collection('products').document(f'product_{i}')
            batch.set(doc_ref, {
                'name': f'Product {i}',
                'price': 10.0 * (i + 1),
                'in_stock': True,
                'created_at': firestore.SERVER_TIMESTAMP
            })
        
        batch.commit()
        log_structured('Batch write completed', count=3)
        return True
    except Exception as e:
        log_structured(f'Failed batch write: {e}', severity='ERROR')
        return False

def transaction_example(db, user_id, amount):
    """Example of a transaction (atomic operation)"""
    try:
        @firestore.transactional
        def update_balance(transaction, user_ref):
            snapshot = user_ref.get(transaction=transaction)
            current_balance = snapshot.get('balance') or 0
            new_balance = current_balance + amount
            
            transaction.update(user_ref, {
                'balance': new_balance,
                'updated_at': firestore.SERVER_TIMESTAMP
            })
            return new_balance
        
        user_ref = db.collection('users').document(user_id)
        transaction = db.transaction()
        new_balance = update_balance(transaction, user_ref)
        
        log_structured('Transaction completed',
                      user_id=user_id,
                      amount=amount,
                      new_balance=new_balance)
        return True
    except Exception as e:
        log_structured(f'Transaction failed: {e}',
                      severity='ERROR',
                      user_id=user_id)
        return False

def main():
    """Main function"""
    log_structured('Starting Firestore example')
    
    config = FirestoreConfig()
    if not config.validate():
        sys.exit(1)
    
    try:
        db = firestore.Client(project=config.project_id)
        log_structured('Firestore client initialized',
                      project=config.project_id)
    except Exception as e:
        log_structured(f'Failed to initialize Firestore: {e}',
                      severity='ERROR')
        sys.exit(1)
    
    try:
        create_user(db, 'user1', 'John Doe', 'john@example.com', 30)
        create_user(db, 'user2', 'Jane Smith', 'jane@example.com', 25)
        create_user(db, 'user3', 'Bob Johnson', 'bob@example.com', 35)
        
        user = get_user(db, 'user1')
        if user:
            print(f"\n=== User 1 ===")
            print(f"Name: {user['name']}, Email: {user['email']}, Age: {user['age']}")
        
        update_user(db, 'user1', age=31, city='San Francisco')
        
        users = query_users_by_age(db, 25)
        print(f"\n=== Users aged 25+ ===")
        for user in users:
            print(f"ID: {user['id']}, Name: {user['name']}, Age: {user['age']}")
        
        create_order(db, 'order1', 'user1', 'Laptop', 1, 999.99)
        create_order(db, 'order2', 'user1', 'Mouse', 2, 29.99)
        create_order(db, 'order3', 'user2', 'Keyboard', 1, 79.99)
        
        orders = get_user_orders(db, 'user1')
        print(f"\n=== Orders for user1 ===")
        for order in orders:
            print(f"Order ID: {order['id']}, Product: {order['product_name']}, "
                  f"Quantity: {order['quantity']}, Total: ${order['total']}")
        
        batch_write_example(db)
        
        transaction_example(db, 'user1', 100.0)
        
        all_users = get_all_users(db)
        print(f"\n=== All Users ===")
        for user in all_users:
            print(f"ID: {user['id']}, Name: {user['name']}, Email: {user['email']}")
        
        log_structured('Firestore example completed successfully')
        
    except Exception as e:
        log_structured(f'Error during execution: {e}', severity='ERROR')
        sys.exit(1)

if __name__ == '__main__':
    main()
