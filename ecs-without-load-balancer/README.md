
# ECS without Load Balancer

The point of this experiment is to try to create an ECS cluster that can be accessed from the outside world without load balancer. The reason to try such an experiment is as follows:

Let's say that we have a **functional automated and manual testing stage** in our CI pipeline of an application built with microservices. The pipepline is triggered when developer commits to the feature branch of one of the services. At this stage of the pipeline we would like to spin a temporary development environment on AWS ECS. The constraints of this environment is as follows:
1. It is temporary. It will be deleted once testing is done
2. It has to spin up in the shortest time possible
3. It does not need to be highly available or scalable
4. Tester should be able to access the environment from the outside world
5. Tester should be able to reuse the test data of a previous test run
6. Test environment requires additional services that are not part of the production architecture such as
    1. Stubs in place of services external to the domain
    2. Automated test executor
    3. Consoles that allow access to backing services, e.g. database or queue consoles
    
The template provided at [AWS Labs][1] suggests a deployment architecture with load balancer. Setting up a load balancer requires additional AWS resources such as
* AWS::ElasticLoadBalancingV2::LoadBalancer
* AWS::ElasticLoadBalancingV2::TargetGroup
* AWS::ElasticLoadBalancingV2::Listener

This seems to be redundent for a temporary environment and slightly contradicts with the constraint 2 above, although setting up of the environment can be started earlier in the pipeline, in parallel tasks, to save time. Nevertheless, in this exercise I will try to create a testing environment without load balander to see if it can serve the purpose.

I will be using CloudFormation templates as infrastructure as code(IaC) and running them with a shell script *environment.sh*. The script utilizes AWS CLI to manage the CloudFormation stacks. What I already have is:
1. An AWS account
2. An AWS account user that has administrative privilidges
3. The *aws_access_key_id* and *aws_secret_access_key* of this user set at the *~/.aws/credentials* file of my development machine.

[1]: https://github.com/awslabs/aws-cloudformation-templates/tree/master/aws/services/ECS/FargateLaunchType

