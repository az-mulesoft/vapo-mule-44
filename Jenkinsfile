pipeline {

    environment {
    	registry = "${env.dockerhubUser}/mule4"
	tag = "${env.BRANCH_NAME}"
	registryCredential = 'dockerhub'

    }

    agent any 
    stages {
	 stage('Build Docker Image'){
	 	agent { label 'master' }
	 	steps{
			script {
				withCredentials([
					usernamePassword(credentialsId: 'dockerhub',
					usernameVariable: 'dhuser',
					passwordVariable: 'dhpass')
				]) {

		        //	print 'username=' + dhuser + ' password=' + dhpass
			//	print 'username.collect { it }=' + dhuser.collect { it }
			//	print 'password.collect { it }=' + dhpass.collect { it }
				}
			}
			sh '''
			docker version
			echo ${WORKSPACE}
			'''
			script {
				dockerImage = docker.build registry + ":" + tag
			}
		}
	 }
	 stage('Push to Dockerhub'){
		steps{
			script {
				docker.withRegistry( '', registryCredential ) {
					//dockerImage.push()
				}
			}
		}
	 }
    }

}
