pipeline {
  agent any

  parameters {
    string(name: 'DOCKER_USERNAME', defaultValue: 'mmagdy12', description: 'Docker Hub username')
    string(name: 'APP_NAME', defaultValue: 'ecommerce-app', description: 'Kubernetes app label/name')
    string(name: 'VERSION', defaultValue: 'v1', description: 'Image tag / version')
    string(name: 'DEPLOYMENT_YAML', defaultValue: 'ecommerce-deployment.yaml', description: 'Deployment YAML file path')
  }

  environment {
    IMAGE = "${params.DOCKER_USERNAME}/${params.APP_NAME}:${params.VERSION}"
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Build Docker image') {
      steps {
        echo "Building Docker image: ${env.IMAGE}"
        sh 'docker build -t "${IMAGE}" .'
      }
    }

    stage('Docker login & push') {
      steps {
        // 👈 هنا التعديل الحقيقي
        withCredentials([usernamePassword(credentialsId: 'dokcerhup', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh '''
            echo "Logging in to Docker Hub as ${DOCKER_USER}..."
            printf "%s\n" "${DOCKER_PASS}" | docker login -u "${DOCKER_USER}" --password-stdin
            echo "Pushing image ${IMAGE}..."
            docker push "${IMAGE}"
          '''
        }
      }
    }

    stage('Update deployment YAML') {
      steps {
        sh """
          sed -i "s|image: .*|image: ${IMAGE}|g" ${params.DEPLOYMENT_YAML}
        """
      }
    }

    stage('kubectl apply manifests') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-filee', variable: 'SECRET-FILE')]) {
          sh '''
            export KUBECONFIG="${SECRET-FILE}"
            kubectl apply -f ${DEPLOYMENT_YAML}
            kubectl apply -f ecommerce-servicemonitor.yaml  true
            kubectl apply -f ecommerce-alert-rules.yaml  true
          '''
        }
      }
    }

    stage('Wait for pods ready') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-filee', variable: 'SECRET-FILE')]) {
          sh '''
            export KUBECONFIG="${SECRET-FILE}"
            kubectl wait --for=condition=ready pod -l app=${APP_NAME} --timeout=180s
          '''
        }
      }
    }

    stage('Service Info') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-filee', variable: 'SECRET-FILE')]) {
          script {
            env.KUBECONFIG = "${SECRET-FILE}"

            NODE_PORT = sh(script: "kubectl get svc ecommerce-service -o jsonpath='{.spec.ports[0].nodePort}'", returnStdout: true).trim()
          }  
        }
      } 
    }
  }
}
