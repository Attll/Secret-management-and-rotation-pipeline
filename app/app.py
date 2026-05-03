import os
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/health')
def health():
    return jsonify({"status": "ok"})

@app.route('/db-check')
def db_check():
    try:
        conn = psycopg2.connect(
            host=os.environ.get('DB_HOST', 'postgres'),
            database=os.environ.get('DB_NAME', 'appdb'),
            user=os.environ.get('DB_USERNAME', ''),
            password=os.environ.get('DB_PASSWORD', '')
        )
        cursor = conn.cursor()
        cursor.execute('SELECT current_user, current_database();')
        user, db = cursor.fetchone()
        conn.close()
        return jsonify({
            "db": "connected",
            "user": user,
            "database": db,
            "secret_source": "HashiCorp Vault via Jenkins pipeline"
        })
    except Exception as e:
        return jsonify({"db": "failed", "error": str(e)}), 500

@app.route('/env-check')
def env_check():
    return jsonify({
        "DB_HOST": os.environ.get('DB_HOST', 'NOT SET'),
        "DB_NAME": os.environ.get('DB_NAME', 'NOT SET'),
        "DB_USERNAME": os.environ.get('DB_USERNAME', 'NOT SET'),
        "DB_PASSWORD": "***masked***" if os.environ.get('DB_PASSWORD') else 'NOT SET',
        "VAULT_ADDR": os.environ.get('VAULT_ADDR', 'NOT SET')
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)