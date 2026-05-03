import os
import hvac                              # Vault Python client
import psycopg2
from flask import Flask, jsonify

app = Flask(__name__)

def get_db_creds():
    """Ask Vault for database credentials at runtime."""
    client = hvac.Client(url=os.environ['VAULT_ADDR'])
    client.token = os.environ['VAULT_TOKEN']
    secret = client.secrets.kv.v2.read_secret_version(
        path='app/db',
        mount_point='secret'
    )
    return secret['data']['data']

@app.route('/health')
def health():
    return jsonify({"status": "ok"})

@app.route('/db-check')
def db_check():
    creds = get_db_creds()
    conn = psycopg2.connect(
        host='postgres',
        database='appdb',
        user=creds['username'],
        password=creds['password']
    )
    conn.close()
    return jsonify({"db": "connected", "user": creds['username']})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)