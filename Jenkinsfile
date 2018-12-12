/**
 * This pipeline will build and deploy a Docker image with Kaniko
 * https://github.com/GoogleContainerTools/kaniko
 * without needing a Docker host
 *
 * You need to create a jenkins-docker-cfg secret with your docker config
 * as described in
 * https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-in-the-cluster-that-holds-your-authorization-token
 *
 * ie.
 * kubectl create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=csanchez --docker-password=mypassword --docker-email=john@doe.com
 */

pipeline {
  agent {
    kubernetes {
      //cloud 'kubernetes'
      label 'kaniko'
      yaml """
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /root
  volumes:
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: regcred
          items:
            - key: .dockerconfigjson
              path: .docker/config.json
"""
    }
  }
  stages {
    stage('Build with Kaniko') {
      environment {
        PATH = "/busybox:$PATH"
      }
      steps {
        git 'https://github.com/jenkinsci/docker-jnlp-slave.git'
        container(name: 'kaniko', shell: '/busybox/sh') {
            sh '''#!/busybox/sh
            /kaniko/executor -f `pwd`/Dockerfile -c `pwd` --insecure --skip-tls-verify --cache=true --destination=mydockerregistry:5000/myorg/myimage
            '''
        }
      }
    }
  }

  environment {
    ORG = 'carlossg'
    APP_NAME = 'jenkins-kaniko-example'
    CHARTMUSEUM_CREDS = credentials('jenkins-x-chartmuseum')
  }
  stages {
    stage('CI Build and push snapshot') {
      when {
        branch 'PR-*'
      }
      environment {
        PREVIEW_VERSION = "0.0.0-SNAPSHOT-$BRANCH_NAME-$BUILD_NUMBER"
        PREVIEW_NAMESPACE = "$APP_NAME-$BRANCH_NAME".toLowerCase()
        HELM_RELEASE = "$PREVIEW_NAMESPACE".toLowerCase()
      }
      steps {
        dir('/home/jenkins/go/src/github.com/carlossg-org/jenkins-kaniko-example') {
          checkout scm
          sh "make linux"
          sh "export VERSION=$PREVIEW_VERSION && skaffold build -f skaffold.yaml"
          sh "jx step post build --image $DOCKER_REGISTRY/$ORG/$APP_NAME:$PREVIEW_VERSION"
        }
        dir('/home/jenkins/go/src/github.com/carlossg-org/jenkins-kaniko-example/charts/preview') {
          sh "make preview"
          sh "jx preview --app $APP_NAME --dir ../.."
        }
      }
    }
    stage('Build Release') {
      when {
        branch 'master'
      }
      steps {
        dir('/home/jenkins/go/src/github.com/carlossg-org/jenkins-kaniko-example') {
          git 'https://github.com/carlossg-org/jenkins-kaniko-example.git'

          // so we can retrieve the version in later steps
          sh "echo \$(jx-release-version) > VERSION"
          sh "jx step tag --version \$(cat VERSION)"
          sh "make build"
          sh "export VERSION=`cat VERSION` && skaffold build -f skaffold.yaml"
          sh "jx step post build --image $DOCKER_REGISTRY/$ORG/$APP_NAME:\$(cat VERSION)"
        }
      }
    }
    stage('Promote to Environments') {
      when {
        branch 'master'
      }
      steps {
        dir('/home/jenkins/go/src/github.com/carlossg-org/jenkins-kaniko-example/charts/jenkins-kaniko-example') {
          sh "jx step changelog --version v\$(cat ../../VERSION)"

          // release the helm chart
          sh "jx step helm release"

          // promote through all 'Auto' promotion Environments
          sh "jx promote -b --all-auto --timeout 1h --version \$(cat ../../VERSION)"
        }
      }
    }
  }
}
