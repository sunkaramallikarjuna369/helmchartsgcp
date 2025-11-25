#!/usr/bin/env python3
"""
Redis Example
For in-cluster Redis or Memorystore

Usage:
    export REDIS_HOST=redis.default.svc.cluster.local
    export REDIS_PORT=6379
    export REDIS_PASSWORD=your-password  # Optional
    python redis_example.py
"""

import redis
import os
import sys
import logging
import json
from datetime import datetime
import time

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

class RedisConfig:
    """Redis configuration from environment variables"""
    def __init__(self):
        self.host = os.getenv('REDIS_HOST', 'redis.default.svc.cluster.local')
        self.port = int(os.getenv('REDIS_PORT', '6379'))
        self.password = os.getenv('REDIS_PASSWORD', '')
        self.db = int(os.getenv('REDIS_DB', '0'))
    
    def validate(self):
        """Validate configuration"""
        return True  # Redis password is optional

def get_redis_client(config):
    """Create Redis client"""
    try:
        r = redis.Redis(
            host=config.host,
            port=config.port,
            password=config.password if config.password else None,
            db=config.db,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5
        )
        
        r.ping()
        
        log_structured('Redis connection established',
                      host=config.host,
                      port=config.port,
                      db=config.db)
        return r
    except redis.ConnectionError as e:
        log_structured(f'Failed to connect to Redis: {e}',
                      severity='ERROR',
                      host=config.host,
                      port=config.port)
        raise

def string_operations(r):
    """Demonstrate string operations"""
    log_structured('=== String Operations ===')
    
    r.set('user:1:name', 'John Doe')
    r.set('user:1:email', 'john@example.com')
    
    name = r.get('user:1:name')
    email = r.get('user:1:email')
    print(f"Name: {name}, Email: {email}")
    
    r.setex('session:abc123', 3600, 'session_data')
    ttl = r.ttl('session:abc123')
    print(f"Session TTL: {ttl} seconds")
    
    r.set('page:views', 0)
    r.incr('page:views')
    r.incr('page:views', 5)
    views = r.get('page:views')
    print(f"Page views: {views}")
    
    r.mset({
        'user:2:name': 'Jane Smith',
        'user:2:email': 'jane@example.com'
    })
    values = r.mget('user:2:name', 'user:2:email')
    print(f"User 2: {values}")

def hash_operations(r):
    """Demonstrate hash operations"""
    log_structured('=== Hash Operations ===')
    
    r.hset('user:3', mapping={
        'name': 'Bob Johnson',
        'email': 'bob@example.com',
        'age': 35,
        'city': 'San Francisco'
    })
    
    name = r.hget('user:3', 'name')
    print(f"Name: {name}")
    
    user = r.hgetall('user:3')
    print(f"User 3: {user}")
    
    fields = r.hmget('user:3', 'name', 'email', 'city')
    print(f"Selected fields: {fields}")
    
    r.hincrby('user:3', 'age', 1)
    age = r.hget('user:3', 'age')
    print(f"Updated age: {age}")
    
    exists = r.hexists('user:3', 'name')
    print(f"Name field exists: {exists}")
    
    r.hdel('user:3', 'city')

def list_operations(r):
    """Demonstrate list operations"""
    log_structured('=== List Operations ===')
    
    r.lpush('tasks', 'task1', 'task2', 'task3')
    r.rpush('tasks', 'task4')
    
    length = r.llen('tasks')
    print(f"Tasks count: {length}")
    
    tasks = r.lrange('tasks', 0, -1)
    print(f"All tasks: {tasks}")
    
    task = r.lpop('tasks')
    print(f"Popped task: {task}")
    
    task = r.lindex('tasks', 0)
    print(f"First task: {task}")
    
    r.ltrim('tasks', 0, 9)  # Keep only first 10 items

def set_operations(r):
    """Demonstrate set operations"""
    log_structured('=== Set Operations ===')
    
    r.sadd('tags:1', 'python', 'redis', 'database')
    r.sadd('tags:2', 'python', 'flask', 'web')
    
    tags1 = r.smembers('tags:1')
    print(f"Tags 1: {tags1}")
    
    is_member = r.sismember('tags:1', 'python')
    print(f"'python' in tags:1: {is_member}")
    
    intersection = r.sinter('tags:1', 'tags:2')
    print(f"Common tags: {intersection}")
    
    union = r.sunion('tags:1', 'tags:2')
    print(f"All tags: {union}")
    
    difference = r.sdiff('tags:1', 'tags:2')
    print(f"Tags only in tags:1: {difference}")
    
    r.srem('tags:1', 'database')
    
    count = r.scard('tags:1')
    print(f"Tags count: {count}")

def sorted_set_operations(r):
    """Demonstrate sorted set operations"""
    log_structured('=== Sorted Set Operations ===')
    
    r.zadd('leaderboard', {
        'player1': 100,
        'player2': 200,
        'player3': 150,
        'player4': 300
    })
    
    top_players = r.zrange('leaderboard', 0, 2, withscores=True)
    print(f"Bottom 3 players: {top_players}")
    
    top_players = r.zrevrange('leaderboard', 0, 2, withscores=True)
    print(f"Top 3 players: {top_players}")
    
    score = r.zscore('leaderboard', 'player2')
    print(f"Player2 score: {score}")
    
    r.zincrby('leaderboard', 50, 'player1')
    
    rank = r.zrevrank('leaderboard', 'player1')
    print(f"Player1 rank: {rank + 1}")  # +1 for 1-based ranking
    
    count = r.zcard('leaderboard')
    print(f"Total players: {count}")
    
    r.zrem('leaderboard', 'player4')

def pub_sub_example(r):
    """Demonstrate pub/sub (basic example)"""
    log_structured('=== Pub/Sub Example ===')
    
    subscribers = r.publish('notifications', 'Hello, subscribers!')
    print(f"Message sent to {subscribers} subscribers")
    

def pipeline_example(r):
    """Demonstrate pipeline for batch operations"""
    log_structured('=== Pipeline Example ===')
    
    pipe = r.pipeline()
    
    pipe.set('key1', 'value1')
    pipe.set('key2', 'value2')
    pipe.set('key3', 'value3')
    pipe.get('key1')
    pipe.get('key2')
    pipe.get('key3')
    
    results = pipe.execute()
    print(f"Pipeline results: {results}")

def cache_example(r):
    """Demonstrate caching pattern"""
    log_structured('=== Cache Example ===')
    
    def get_user_from_db(user_id):
        """Simulate database query"""
        time.sleep(0.1)  # Simulate slow DB query
        return {
            'id': user_id,
            'name': f'User {user_id}',
            'email': f'user{user_id}@example.com'
        }
    
    def get_user(user_id):
        """Get user with caching"""
        cache_key = f'cache:user:{user_id}'
        
        cached = r.get(cache_key)
        if cached:
            log_structured('Cache hit', user_id=user_id)
            return json.loads(cached)
        
        log_structured('Cache miss', user_id=user_id)
        user = get_user_from_db(user_id)
        
        r.setex(cache_key, 3600, json.dumps(user))
        
        return user
    
    user = get_user(123)
    print(f"User: {user}")
    
    user = get_user(123)
    print(f"User (cached): {user}")

def main():
    """Main function"""
    log_structured('Starting Redis example')
    
    config = RedisConfig()
    if not config.validate():
        sys.exit(1)
    
    try:
        r = get_redis_client(config)
    except Exception as e:
        log_structured(f'Failed to connect: {e}', severity='ERROR')
        sys.exit(1)
    
    try:
        string_operations(r)
        print()
        
        hash_operations(r)
        print()
        
        list_operations(r)
        print()
        
        set_operations(r)
        print()
        
        sorted_set_operations(r)
        print()
        
        pub_sub_example(r)
        print()
        
        pipeline_example(r)
        print()
        
        cache_example(r)
        print()
        
        log_structured('Redis example completed successfully')
        
    except Exception as e:
        log_structured(f'Error during execution: {e}', severity='ERROR')
        sys.exit(1)
    finally:
        r.close()
        log_structured('Redis connection closed')

if __name__ == '__main__':
    main()
