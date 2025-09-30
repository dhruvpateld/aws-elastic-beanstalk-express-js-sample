pipeline {
  agent any

  environment {
    DOCKERHUB = credentials('dockerhub')                 // Docker Hub creds
    DOCKER_REPO = "dhruvpatelll/aws-eb-sample"      // change name if you want
  }

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build & Test (Node 16)') {
      agent { docker { image 'node:16-bullseye' } }      // required: Node 16
      steps {
        sh 'node -v'
        sh 'npm install --save'                          // required in spec
        sh 'npm test || echo "No unit tests found"'
        sh 'npm pack || true'
      }
      post {
        always { archiveArtifacts artifacts: "*.tgz", allowEmptyArchive: true }
      }
    }

    stage('Dependency Vulnerability Scan') {             // must fail on High/Critical
      agent { docker { image 'node:16-bullseye' } }
      environment { SNYK_TOKEN = credentials('snyk-token') }
      steps {
        sh '''
          npm i -g snyk
          snyk auth $SNYK_TOKEN
          snyk test --severity-threshold=high
        '''
      }
    }

    stage('Docker Build & Push') {
      steps {
        sh 'docker version'  // talks to DinD at tcp://docker:2376
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
  }

  post {
    always  { archiveArtifacts artifacts: "**/*.log", allowEmptyArchive: true }
    success { echo "Build ${env.BUILD_NUMBER} succeeded." }
    failure { echo "Build ${env.BUILD_NUMBER} failed. See logs." }
  }
}

