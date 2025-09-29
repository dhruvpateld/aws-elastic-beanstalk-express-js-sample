pipeline {
  agent none
  environment {
    DOCKERHUB_REPO = 'dhruvpatelll/aws-eb-sample'
    IMAGE = "${env.DOCKERHUB_REPO}:${env.BUILD_NUMBER}"
  }
  stages {
    stage('Checkout') {
      agent any
      steps { checkout scm }
    }
    stage('Build & Test (Node 16)') {
      agent { docker { image 'node:16' } }
      steps {
        sh 'echo "=== npm install --save ==="'
        sh 'npm install --save'
        sh 'echo "=== npm test ==="'
        sh 'npm test'
      }
    }
    stage('Security Scan (Snyk)') {
      agent { docker { image 'node:16' } }
      environment { SNYK_TOKEN = credentials('snyk-token') }
      steps {
        sh 'echo "=== Snyk auth & test (fail on high) ==="'
        sh 'npm install -g snyk'
        sh 'snyk auth "$SNYK_TOKEN"'
        sh 'snyk test --severity-threshold=high'
      }
    }
    stage('Docker Build') {
      agent any
      steps {
        sh 'echo "=== docker version (DinD) ==="'
        sh 'docker version'
        sh 'echo "=== docker build -t $IMAGE . ==="'
        sh 'docker build -t "$IMAGE" .'
      }
    }
    stage('Docker Push') {
      agent any
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'U', passwordVariable: 'P')]) {
          sh 'echo "=== docker login & push ==="'
          sh 'echo "$P" | docker login -u "$U" --password-stdin'
          sh 'docker push "$IMAGE"'
        }
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'Jenkinsfile,package*.json', fingerprint: true
    }
  }
}
