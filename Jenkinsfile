pipeline {
  agent any                              // run on any available Jenkins agent

  environment {
    VAULT_ADDR = "http://vault:8200"     // vault container name resolves on pipeline-net
    APP_IMAGE  = "secret-pipeline-app"
  }

  stages {

    // ─── STAGE 1: LEAK SCAN ───────────────────────────────────────────────
    stage('Leak Scan') {
      steps {
        echo 'Scanning repository for hardcoded secrets...'
        sh '''
          gitleaks detect \
            --source=. \
            --config=.gitleaks.toml \
            --verbose \
            --redact              # redact actual secret values from logs
        '''
      }
    }

    // ─── STAGE 2 + 3: VAULT LOGIN + FETCH SECRETS ─────────────────────────
    stage('Fetch Secrets from Vault') {
      steps {
        // withCredentials pulls VAULT_ROLE_ID and VAULT_SECRET_ID
        // from Jenkins credential store — never printed in logs
        withCredentials([
          string(credentialsId: 'VAULT_ROLE_ID',    variable: 'ROLE_ID'),
          string(credentialsId: 'VAULT_SECRET_ID',  variable: 'SECRET_ID')
        ]) {
          script {
            echo 'Authenticating with Vault via AppRole...'

            // log in to Vault — get back a temporary token
            def vaultToken = sh(
              script: """
                curl -s --request POST \
                  --data '{"role_id":"'"\$ROLE_ID"'","secret_id":"'"\$SECRET_ID"'"}' \
                  \$VAULT_ADDR/v1/auth/approle/login \
                  | python3 -c "import sys,json; print(json.load(sys.stdin)['auth']['client_token'])"
              """,
              returnStdout: true
            ).trim()

            echo 'Fetching DB credentials from Vault...'

            // use the token to read the secret
            def dbSecret = sh(
              script: """
                curl -s --header "X-Vault-Token: ${vaultToken}" \
                  \$VAULT_ADDR/v1/secret/data/app/db \
                  | python3 -c "import sys,json; d=json.load(sys.stdin)['data']['data']; print(d['username']+'|'+d['password'])"
              """,
              returnStdout: true
            ).trim()

            // split and store as environment variables for next stage
            def parts = dbSecret.split('\\|')
            env.DB_USERNAME = parts[0]
            env.DB_PASSWORD = parts[1]

            echo 'Secrets fetched successfully. Values are masked in logs.'
          }
        }
      }
    }

    // ─── STAGE 4: BUILD + DEPLOY ──────────────────────────────────────────
    stage('Build and Deploy') {
      steps {
        echo 'Building Docker image...'
        sh "docker build -t ${APP_IMAGE} ./app"

        echo 'Deploying app container with secrets injected...'
        sh """
          docker stop app 2>/dev/null || true       // stop existing container if running
          docker rm   app 2>/dev/null || true       // remove it

          docker run -d \
            --name app \
            --network secret-pipeline_pipeline-net \
            -p 5000:5000 \
            -e VAULT_ADDR=\$VAULT_ADDR \
            -e VAULT_TOKEN=\$DB_USERNAME \
            -e DB_USERNAME=\$DB_USERNAME \
            -e DB_PASSWORD=\$DB_PASSWORD \
            -e DB_HOST=postgres \
            -e DB_NAME=appdb \
            ${APP_IMAGE}
        """
      }
    }

    // ─── STAGE 5: HEALTH CHECK ────────────────────────────────────────────
    stage('Health Check') {
      steps {
        echo 'Waiting for app to start...'
        sh 'sleep 5'
        sh '''
          for i in 1 2 3; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://app:5000/health)
            if [ "$STATUS" = "200" ]; then
              echo "Health check passed — app is running"
              exit 0
            fi
            echo "Attempt $i failed (status $STATUS) — retrying in 5s..."
            sleep 5
          done
          echo "Health check failed after 3 attempts"
          exit 1
        '''
      }
    }

  }

  // ─── POST: NOTIFY ON RESULT ───────────────────────────────────────────────
  post {
    success {
      echo "Pipeline succeeded — app deployed with Vault-managed secrets"
    }
    failure {
      echo "Pipeline failed — check logs above for which stage failed"
      // add email or Slack notification here if desired
    }
    always {
      echo "Audit: check Vault audit log for all secret access events"
    }
  }
}