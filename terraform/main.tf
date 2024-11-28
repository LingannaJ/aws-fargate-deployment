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

# Security Group
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-sg"
  description = "Allow traffic to ECS services"
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

# ECR Repository
resource "aws_ecr_repository" "patient_service" {
  name = "patient-service-repo"
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
      image     = "${aws_ecr_repository.patient_service.repository_url}:latest"
      cpu       = 256
      memory    = 512
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "patient_service" {
  name            = "patient-service"
  cluster         = aws_ecs_cluster.hackathon_cluster.id
  task_definition = aws_ecs_task_definition.patient_service.arn
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.public_subnets
    security_groups = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }
}
