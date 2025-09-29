pipeline {
  agent none

  // EDIT THIS: set your Docker Hub repo "username/reponame"
  environment {
    DOCKERHUB_REPO = 'dhruvpatelll/aws-eb-sample'
    IMAGE = "${env.DOCKERHUB_REPO}:${env.BUILD_NUMBER}"
  }

  stages {
    stage('Checkout') {
      agent any
      steps { checkout scm }
    }

    // Requirement: Use Node 16 Docker image as build agent; run npm install --save and tests
    stage('Build & Test (Node 16)') {
      agent { docker { image 'node:16' } }
      steps {
        sh 'node -v && npm -v'
        sh 'npm install --save'
        sh 'npm test'
      }
    }

    // Security: fail on High/Critical using Snyk
    stage('Security Scan (Snyk)') {
      agent { docker { image 'node:16' } }
      environment { SNYK_TOKEN = credentials('snyk-token') }
      steps {
        sh '''
          npm install -g snyk
          snyk auth "$SNYK_TOKEN"
          snyk test --severity-threshold=high
        '''
      }
    }

    stage('Docker Build') {
      agent any
      steps {
        sh 'docker version'
        sh 'docker build -t "$IMAGE" .'
      }
    }

    stage('Docker Push') {
      agent any
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-cred', usernameVariable: 'U', passwordVariable: 'P')]) {
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
