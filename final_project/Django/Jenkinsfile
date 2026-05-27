pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.16.0-debug
      command: ["sleep"]
      args: ["99d"]
    - name: git
      image: alpine/git:latest
      command: ["sleep"]
      args: ["99d"]
'''
        }
    }

    environment {
        ECR_REGISTRY = "REDACTED-AWS-ACCOUNT.dkr.ecr.us-west-2.amazonaws.com"
        IMAGE_NAME   = "lesson-7-ecr"
    }

    stages {
        stage('Build & Push Docker Image') {
            steps {
                container('kaniko') {
                    script {
                        def imageTag = "build-${env.BUILD_NUMBER}"
                        sh "/kaniko/executor --context=dir://lesson-6 --dockerfile=lesson-6/Dockerfile --destination=${ECR_REGISTRY}/${IMAGE_NAME}:${imageTag} --cache=true"
                    }
                }
            }
        }

        stage('Update Git Manifest') {
            steps {
                container('git') {
                    script {
                        def imageTag = "build-${env.BUILD_NUMBER}"
                        withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
                            sh """
                                sed -i 's/tag: .*/tag: "'${imageTag}'"/' lesson-8-9/charts/django-app/values.yaml
                                git config --global --add safe.directory '*'
                                git config user.name "Jenkins CI"
                                git config user.email "jenkins@ci.com"
                                git add lesson-8-9/charts/django-app/values.yaml
                                git commit -m "chore: update image tag to ${imageTag} [skip ci]" || echo "No changes to commit"
                                git push https://${GIT_USER}:${GIT_TOKEN}@github.com/kms-engineer/my-microservice-project.git HEAD:lesson-8-9
                            """
                        }
                    }
                }
            }
        }
    }
}
