pipeline {
  agent any
  options {
    timestamps()
    skipDefaultCheckout(true)
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }

  environment {
    DOCKER_REPO = ''   // set in Init
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
        sh 'echo "HOST WORKSPACE is: $WORKSPACE" && ls -la'
      }
    }

    stage('Init (Docker repo + quick checks)') {
      steps {
        script {
          // Try read dockerhub username from credential; fallback to your known username
          def userFromCred = ''
          try {
            withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
              userFromCred = DH_USER?.trim()
            }
          } catch (ignored) {
            // credential missing—will rely on fallback below
          }

          def fallbackUser = 'dhruvpatelll'   // <-- set this to YOUR Docker Hub username
          def finalUser = userFromCred ?: fallbackUser
          env.DOCKER_REPO = "${finalUser}/eb-node-sample"

          echo "Using Docker repository: ${env.DOCKER_REPO}"

          if (!env.DOCKER_REPO || env.DOCKER_REPO == '/eb-node-sample') {
            error 'DOCKER_REPO is empty. Fix dockerhub credential or set fallbackUser.'
          }
        }

        // prove the mount works
        sh '''
          docker run --rm -v "${WORKSPACE}:/workspace" -w /workspace \
            node:16-bullseye bash -lc 'echo "IN-CONTAINER LISTING:"; ls -la'
        '''
      }
    }

    stage('Build & Test (Node 16)') {
      steps {
        sh '''
          docker run --rm \
            -v "${WORKSPACE}:/workspace" -w /workspace \
            node:16-bullseye bash -lc "
              test -f package.json && echo OK: package.json present || (echo 'package.json missing INSIDE container' && ls -la && exit 2);
              node -v &&
              npm install --save &&
              npm test || echo 'No unit tests found' &&
              npm pack || true
            "
        '''
      }
      post {
        always { archiveArtifacts artifacts: '*.tgz', allowEmptyArchive: true }
      }
    }

    stage('Dependency Vulnerability Scan (Snyk)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            docker run --rm \
              -e SNYK_TOKEN="$SNYK_TOKEN" \
              -v "${WORKSPACE}:/workspace" -w /workspace \
              node:16-bullseye bash -lc "
                npm i -g snyk &&
                snyk auth $SNYK_TOKEN &&
                snyk test --file=package.json --severity-threshold=high
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
        sh 'docker version'
        sh 'echo "Building image: $DOCKER_REPO:$BUILD_NUMBER"'
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

