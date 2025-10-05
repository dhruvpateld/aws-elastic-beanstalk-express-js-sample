pipeline {
  agent any
  options {
    timestamps()
    // NOTE: do NOT use skipDefaultCheckout(true)
    // Leaving it out shows the extra "Checkout SCM" stage like your friend's screenshot.
    buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
  }

  environment {
    DOCKER_REPO = 'dhruvpatelll/eb-node-sample'  
  }

  stages {
    stage('Checkout') {
      steps {
        // explicit checkout so you get both "Checkout SCM" and "Checkout"
        checkout scm
        sh 'ls -la'
      }
    }

    stage('Install Node 16 (once per build)') {
      steps {
        // Pre-pull the image so later stages start fast
        sh 'docker pull node:16-bullseye || true'
      }
    }

    stage('Install & Test') {
      steps {
        // npm install + tests + Snyk scan (folded into this stage to match your friend's layout)
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          sh '''
            docker run --rm \
              -e SNYK_TOKEN="$SNYK_TOKEN" \
              -v "$WORKSPACE:/workspace" -w /workspace \
              node:16-bullseye bash -lc "
                node -v &&
                npm install --save &&
                npm test || echo 'No unit tests found' &&
                npm i -g snyk &&
                snyk auth $SNYK_TOKEN &&
                snyk test --file=package.json --severity-threshold=high
              "
          '''
        }
      }
      post {
        always {
          // archive any package tarball if created
          archiveArtifacts artifacts: '*.tgz', allowEmptyArchive: true
        }
      }
    }
    
    stage('Dependency Scan') {
	steps {
	    withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
	      sh '''
		docker run --rm \
		  -e SNYK_TOKEN="$SNYK_TOKEN" \
		  -v "$WORKSPACE:/workspace" -w /workspace \
		  node:16-bullseye bash -lc "
		    npm i -g snyk &&
		    snyk auth $SNYK_TOKEN &&
		    snyk test --file=package.json --severity-threshold=high
		  "
	      '''
	    }
	  }
	}


    stage('Build Docker Image') {
      steps {
        sh 'echo "Building image: $DOCKER_REPO:$BUILD_NUMBER"'
        sh 'docker build -t "$DOCKER_REPO:$BUILD_NUMBER" .'
      }
    }

    stage('Login & Push') {
      steps {
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

    stage('Post Actions') {
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

  post {
    success { echo 'Pipeline completed successfully.' }
    failure { echo 'Pipeline failed — check Install & Test for Snyk or Docker stages.' }
  }
}

