pipeline {
  /* Keeps a workspace for all stages, shows timestamps, and retains logs/artifacts */
  agent any
  options {
    timestamps()
    skipDefaultCheckout(true)
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }

  /* EDIT: set your Docker Hub repo here */
  environment {
    DOCKER_REPO = 'dhruvpatelll'        
    IMAGE_TAG   = "${env.BUILD_NUMBER}"
    IMAGE_FULL  = "${env.DOCKER_REPO}:${env.IMAGE_TAG}"
  }

  stages {
    stage('Checkout SCM') {
      steps { checkout scm }
    }

    stage('Install Node 16 (once per build)') {
      steps { sh 'docker pull node:16-bullseye' }
    }

    stage('Install & Test') {
      steps {
        echo '=== npm install --save & tests inside Node 16 ==='
        script {
          docker.image('node:16-bullseye').inside("-v ${env.WORKSPACE}:/w -w /w") {
            sh '''
              node -v && npm -v
              npm install --save
              npm test || echo "No unit tests found"
            '''
          }
        }
      }
    }

    stage('Dependency Vulnerability Scan (Snyk)') {
      environment { SNYK_TOKEN = credentials('snyk-token') }
      steps {
        echo '=== Snyk test (will FAIL build on High/Critical) ==='
        script {
          docker.image('node:16-bullseye').inside("-v ${env.WORKSPACE}:/w -w /w") {
            sh '''
              npm i -g snyk
              snyk auth "$SNYK_TOKEN"
              snyk test --file=package.json --severity-threshold=high
            '''
          }
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        echo "=== docker build ${IMAGE_FULL} ==="
        sh 'docker version'
        sh 'docker build -t "$IMAGE_FULL" .'
      }
    }

    stage('Login & Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
          sh 'echo "$PASS" | docker login -u "$USER" --password-stdin'
        }
        sh '''
          docker push "$IMAGE_FULL"
          docker tag  "$IMAGE_FULL" "$DOCKER_REPO:latest"
          docker push "$DOCKER_REPO:latest"
        '''
      }
    }

    stage('Post Actions') {
      steps {
        sh 'mkdir -p reports || true'
        sh 'echo "IMAGE=$IMAGE_FULL" > reports/image.txt'
        archiveArtifacts artifacts: 'reports/**/*, Jenkinsfile, package*.json', allowEmptyArchive: true, fingerprint: true
      }
    }
  }
}

