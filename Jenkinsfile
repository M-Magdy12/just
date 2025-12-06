pipeline {
    agent any
    
    environment {
        DOCKER_USERNAME = "marwanhassan22"
        APP_NAME = "ecommerce-app"
        // Dynamic version using build number and git commit
        VERSION = "${BUILD_NUMBER}-${GIT_COMMIT?.take(7) ?: 'latest'}"
        DOCKER_CREDENTIALS_ID = "docker-hub-credentials"
        IMAGE_TAG = "${DOCKER_USERNAME}/${APP_NAME}:${VERSION}"
    }
    
    stages {
        stage('Initialize') {
            steps {
                script {
                    echo "======================================"
                    echo "E-commerce App Deployment Pipeline"
                    echo "======================================"
                    echo "Building version: ${VERSION}"
                    echo "Image tag: ${IMAGE_TAG}"
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Step 1: Building Docker image..."
                    sh """
                        docker build -t ${IMAGE_TAG} .
                        docker tag ${IMAGE_TAG} ${DOCKER_USERNAME}/${APP_NAME}:latest
                    """
                    echo "✓ Docker image built successfully: ${IMAGE_TAG}"
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "Step 2: Pushing image to Docker Hub..."
                    withCredentials([usernamePassword(
                        credentialsId: "${DOCKER_CREDENTIALS_ID}",
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            echo \$DOCKER_PASS | docker login -u \$DOCKER_USER --password-stdin
                            docker push ${IMAGE_TAG}
                            docker push ${DOCKER_USERNAME}/${APP_NAME}:latest
                        """
                    }
                    echo "✓ Image pushed successfully"
                    echo "  - ${IMAGE_TAG}"
                    echo "  - ${DOCKER_USERNAME}/${APP_NAME}:latest"
                }
            }
        }
        
        stage('Update Deployment Configuration') {
            steps {
                script {
                    echo "Step 3: Updating deployment configuration..."
                    sh """
                        # Update the image tag in the deployment file
                        sed -i 's|image: marwanhassan22/ecommerce-app:.*|image: ${IMAGE_TAG}|g' ecommerce-deployment.yaml
                        
                        # Verify the change
                        echo "Updated deployment file:"
                        grep "image:" ecommerce-deployment.yaml
                    """
                    echo "✓ Configuration updated with image: ${IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            steps {
                script {
                    echo "Step 4: Deploying to Kubernetes..."
                    sh """
                        kubectl apply -f ecommerce-deployment.yaml
                        
                        # Record the deployment change
                        kubectl annotate deployment/ecommerce-app \
                            kubernetes.io/change-cause="Jenkins build #${BUILD_NUMBER} - Image: ${IMAGE_TAG}" \
                            --overwrite
                    """
                    echo "✓ Application deployed"
                }
            }
        }
        
        stage('Deploy ServiceMonitor') {
            steps {
                script {
                    echo "Step 5: Deploying ServiceMonitor..."
                    sh """
                        kubectl apply -f ecommerce-servicemonitor.yaml
                    """
                    echo "✓ ServiceMonitor deployed"
                }
            }
        }
        
        stage('Deploy Alert Rules') {
            steps {
                script {
                    echo "Step 6: Deploying Alert Rules..."
                    sh """
                        kubectl apply -f ecommerce-alert-rules.yaml
                    """
                    echo "✓ Alert rules deployed"
                }
            }
        }
        
        stage('Wait for Deployment Rollout') {
            steps {
                script {
                    echo "Step 7: Waiting for deployment rollout to complete..."
                    sh """
                        # Wait for the deployment to rollout
                        kubectl rollout status deployment/ecommerce-app --timeout=300s
                        
                        # Wait for pods to be ready
                        kubectl wait --for=condition=ready pod -l app=ecommerce --timeout=180s
                    """
                    echo "✓ Deployment rollout completed successfully"
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                script {
                    echo "Step 8: Verifying deployment..."
                    sh """
                        echo "Current deployment image:"
                        kubectl get deployment ecommerce-app -o jsonpath='{.spec.template.spec.containers[0].image}'
                        echo ""
                        
                        echo "\\nPod status:"
                        kubectl get pods -l app=ecommerce
                        
                        echo "\\nDeployment history:"
                        kubectl rollout history deployment/ecommerce-app
                    """
                }
            }
        }
        
        stage('Get Service Information') {
            steps {
                script {
                    echo "Step 9: Gathering Service Information..."
                    def nodePort = sh(
                        script: "kubectl get svc ecommerce-service -o jsonpath='{.spec.ports[0].nodePort}'",
                        returnStdout: true
                    ).trim()
                    
                    def nodeIP = sh(
                        script: """
                            NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
                            if [ -z "\$NODE_IP" ]; then
                                NODE_IP=\$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                            fi
                            echo \$NODE_IP
                        """,
                        returnStdout: true
                    ).trim()
                    
                    echo """
======================================
Deployment Completed Successfully!
======================================
Build Number: ${BUILD_NUMBER}
Image Tag: ${IMAGE_TAG}
Deployment: ecommerce-app

Application URL: http://${nodeIP}:${nodePort}
Metrics URL: http://${nodeIP}:${nodePort}/metrics
Health Check: http://${nodeIP}:${nodePort}/health

Test the application:
  curl http://${nodeIP}:${nodePort}/products
  curl http://${nodeIP}:${nodePort}/stats

Check pods:
  kubectl get pods -l app=ecommerce

Watch logs:
  kubectl logs -l app=ecommerce -f

Rollback if needed:
  kubectl rollout undo deployment/ecommerce-app
======================================
                    """
                    
                    // Store deployment info for later reference
                    currentBuild.description = "Deployed: ${IMAGE_TAG}"
                }
            }
        }
    }
    
    post {
        failure {
            script {
                echo "❌ Deployment failed!"
                sh """
                    echo "Current pod status:"
                    kubectl get pods -l app=ecommerce || true
                    
                    echo "\\nPod events:"
                    kubectl get events --sort-by='.lastTimestamp' | grep ecommerce || true
                    
                    echo "\\nDeployment status:"
                    kubectl describe deployment ecommerce-app || true
                """
            }
        }
        success {
            echo "✓ Pipeline completed successfully!"
            echo "Image ${IMAGE_TAG} is now running in production"
        }
        always {
            script {
                // Cleanup Docker login
                sh "docker logout || true"
                
                // Clean up old Docker images locally to save space
                sh """
                    docker image prune -f --filter "until=24h" || true
                """
            }
        }
    }
}
