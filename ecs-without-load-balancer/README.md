
# ECS without Load Balancer

The point of this experiment is to try to create an ECS cluster that can be accessed from the outside world without load balancer. The reason to try such an experiment is as follows:

Let's say that we have a functional automated and manual testing stage in our CI pipeline of an application built with microservices. The pipepline is triggered when developer commits to the feature branch of one of the services. At this stage of the pipeline we would like to spin a temporary development environment on AWS ECS.




