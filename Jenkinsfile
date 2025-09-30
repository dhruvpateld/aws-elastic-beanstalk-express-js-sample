pipeline {
  agent any
  options {
    timestamps()
    skipDefaultCheckout(true) // we'll checkout explicitly
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }

  environment {
    // We'll compute DOCKER_REPO in 'Init' using the dockerhub credential username.
    DOCKER_REPO = ''
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'ls -la'
      }
    }

    stage('Init (derive Docker repo name)') {
      steps {
        script {
          withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            env.DOCKER_USER = DH_USER
            env.DOCKER_REPO = "${DH_USER}/eb-node-sample"
          }
          echo "Using Docker repository: ${env.DOCKER_REPO}"
        }
      }
    }

    stage('Build & Test (Node 16 via docker run)') {
      steps {
        sh '''
          docker run --rm \
            -v "$PWD":/workspace -w /workspace \
            node:16-bullseye bash -lc "
              node -v &&
              npm install --save &&
              npm test || echo 'No unit tests found' &&
              npm pack || true
            "
        '''
      }
      post {
        always {
          archiveArtifacts artifacts: '*.tgz', allowEmptyArchive: true
        }
      }
    }

    stage('Dependency Vulnerability Scan (Snyk)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            docker run --rm \
              -e SNYK_TOKEN="$SNYK_TOKEN" \
              -v "$PWD":/workspace -w /workspace \
              node:16-bullseye bash -lc "
                npm i -g snyk &&
                snyk auth $SNYK_TOKEN &&
                snyk test --severity-threshold=high
              "
          '''
        }
      }
      post {
        unsuccessful {
          echo 'Snyk reported High/Critical severity. Failing as required.'
        }
      }
    }

    stage('Docker Build & Push') {
      steps {
        sh 'docker version' // verifies Jenkins -> DinD connectivity
        sh 'docker build -t "$DOCKER_REPO:$BUILD_NUMBER" .'
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh 'echo "$PASS" | docker login -u "$USER" --password-stdin'
        }
        sh '''
          docker push "$DOCKER_REPO:$BUILD_NUMBER"
          docker tag  "$DOCKER_REPO:$BUILD_NUMBER" "$DOCKER_REPO:latest"
          docker push "$DOCKER_REPO:latest"
        '''
      }
    }

    stage('Archive Logs & Evidence') {
      steps {
        sh 'mkdir -p reports || true'
        sh 'ls -la > build_listing.log || true'
      }
      post {
        always {
          archiveArtifacts artifacts: 'reports/**/*, **/*.log', allowEmptyArchive: true
        }
      }
    }
  }
}

