provider "aws" {
  region = "us-east-1"
}

# VPC with subnets
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  name   = "hackathon-vpc"
  cidr   = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
}

# ECS Cluster
resource "aws_ecs_cluster" "hackathon_cluster" {
  name = "hackathon-ecs-cluster"
}

# IAM Role for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_policy" {
  name       = "ecs_task_execution_policy_attachment"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Security Group for ECS
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-sg"
  description = "Allow traffic to ECS services"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_security_group" {
  name        = "alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group Rule for ALB to ECS
resource "aws_security_group_rule" "ecs_allow_alb" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ecs_security_group.id
  source_security_group_id = aws_security_group.alb_security_group.id
}

# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

# Target Group for ECS Service
resource "aws_lb_target_group" "ecs_target_group" {
  name        = "ecs-target-group"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    interval            = 30
    path                = "/health" # Update if your app health path differs
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

# Listener for ALB
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}

# ECS Service
resource "aws_ecs_service" "patient_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.hackathon_cluster.id
  task_definition = aws_ecs_task_definition.patient_service.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.vpc.private_subnets # Use private subnets
    security_groups = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = "patient-service-container"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.app_listener]
}

# ECR Repository
resource "aws_ecr_repository" "patient_service" {
  name = "patient-service-repo"
  
  force_delete = true  # This forces the deletion of the repository and its images
}

# ECS Task Definition
resource "aws_ecs_task_definition" "patient_service" {
  family                   = "patient-service-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "patient-service-container"
      image     = "767397768520.dkr.ecr.us-east-1.amazonaws.com/patient-service:latest" # Replace with your ECR image here, after pushed to ECR
      cpu       = 256
      memory    = 512
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      environment = [
        {
          name  = "PORT"
          value = "3000"
        }
      ]
    }
  ])
}


# This below script is check the ruuning logs in cloud watch with ECS TASK Defination

# ECR Repository 
# resource "aws_ecr_repository" "patient_service" {
#   name = "patient-service-repo"
# }

# # CloudWatch Log Group for ECS container logs
# resource "aws_cloudwatch_log_group" "patient_service_log_group" {
#   name = "/ecs/patient-service"
# }

# # ECS Task Definition with CloudWatch Logging
# resource "aws_ecs_task_definition" "patient_service" {
#   family                   = "patient-service-task"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
#   task_role_arn            = aws_iam_role.ecs_task_role.arn
#   cpu                      = "256"
#   memory                   = "512"

#   container_definitions = jsonencode([{
#     name        = "patient-service-container"
#     image       = "767397768520.dkr.ecr.us-east-1.amazonaws.com/patient-service:latest" # Replace with your ECR image here, after pushed to ECR
#     cpu         = 256
#     memory      = 512
#     portMappings = [
#       {
#         containerPort = 3000
#         hostPort      = 3000
#       }
#     ]
#     environment = [
#       {
#         name  = "PORT"
#         value = "3000"
#       }
#     ]

#     # CloudWatch Logs Configuration for ECS Container
#     logConfiguration = {
#       logDriver = "awslogs"
#       options = {
#         "awslogs-group"         = aws_cloudwatch_log_group.patient_service_log_group.name
#         "awslogs-region"        = "us-east-1"
#         "awslogs-stream-prefix" = "ecs"
#       }
#     }
#   }])
# }

