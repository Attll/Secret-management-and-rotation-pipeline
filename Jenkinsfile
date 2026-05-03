pipeline {
  agent any

  environment {
    VAULT_ADDR = "http://vault:8200"
    APP_IMAGE  = "secret-pipeline-app"
  }

  stages {

    stage('Leak Scan') {
      steps {
        echo 'Scanning repository for hardcoded secrets...'
        sh '''
          gitleaks detect \
            --source=. \
            --config=.gitleaks.toml \
            --verbose \
            --redact
        '''
      }
    }

    stage('Fetch Secrets from Vault') {
      steps {
        withCredentials([
          string(credentialsId: 'VAULT_ROLE_ID',    variable: 'ROLE_ID'),
          string(credentialsId: 'VAULT_SECRET_ID',  variable: 'SECRET_ID')
        ]) {
          script {
            echo 'Authenticating with Vault via AppRole...'

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

            def dbSecret = sh(
              script: """
                curl -s --header "X-Vault-Token: ${vaultToken}" \
                  \$VAULT_ADDR/v1/secret/data/app/db \
                  | python3 -c "import sys,json; d=json.load(sys.stdin)['data']['data']; print(d['username']+'|'+d['password'])"
              """,
              returnStdout: true
            ).trim()

            def parts = dbSecret.split('\\|')
            env.DB_USERNAME = parts[0]
            env.DB_PASSWORD = parts[1]

            echo 'Secrets fetched. Values masked in logs.'
          }
        }
      }
    }

    stage('Build and Deploy') {
      steps {
        echo 'Building Docker image...'
        sh "docker build -t ${APP_IMAGE} ./app"

        echo 'Deploying app container...'
        sh """
          docker stop app 2>/dev/null || true
          docker rm   app 2>/dev/null || true

          docker run -d \
            --name app \
            --network secret-pipeline_pipeline-net \
            -p 5000:5000 \
            -e VAULT_ADDR=\$VAULT_ADDR \
            -e DB_USERNAME=\$DB_USERNAME \
            -e DB_PASSWORD=\$DB_PASSWORD \
            -e DB_HOST=postgres \
            -e DB_NAME=appdb \
            ${APP_IMAGE}
        """
      }
    }

    stage('Health Check') {
      steps {
        sh 'sleep 5'
        sh '''
          for i in 1 2 3; do
            STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://app:5000/health)
            if [ "$STATUS" = "200" ]; then
              echo "Health check passed"
              exit 0
            fi
            echo "Attempt $i failed (status $STATUS) retrying..."
            sleep 5
          done
          echo "Health check failed"
          exit 1
        '''
      }
    }

  }

  post {
    success {
      echo "Pipeline succeeded — app deployed with Vault-managed secrets"
    }
    failure {
      echo "Pipeline failed — check logs above"
    }
    always {
      echo "Audit: check Vault audit log for all secret access events"
    }
  }
}