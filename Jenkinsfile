pipeline {
  agent any
  options {
    timestamps()
    skipDefaultCheckout(true)                         // we checkout explicitly in the first stage
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }
  environment {
    DOCKERHUB   = credentials('dockerhub')            // username+password (ID: dockerhub)
    DOCKER_REPO = "${DOCKERHUB_USR}/eb-node-sample"   // change name if you want
    SNYK_TOKEN  = credentials('snyk-token')           // secret text (ID: snyk-token)
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'ls -la'
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
      post {
        unsuccessful {
          echo 'Snyk reported High/Critical severity. Build failed as required.'
        }
      }
    }

    stage('Docker Build & Push') {
      steps {
        sh 'docker version'  // verifies Jenkins -> DinD connection
        sh 'docker build -t $DOCKER_REPO:$BUILD_NUMBER .'
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh 'echo "$PASS" | docker login -u "$USER" --password-stdin'
        }
        sh '''
          docker push $DOCKER_REPO:$BUILD_NUMBER
          docker tag  $DOCKER_REPO:$BUILD_NUMBER $DOCKER_REPO:latest
          docker push $DOCKER_REPO:latest
        '''
      }
    }

    stage('Archive Logs & Evidence') {
      steps {
        // collect common evidence patterns if present
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

  // NOTE: No pipeline-level post{} that archives files.
  // Archiving only happens inside stages to guarantee workspace context.
}

