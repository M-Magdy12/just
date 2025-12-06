pipeline {
    agent any
   
    stages {
        stage('build') {
            steps {
                sh """
                    docker build -t fortestinggg .
                """
            }
        }

        stage('push') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dokcerhup', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh """
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker tag nginximage $DOCKER_USER/nginximage:latest
                        docker push $DOCKER_USER/fortestinggg:latest
                    """
                }
            }
        }

    }
}
