# build-and-deploy
A Bash Script to build and deploy Docker Containers to ECR and to update Lambda to use the latest version

I was playing with creating Docker Containers for use in Lambda as explained in the article [AWS Lambda for the containers developer] (https://aws.amazon.com/blogs/containers/aws-lambda-for-the-containers-developer/). However, I needed to be able to iterate quickly, so I built this script to perform the tasks I needed to run on a regular basis.

## Usage

build-and-deploy.sh -h

        usage: build-and-deploy.sh 
                [ -b | --build-docker ]
                [ -e | --execute ]
                [ -s | --shell ]
                [ -p | --push2ecr ]
                [ -l | --set-lambda2use ]
                [ -a | --all (Default, does not include execute) ]
                [Container Directory]

                [-D | --debug] 
                [-h | --help] 

If you don't specify a container image, the script will open a menu and display the directories in your home directory for you to choose. The idea being that the directory name is the same as the ECR repository you will be pushing to. In order to push to Lambda, the script looks for a file called <code>lambda-function.txt</code> where is grabs the Lambda function name you use. The script assumes you have permissions to perform that actions you need. I was running this script on an Ubuntu based EC2 machine running docker for my testing.
